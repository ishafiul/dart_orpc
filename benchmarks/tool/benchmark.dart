import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../packages/benchmark_workloads/lib/benchmark_workloads.dart';

final Directory benchmarkRoot = File.fromUri(
  Platform.script,
).parent.parent.absolute;
final Directory buildDirectory = Directory('${benchmarkRoot.path}/build');

const echoPayload = {'message': 'benchmark', 'count': 42, 'enabled': true};
const catalogPath = '/catalog?category=books&page=2&limit=10';

final fixtures = <Fixture>[
  Fixture(
    name: 'dart_orpc',
    directory: 'apps/dart_orpc_benchmark',
    port: 18081,
    buildSteps: const [
      Command('dart', ['pub', 'get']),
      Command('dart', ['run', 'build_runner', 'build']),
      Command('dart', [
        'compile',
        'exe',
        'bin/server.dart',
        '-o',
        '../../build/dart_orpc_server',
      ]),
    ],
    executable: 'dart_orpc_server',
  ),
  Fixture(
    name: 'shelf',
    directory: 'apps/shelf_benchmark',
    port: 18082,
    buildSteps: const [
      Command('dart', ['pub', 'get']),
      Command('dart', [
        'compile',
        'exe',
        'bin/server.dart',
        '-o',
        '../../build/shelf_server',
      ]),
    ],
    executable: 'shelf_server',
  ),
  Fixture(
    name: 'dart_frog',
    directory: 'apps/dart_frog_benchmark',
    port: 18083,
    buildSteps: const [
      Command('dart', ['pub', 'get']),
      Command('dart', ['run', 'dart_frog_cli:dart_frog', 'build']),
      Command('dart', [
        'compile',
        'exe',
        'build/bin/server.dart',
        '-o',
        '../../build/dart_frog_server',
      ]),
    ],
    executable: 'dart_frog_server',
  ),
  Fixture(
    name: 'serverpod',
    directory: 'apps/serverpod_benchmark/serverpod_benchmark_server',
    port: 18085,
    buildSteps: const [
      Command('dart', ['pub', 'get'], workingDirectory: '..'),
      Command('dart', ['run', 'serverpod_cli:serverpod_cli', 'generate']),
      Command('dart', [
        'compile',
        'exe',
        'bin/main.dart',
        '-o',
        '../../../build/serverpod_server',
      ]),
    ],
    executable: 'serverpod_server',
    environment: const {
      'SERVERPOD_API_SERVER_PORT': '18084',
      'SERVERPOD_API_SERVER_PUBLIC_HOST': '127.0.0.1',
      'SERVERPOD_API_SERVER_PUBLIC_PORT': '18084',
      'SERVERPOD_API_SERVER_PUBLIC_SCHEME': 'http',
      'SERVERPOD_WEB_SERVER_PORT': '18085',
      'SERVERPOD_WEB_SERVER_PUBLIC_HOST': '127.0.0.1',
      'SERVERPOD_WEB_SERVER_PUBLIC_PORT': '18085',
      'SERVERPOD_WEB_SERVER_PUBLIC_SCHEME': 'http',
      'SERVERPOD_INSIGHTS_SERVER_PORT': '18086',
      'SERVERPOD_INSIGHTS_SERVER_PUBLIC_HOST': '127.0.0.1',
      'SERVERPOD_INSIGHTS_SERVER_PUBLIC_PORT': '18086',
      'SERVERPOD_INSIGHTS_SERVER_PUBLIC_SCHEME': 'http',
      'SERVERPOD_SESSION_CONSOLE_LOG_ENABLED': 'false',
      'SERVERPOD_SESSION_PERSISTENT_LOG_ENABLED': 'false',
    },
  ),
];

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.first == 'help') {
    _printUsage();
    return;
  }

  switch (arguments.first) {
    case 'build':
      await buildAll();
      return;
    case 'verify':
      await verifyAll();
      return;
    case 'load':
      await runLoad(arguments.skip(1).toList());
      return;
    case 'suite':
      await runSuite(arguments.skip(1).toList());
      return;
    default:
      stderr.writeln('Unknown command: ${arguments.first}');
      _printUsage();
      exitCode = 64;
  }
}

Future<void> buildAll() async {
  await buildDirectory.create(recursive: true);
  for (final fixture in fixtures) {
    stdout.writeln('BUILD ${fixture.name}');
    for (final command in fixture.buildSteps) {
      await _runCommand(fixture, command);
    }
  }
}

Future<void> verifyAll() async {
  _requireBuilds();
  final running = await _startFixtures();
  try {
    for (final fixture in fixtures) {
      await _waitUntilReady(fixture);
      await _verifyFixture(fixture);
      stdout.writeln('PASS ${fixture.name}');
    }
    await _verifyNativeTransports();
    stdout.writeln('PASS native RPC transports');
  } finally {
    await _stopFixtures(running);
  }
}

Future<void> runLoad(List<String> arguments) async {
  _requireBuilds();
  final scenario = _option(arguments, '--scenario') ?? 'json';
  final duration = _option(arguments, '--duration') ?? '30s';
  final connections = _option(arguments, '--connections') ?? '64';
  final fixtureName = _option(arguments, '--fixture');
  if (!{
    'plaintext',
    'json',
    'echo',
    'catalog',
    'checkout',
  }.contains(scenario)) {
    throw ArgumentError.value(scenario, '--scenario');
  }
  final selectedFixtures = fixtureName == null
      ? fixtures
      : fixtures.where((fixture) => fixture.name == fixtureName).toList();
  if (selectedFixtures.isEmpty) {
    throw ArgumentError.value(fixtureName, '--fixture');
  }

  final oha = await Process.run('which', ['oha']);
  if (oha.exitCode != 0) {
    throw StateError(
      'oha is required for load runs. Install it, then retry this command.',
    );
  }

  final resultsDirectory = Directory('${benchmarkRoot.path}/results');
  await resultsDirectory.create(recursive: true);
  final running = await _startFixtures(selectedFixtures);
  try {
    for (final fixture in selectedFixtures) {
      await _waitUntilReady(fixture);
    }

    for (final fixture in selectedFixtures) {
      final output = File(
        '${resultsDirectory.path}/${fixture.name}_$scenario.json',
      );
      final ohaArguments = [
        '--no-tui',
        '-z',
        duration,
        '-c',
        connections,
        '--output-format',
        'json',
      ];
      if (scenario == 'echo' || scenario == 'checkout') {
        ohaArguments.addAll([
          '-m',
          'POST',
          '-H',
          'content-type: application/json',
          '-d',
          scenario == 'echo'
              ? jsonEncode(echoPayload)
              : await _checkoutPayloadText(),
        ]);
      }
      final path = scenario == 'catalog' ? catalogPath : '/$scenario';
      ohaArguments.add('http://127.0.0.1:${fixture.port}$path');

      stdout.writeln('LOAD ${fixture.name} $scenario');
      final result = await Process.run('oha', ohaArguments);
      if (result.exitCode != 0) {
        throw ProcessException('oha', ohaArguments, '${result.stderr}');
      }
      await output.writeAsString('${result.stdout}\n');
    }
  } finally {
    await _stopFixtures(running);
  }
}

Future<void> runSuite(List<String> arguments) async {
  _requireBuilds();
  final duration = _option(arguments, '--duration') ?? '10s';
  final connections = int.parse(_option(arguments, '--connections') ?? '64');
  final sampleMilliseconds = int.parse(
    _option(arguments, '--sample-ms') ?? '250',
  );
  final cooldownSeconds = int.parse(
    _option(arguments, '--cooldown-seconds') ?? '2',
  );
  final warmup = _option(arguments, '--warmup') ?? '2s';
  final requestedRate = _option(arguments, '--rate');
  final rate = requestedRate == null ? null : int.parse(requestedRate);
  final requestedScenarios = _option(arguments, '--scenarios');
  final scenarios = requestedScenarios == null
      ? benchmarkScenarios
      : requestedScenarios.split(',').map((value) => value.trim()).toList();
  for (final scenario in scenarios) {
    if (!benchmarkScenarios.contains(scenario)) {
      throw ArgumentError.value(scenario, '--scenarios');
    }
  }
  if (connections < 1 ||
      sampleMilliseconds < 50 ||
      cooldownSeconds < 0 ||
      rate != null && rate < 1) {
    throw ArgumentError('Invalid suite sampling configuration.');
  }

  await _requireOha();
  final session = await _createSuiteSession(
    duration: duration,
    connections: connections,
    sampleMilliseconds: sampleMilliseconds,
    cooldownSeconds: cooldownSeconds,
    warmup: warmup,
    rate: rate,
    scenarios: scenarios,
  );
  final results = <SuiteResult>[];

  stdout.writeln('SESSION ${session.directory.path}');
  for (final scenario in scenarios) {
    for (final fixture in fixtures) {
      stdout.writeln('SUITE ${fixture.name} $scenario');
      results.add(
        await _runSuiteSample(
          session,
          fixture: fixture,
          scenario: scenario,
          duration: duration,
          connections: connections,
          warmup: warmup,
          rate: rate,
          sampleInterval: Duration(milliseconds: sampleMilliseconds),
          cooldown: Duration(seconds: cooldownSeconds),
        ),
      );
    }
  }

  await _writeSuiteMetadata(session, results);
  await _writeSuiteReport(session, results);
  stdout.writeln('REPORT ${session.directory.path}/README.md');
}

const benchmarkScenarios = ['plaintext', 'json', 'echo', 'catalog', 'checkout'];

Future<SuiteResult> _runSuiteSample(
  SuiteSession session, {
  required Fixture fixture,
  required String scenario,
  required String duration,
  required int connections,
  required String warmup,
  required int? rate,
  required Duration sampleInterval,
  required Duration cooldown,
}) async {
  final serverOutput = StringBuffer();
  final gcOutput = StringBuffer();
  final existingVmOptions = Platform.environment['DART_VM_OPTIONS']?.trim();
  final processUptime = Stopwatch()..start();
  final process = await Process.start(
    '${buildDirectory.path}/${fixture.executable}',
    const [],
    workingDirectory: '${benchmarkRoot.path}/${fixture.directory}',
    environment: {
      ...Platform.environment,
      'PORT': '${fixture.port}',
      'DART_VM_OPTIONS': [
        if (existingVmOptions != null && existingVmOptions.isNotEmpty)
          existingVmOptions,
        '--verbose-gc',
      ].join(' '),
      ...fixture.environment,
    },
  );
  process.stdout.transform(utf8.decoder).listen(serverOutput.write);
  process.stderr.transform(utf8.decoder).listen((output) {
    serverOutput.write(output);
    gcOutput.write(output);
  });

  try {
    await _waitUntilReady(fixture);
    final samples = <ProcessResourceSample>[
      await _readProcessSample(process.pid, phase: 'idle', index: 0),
    ];
    final warmupArguments = await _ohaArguments(
      fixture,
      scenario: scenario,
      duration: warmup,
      connections: '$connections',
      rate: rate,
    );
    final warmupResult = await Process.run('oha', warmupArguments);
    if (warmupResult.exitCode != 0) {
      throw ProcessException(
        'oha',
        warmupArguments,
        '${warmupResult.stderr}',
        warmupResult.exitCode,
      );
    }
    final ohaArguments = await _ohaArguments(
      fixture,
      scenario: scenario,
      duration: duration,
      connections: '$connections',
      rate: rate,
    );
    final loadStartSeconds =
        processUptime.elapsedMicroseconds / Duration.microsecondsPerSecond;
    final load = await Process.start('oha', ohaArguments);
    final loadOutput = load.stdout.transform(utf8.decoder).join();
    final loadError = load.stderr.transform(utf8.decoder).join();
    var finished = false;
    final exitCodeFuture = load.exitCode.then((exitCode) {
      finished = true;
      return exitCode;
    });
    var sampleIndex = 0;
    while (!finished) {
      samples.add(
        await _readProcessSample(
          process.pid,
          phase: 'load',
          index: sampleIndex++,
        ),
      );
      await Future<void>.delayed(sampleInterval);
    }
    final exitCode = await exitCodeFuture;
    final loadEndSeconds =
        processUptime.elapsedMicroseconds / Duration.microsecondsPerSecond;
    final rawJson = await loadOutput;
    final error = await loadError;
    if (exitCode != 0) {
      throw ProcessException('oha', ohaArguments, error, exitCode);
    }

    if (cooldown > Duration.zero) {
      await Future<void>.delayed(cooldown);
    }
    samples.add(
      await _readProcessSample(
        process.pid,
        phase: 'cooldown',
        index: sampleIndex,
      ),
    );

    final rateSuffix = rate == null ? '' : '-q$rate';
    final stem = '${fixture.name}-$scenario-$duration-c$connections$rateSuffix';
    await File(
      '${session.loadDirectory.path}/$stem.json',
    ).writeAsString('$rawJson\n');
    await File(
      '${session.resourceDirectory.path}/$stem.tsv',
    ).writeAsString(_resourceSamplesTsv(samples));
    await File(
      '${session.logDirectory.path}/$stem.log',
    ).writeAsString(serverOutput.toString());
    await File(
      '${session.gcDirectory.path}/$stem.log',
    ).writeAsString(gcOutput.toString());

    return SuiteResult.fromRaw(
      fixture: fixture.name,
      scenario: scenario,
      raw: jsonDecode(rawJson) as Map<String, dynamic>,
      samples: samples,
      gc: GcMetrics.parse(
        gcOutput.toString(),
        startSeconds: loadStartSeconds,
        endSeconds: loadEndSeconds,
      ),
    );
  } finally {
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}

Future<List<String>> _ohaArguments(
  Fixture fixture, {
  required String scenario,
  required String duration,
  required String connections,
  int? rate,
}) async {
  final arguments = [
    '--no-tui',
    '-z',
    duration,
    '-c',
    connections,
    '--output-format',
    'json',
  ];
  if (rate != null) {
    arguments.addAll(['-q', '$rate']);
  }
  if (scenario == 'echo' || scenario == 'checkout') {
    arguments.addAll([
      '-m',
      'POST',
      '-H',
      'content-type: application/json',
      '-d',
      scenario == 'echo'
          ? jsonEncode(echoPayload)
          : await _checkoutPayloadText(),
    ]);
  }
  final path = scenario == 'catalog' ? catalogPath : '/$scenario';
  arguments.add('http://127.0.0.1:${fixture.port}$path');
  return arguments;
}

Future<ProcessResourceSample> _readProcessSample(
  int pid, {
  required String phase,
  required int index,
}) async {
  final result = await Process.run('ps', [
    '-p',
    '$pid',
    '-o',
    '%cpu=',
    '-o',
    'rss=',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Unable to sample process $pid: ${result.stderr}');
  }
  final values = '${result.stdout}'.trim().split(RegExp(r'\s+'));
  if (values.length != 2) {
    throw StateError('Unexpected ps output for process $pid.');
  }
  return ProcessResourceSample(
    phase: phase,
    index: index,
    cpuPercent: double.parse(values[0]),
    rssKib: int.parse(values[1]),
  );
}

String _resourceSamplesTsv(List<ProcessResourceSample> samples) {
  final output = StringBuffer('phase\tsample\tcpu_percent\trss_kib\n');
  for (final sample in samples) {
    output.writeln(
      '${sample.phase}\t${sample.index}\t${sample.cpuPercent}\t${sample.rssKib}',
    );
  }
  return output.toString();
}

Future<void> _requireOha() async {
  final result = await Process.run('which', ['oha']);
  if (result.exitCode != 0) {
    throw StateError(
      'oha is required for benchmark runs. Install it, then retry.',
    );
  }
}

Future<SuiteSession> _createSuiteSession({
  required String duration,
  required int connections,
  required int sampleMilliseconds,
  required int cooldownSeconds,
  required String warmup,
  required int? rate,
  required List<String> scenarios,
}) async {
  final commitResult = await Process.run('git', [
    'rev-parse',
    '--short',
    'HEAD',
  ]);
  final statusResult = await Process.run('git', ['status', '--porcelain']);
  final commit = '${commitResult.stdout}'.trim();
  final changedPaths = '${statusResult.stdout}'
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .length;
  final now = DateTime.now();
  final timestamp =
      '${now.year}-${_two(now.month)}-${_two(now.day)}-'
      '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  final baseName = '$timestamp-$commit';
  var directory = Directory('${benchmarkRoot.path}/results/$baseName');
  var suffix = 2;
  while (directory.existsSync()) {
    directory = Directory('${benchmarkRoot.path}/results/$baseName-$suffix');
    suffix++;
  }
  final loadDirectory = Directory('${directory.path}/load');
  final resourceDirectory = Directory('${directory.path}/resources');
  final logDirectory = Directory('${directory.path}/logs');
  final gcDirectory = Directory('${directory.path}/gc');
  await Future.wait([
    loadDirectory.create(recursive: true),
    resourceDirectory.create(recursive: true),
    logDirectory.create(recursive: true),
    gcDirectory.create(recursive: true),
  ]);

  return SuiteSession(
    directory: directory,
    loadDirectory: loadDirectory,
    resourceDirectory: resourceDirectory,
    logDirectory: logDirectory,
    gcDirectory: gcDirectory,
    createdAt: now,
    commit: commit,
    changedPathCount: changedPaths,
    duration: duration,
    connections: connections,
    sampleMilliseconds: sampleMilliseconds,
    cooldownSeconds: cooldownSeconds,
    warmup: warmup,
    rate: rate,
    scenarios: List.unmodifiable(scenarios),
  );
}

Future<void> _writeSuiteMetadata(
  SuiteSession session,
  List<SuiteResult> results,
) async {
  final cpu = await _commandOutput('sysctl', [
    '-n',
    'machdep.cpu.brand_string',
  ]);
  final memory = int.tryParse(
    await _commandOutput('sysctl', ['-n', 'hw.memsize']),
  );
  final os = await _commandOutput('uname', ['-a']);
  final dart = await _commandOutput('dart', ['--version'], includeStderr: true);
  final oha = await _commandOutput('oha', ['--version']);
  final metadata = {
    'createdAt': session.createdAt.toIso8601String(),
    'commit': session.commit,
    'worktree': session.changedPathCount == 0 ? 'clean' : 'dirty',
    'changedPathCount': session.changedPathCount,
    'duration': session.duration,
    'connections': session.connections,
    'sampleMilliseconds': session.sampleMilliseconds,
    'cooldownSeconds': session.cooldownSeconds,
    'warmup': session.warmup,
    'rate': session.rate,
    'mode': session.rate == null ? 'saturation' : 'fixed-rate',
    'scenarios': session.scenarios,
    'fixtureOrder': [for (final fixture in fixtures) fixture.name],
    'runsPerCombination': 1,
    'machine': {'os': os, 'cpu': cpu, 'memoryBytes': memory},
    'tools': {'dart': dart, 'oha': oha},
    'completedResponses': results.fold<int>(
      0,
      (total, result) => total + result.completedResponses,
    ),
    'allResponsesSuccessful': results.every(
      (result) => result.successRate == 1,
    ),
    'gc': {
      'enabled': true,
      'scope': 'measured load window',
      'totalEvents': results.fold<int>(
        0,
        (total, result) => total + result.gc.eventCount,
      ),
      'totalTimeMilliseconds': results.fold<double>(
        0,
        (total, result) => total + result.gc.totalTimeMilliseconds,
      ),
    },
  };
  await File(
    '${session.directory.path}/metadata.json',
  ).writeAsString('${const JsonEncoder.withIndent('  ').convert(metadata)}\n');
}

Future<String> _commandOutput(
  String executable,
  List<String> arguments, {
  bool includeStderr = false,
}) async {
  final result = await Process.run(executable, arguments);
  final output = includeStderr && '${result.stdout}'.trim().isEmpty
      ? result.stderr
      : result.stdout;
  return '$output'.trim();
}

Future<void> _writeSuiteReport(
  SuiteSession session,
  List<SuiteResult> results,
) async {
  final output = StringBuffer()
    ..writeln('# Framework benchmark — ${_date(session.createdAt)}')
    ..writeln()
    ..writeln('Generated by `dart run benchmarks/tool/benchmark.dart suite`.')
    ..writeln()
    ..writeln('## Configuration')
    ..writeln()
    ..writeln('- Duration: ${session.duration} per fixture and scenario')
    ..writeln('- Connections: ${session.connections}')
    ..writeln('- Warm-up: ${session.warmup} per fixture and scenario')
    ..writeln(
      '- Mode: ${session.rate == null ? 'closed-loop saturation' : 'fixed rate (${session.rate} requests/second)'}',
    )
    ..writeln('- CPU/RSS sample interval: ${session.sampleMilliseconds} ms')
    ..writeln('- GC telemetry: Dart VM verbose GC enabled')
    ..writeln('- Cooldown: ${session.cooldownSeconds} seconds')
    ..writeln('- Commit: `${session.commit}`')
    ..writeln(
      '- Worktree: ${session.changedPathCount == 0 ? 'clean' : 'dirty (${session.changedPathCount} changed/untracked paths)'}',
    )
    ..writeln(
      '- Fixture order: ${fixtures.map((item) => item.name).join(', ')}',
    )
    ..writeln('- Runs per combination: 1')
    ..writeln()
    ..writeln(
      'This is a local, stable-order, single-sample regression run. It is not '
      'a publishable baseline.',
    )
    ..writeln()
    ..writeln('## Results')
    ..writeln()
    ..writeln(
      '| Track | Scenario | Fixture | req/s | req/s per CPU% | p50 | p90 | p99 | p99.9 | Avg CPU | Peak RSS | Success |',
    )
    ..writeln(
      '| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    );
  for (final scenario in session.scenarios) {
    for (final result in results.where((item) => item.scenario == scenario)) {
      output.writeln(
        '| ${_trackFor(scenario)} | $scenario | ${_label(result.fixture)} | '
        '${_number(result.requestsPerSecond, 0)} | '
        '${_number(result.requestsPerSecondPerCpuPoint, 1)} | '
        '${_number(result.p50Milliseconds, 2)} ms | '
        '${_number(result.p90Milliseconds, 2)} ms | '
        '${_number(result.p99Milliseconds, 2)} ms | '
        '${_number(result.p999Milliseconds, 2)} ms | '
        '${_number(result.averageCpuPercent, 1)}% | '
        '${_number(result.peakRssMib, 1)} MiB | '
        '${_number(result.successRate * 100, 1)}% |',
      );
    }
  }

  output
    ..writeln()
    ..writeln('## Garbage collection')
    ..writeln()
    ..writeln('GC metrics cover only the measured load window.')
    ..writeln()
    ..writeln(
      '| Track | Scenario | Fixture | Events | Major/concurrent | Total GC | GC ms/100k requests | Avg pause | Max pause |',
    )
    ..writeln('| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (final scenario in session.scenarios) {
    for (final result in results.where((item) => item.scenario == scenario)) {
      output.writeln(
        '| ${_trackFor(scenario)} | $scenario | ${_label(result.fixture)} | '
        '${result.gc.eventCount} | '
        '${result.gc.majorOrConcurrentEventCount} | '
        '${_number(result.gc.totalTimeMilliseconds, 1)} ms | '
        '${_number(result.gcMillisecondsPer100kRequests, 2)} ms | '
        '${_number(result.gc.averagePauseMilliseconds, 3)} ms | '
        '${_number(result.gc.maximumPauseMilliseconds, 1)} ms |',
      );
    }
  }

  output
    ..writeln()
    ..writeln('## Where dart_orpc was better or worse')
    ..writeln();
  for (final scenario in session.scenarios) {
    final scenarioResults = results
        .where((result) => result.scenario == scenario)
        .toList();
    output
      ..writeln('### ${_title(scenario)}')
      ..writeln()
      ..writeln(
        _scenarioComparison(scenarioResults, requestedRate: session.rate),
      )
      ..writeln();
  }

  output
    ..writeln('## Interpretation notes')
    ..writeln()
    ..writeln(
      '- CPU can exceed 100% when a process uses more than one logical core.',
    )
    ..writeln(
      session.rate == null
          ? '- Saturation-mode raw CPU is not ranked because each framework completes a different amount of work; compare requests/second per CPU-point.'
          : '- Fixed-rate CPU is directly comparable when every fixture sustains the requested rate.',
    )
    ..writeln(
      '- Deadline-aborted in-flight requests at the end of an `oha` window are not completed HTTP failures.',
    )
    ..writeln(
      '- Raw load JSON, resource samples, and server logs are preserved under `load/`, `resources/`, and `logs/`.',
    )
    ..writeln(
      '- Raw verbose-GC output is preserved under `gc/`; verbose GC adds diagnostic overhead and may affect absolute performance.',
    )
    ..writeln(
      '- Publishable conclusions require randomized order and at least five runs per combination.',
    );

  await File(
    '${session.directory.path}/README.md',
  ).writeAsString(output.toString());
}

String _scenarioComparison(
  List<SuiteResult> results, {
  required int? requestedRate,
}) {
  final dartOrpc = results.singleWhere(
    (result) => result.fixture == 'dart_orpc',
  );
  final competitors = results
      .where((result) => result.fixture != 'dart_orpc')
      .toList();
  final throughputCompetitor = competitors.reduce(
    (left, right) =>
        left.requestsPerSecond >= right.requestsPerSecond ? left : right,
  );
  final p50Competitor = competitors.reduce(
    (left, right) =>
        left.p50Milliseconds <= right.p50Milliseconds ? left : right,
  );
  final p99Competitor = competitors.reduce(
    (left, right) =>
        left.p99Milliseconds <= right.p99Milliseconds ? left : right,
  );
  final p999Competitor = competitors.reduce(
    (left, right) =>
        left.p999Milliseconds <= right.p999Milliseconds ? left : right,
  );
  final cpuCompetitor = competitors.reduce(
    (left, right) =>
        left.averageCpuPercent <= right.averageCpuPercent ? left : right,
  );
  final cpuEfficiencyCompetitor = competitors.reduce(
    (left, right) =>
        left.requestsPerSecondPerCpuPoint >= right.requestsPerSecondPerCpuPoint
        ? left
        : right,
  );
  final memoryCompetitor = competitors.reduce(
    (left, right) => left.peakRssMib <= right.peakRssMib ? left : right,
  );
  final normalizedGcCompetitor = competitors.reduce(
    (left, right) =>
        left.gcMillisecondsPer100kRequests <=
            right.gcMillisecondsPer100kRequests
        ? left
        : right,
  );
  final maxGcPauseCompetitor = competitors.reduce(
    (left, right) =>
        left.gc.maximumPauseMilliseconds <= right.gc.maximumPauseMilliseconds
        ? left
        : right,
  );
  final allSustainedRequestedRate =
      requestedRate != null &&
      results.every(
        (result) =>
            result.requestsPerSecond >= requestedRate * 0.98 &&
            result.successRate == 1,
      );
  final comparisons = [
    requestedRate == null
        ? '- Throughput: ${_higherComparison(dartOrpc.requestsPerSecond, throughputCompetitor.requestsPerSecond, throughputCompetitor.fixture)}'
        : '- Throughput target: ${_rateComparison(dartOrpc, requestedRate)}',
    '- p50 latency: ${_lowerComparison(dartOrpc.p50Milliseconds, p50Competitor.p50Milliseconds, p50Competitor.fixture)}',
    '- p99 latency: ${_lowerComparison(dartOrpc.p99Milliseconds, p99Competitor.p99Milliseconds, p99Competitor.fixture)}',
    '- p99.9 latency: ${_lowerComparison(dartOrpc.p999Milliseconds, p999Competitor.p999Milliseconds, p999Competitor.fixture)}',
    '- CPU efficiency: ${_higherComparison(dartOrpc.requestsPerSecondPerCpuPoint, cpuEfficiencyCompetitor.requestsPerSecondPerCpuPoint, cpuEfficiencyCompetitor.fixture)}',
    '- Peak RSS: ${_lowerComparison(dartOrpc.peakRssMib, memoryCompetitor.peakRssMib, memoryCompetitor.fixture)}',
    '- GC time per 100k requests: ${_lowerComparison(dartOrpc.gcMillisecondsPer100kRequests, normalizedGcCompetitor.gcMillisecondsPer100kRequests, normalizedGcCompetitor.fixture)}',
    '- Maximum GC pause: ${_lowerComparison(dartOrpc.gc.maximumPauseMilliseconds, maxGcPauseCompetitor.gc.maximumPauseMilliseconds, maxGcPauseCompetitor.fixture)}',
  ];
  if (allSustainedRequestedRate) {
    comparisons.insert(
      5,
      '- Average CPU: ${_lowerComparison(dartOrpc.averageCpuPercent, cpuCompetitor.averageCpuPercent, cpuCompetitor.fixture)}',
    );
  } else if (requestedRate != null) {
    comparisons.insert(
      5,
      '- Average CPU: ${_number(dartOrpc.averageCpuPercent, 1)}%; not ranked because at least one fixture did not sustain 98% of the requested rate with 100% success.',
    );
  } else {
    comparisons.insert(
      5,
      '- Average CPU: ${_number(dartOrpc.averageCpuPercent, 1)}%; not ranked in saturation mode because throughput differs.',
    );
  }
  return comparisons.join('\n');
}

String _rateComparison(SuiteResult result, int requestedRate) {
  final achievedPercent = result.requestsPerSecond / requestedRate * 100;
  return achievedPercent >= 98 && result.successRate == 1
      ? '🟢 dart_orpc sustained ${_number(achievedPercent, 1)}% of the requested rate.'
      : '🔴 dart_orpc sustained only ${_number(achievedPercent, 1)}% of the requested rate.';
}

String _higherComparison(double dartValue, double competitor, String fixture) {
  final difference = (dartValue / competitor - 1) * 100;
  return difference >= 0
      ? '🟢 dart_orpc was ${_number(difference, 1)}% higher than the strongest competitor (${_label(fixture)}).'
      : '🔴 dart_orpc was ${_number(-difference, 1)}% lower than the leader (${_label(fixture)}).';
}

String _lowerComparison(double dartValue, double competitor, String fixture) {
  if (competitor == 0) {
    return dartValue == 0
        ? '🟢 dart_orpc matched the best competitor (${_label(fixture)}) at zero.'
        : '🔴 dart_orpc recorded ${_number(dartValue, 1)} while the best competitor (${_label(fixture)}) recorded zero.';
  }
  final difference = (dartValue / competitor - 1) * 100;
  if (difference.abs() < 0.05) {
    return '🟢 dart_orpc matched the best competitor (${_label(fixture)}) within 0.1%.';
  }
  return difference <= 0
      ? '🟢 dart_orpc was ${_number(-difference, 1)}% lower than the best competitor (${_label(fixture)}).'
      : '🔴 dart_orpc was ${_number(difference, 1)}% higher than the best competitor (${_label(fixture)}).';
}

String _trackFor(String scenario) {
  return const {'plaintext', 'json', 'echo'}.contains(scenario)
      ? 'Micro'
      : 'Application';
}

String _label(String fixture) => switch (fixture) {
  'dart_orpc' => 'dart_orpc',
  'shelf' => 'Shelf',
  'dart_frog' => 'Dart Frog',
  'serverpod' => 'Serverpod',
  _ => fixture,
};

String _title(String value) => value
    .replaceAll('json', 'JSON')
    .split('_')
    .map(
      (part) => part == 'JSON'
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String _number(double value, int decimals) => value.toStringAsFixed(decimals);

String _date(DateTime value) =>
    '${value.year}-${_two(value.month)}-${_two(value.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

Future<List<Process>> _startFixtures([List<Fixture>? selectedFixtures]) async {
  final processes = <Process>[];
  for (final fixture in selectedFixtures ?? fixtures) {
    final process = await Process.start(
      '${buildDirectory.path}/${fixture.executable}',
      const [],
      workingDirectory: '${benchmarkRoot.path}/${fixture.directory}',
      environment: {
        ...Platform.environment,
        'PORT': '${fixture.port}',
        ...fixture.environment,
      },
    );
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    processes.add(process);
  }
  return processes;
}

Future<void> _stopFixtures(List<Process> processes) async {
  for (final process in processes) {
    process.kill(ProcessSignal.sigterm);
  }
  await Future.wait(
    processes.map(
      (process) => process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      ),
    ),
  );
}

Future<void> _waitUntilReady(Fixture fixture) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  Object? lastError;
  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await _request(fixture, '/plaintext');
      if (response.statusCode == HttpStatus.ok) return;
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('${fixture.name} did not become ready: $lastError');
}

Future<void> _verifyFixture(Fixture fixture) async {
  final plaintext = await _request(fixture, '/plaintext');
  _expect(plaintext.statusCode == 200, '${fixture.name} plaintext status');
  _expect(plaintext.body == 'Hello, World!', '${fixture.name} plaintext body');

  final jsonResponse = await _request(fixture, '/json');
  _expect(jsonResponse.statusCode == 200, '${fixture.name} json status');
  _expect(
    const DeepCollectionEquality().equals(jsonDecode(jsonResponse.body), const {
      'message': 'Hello, World!',
    }),
    '${fixture.name} json body',
  );

  final echo = await _request(
    fixture,
    '/echo',
    method: 'POST',
    body: jsonEncode(echoPayload),
  );
  _expect(echo.statusCode == 200, '${fixture.name} echo status');
  _expect(
    const DeepCollectionEquality().equals(jsonDecode(echo.body), echoPayload),
    '${fixture.name} echo body',
  );

  final catalog = await _request(fixture, catalogPath);
  _expect(catalog.statusCode == 200, '${fixture.name} catalog status');
  _expect(
    const DeepCollectionEquality().equals(
      jsonDecode(catalog.body),
      buildCatalog(category: 'books', page: 2, limit: 10),
    ),
    '${fixture.name} catalog body',
  );

  final checkoutInput = jsonDecode(await _checkoutPayloadText());
  final checkout = await _request(
    fixture,
    '/checkout',
    method: 'POST',
    body: jsonEncode(checkoutInput),
  );
  _expect(checkout.statusCode == 200, '${fixture.name} checkout status');
  _expect(
    const DeepCollectionEquality().equals(
      jsonDecode(checkout.body),
      processCheckout(checkoutInput),
    ),
    '${fixture.name} checkout body',
  );

  final invalidCatalog = await _request(
    fixture,
    '/catalog?category=&page=0&limit=101',
  );
  _expect(
    invalidCatalog.statusCode == HttpStatus.badRequest,
    '${fixture.name} invalid catalog status',
  );

  final invalidCheckout = await _request(
    fixture,
    '/checkout',
    method: 'POST',
    body: jsonEncode({
      'customer': {'id': 'customer-42'},
      'currency': 'USD',
      'items': const [],
    }),
  );
  _expect(
    invalidCheckout.statusCode == HttpStatus.badRequest,
    '${fixture.name} invalid checkout status',
  );
}

Future<String> _checkoutPayloadText() {
  return File('${benchmarkRoot.path}/payloads/checkout.json').readAsString();
}

Future<void> _verifyNativeTransports() async {
  final dartOrpc = await _requestAtPort(
    18081,
    '/rpc',
    method: 'POST',
    body: jsonEncode({
      'method': 'benchmark.echo',
      'input': const {'message': 'benchmark'},
    }),
  );
  _expect(dartOrpc.statusCode == 200, 'dart_orpc RPC status');
  final dartOrpcBody = jsonDecode(dartOrpc.body) as Map<String, dynamic>;
  _expect(
    const DeepCollectionEquality().equals(dartOrpcBody['data'], const {
      'message': 'benchmark',
    }),
    'dart_orpc RPC body',
  );

  final serverpod = await _requestAtPort(
    18084,
    '/benchmark',
    method: 'POST',
    body: jsonEncode({
      'method': 'echo',
      'input': const {'message': 'benchmark'},
    }),
  );
  _expect(serverpod.statusCode == 200, 'Serverpod RPC status');
  _expect(
    const DeepCollectionEquality().equals(jsonDecode(serverpod.body), const {
      'message': 'benchmark',
    }),
    'Serverpod RPC body',
  );
}

Future<HttpResult> _request(
  Fixture fixture,
  String path, {
  String method = 'GET',
  String? body,
}) => _requestAtPort(fixture.port, path, method: method, body: body);

Future<HttpResult> _requestAtPort(
  int port,
  String path, {
  String method = 'GET',
  String? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    return HttpResult(
      response.statusCode,
      await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

Future<void> _runCommand(Fixture fixture, Command command) async {
  final workingDirectory = command.workingDirectory == null
      ? '${benchmarkRoot.path}/${fixture.directory}'
      : Directory(
          '${benchmarkRoot.path}/${fixture.directory}/${command.workingDirectory}',
        ).absolute.path;
  final result = await Process.start(
    command.executable,
    command.arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
      command.executable,
      command.arguments,
      'Build command failed for ${fixture.name}.',
      exitCode,
    );
  }
}

void _requireBuilds() {
  for (final fixture in fixtures) {
    final executable = File('${buildDirectory.path}/${fixture.executable}');
    if (!executable.existsSync()) {
      throw StateError('Missing ${executable.path}; run `build` first.');
    }
  }
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1) return null;
  if (index + 1 == arguments.length) {
    throw ArgumentError('Missing value for $name.');
  }
  return arguments[index + 1];
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError('Verification failed: $message');
}

void _printUsage() {
  stdout.writeln('''
Usage: dart run benchmarks/tool/benchmark.dart <command>

Commands:
  build
  verify
  load [--scenario plaintext|json|echo|catalog|checkout]
       [--duration 30s] [--connections 64]
       [--fixture dart_orpc|shelf|dart_frog|serverpod]
  suite [--duration 10s] [--connections 64] [--sample-ms 250]
        [--warmup 2s] [--cooldown-seconds 2] [--rate requests-per-second]
        [--scenarios plaintext,json,echo,catalog,checkout]
''');
}

final class SuiteSession {
  const SuiteSession({
    required this.directory,
    required this.loadDirectory,
    required this.resourceDirectory,
    required this.logDirectory,
    required this.gcDirectory,
    required this.createdAt,
    required this.commit,
    required this.changedPathCount,
    required this.duration,
    required this.connections,
    required this.sampleMilliseconds,
    required this.cooldownSeconds,
    required this.warmup,
    required this.rate,
    required this.scenarios,
  });

  final Directory directory;
  final Directory loadDirectory;
  final Directory resourceDirectory;
  final Directory logDirectory;
  final Directory gcDirectory;
  final DateTime createdAt;
  final String commit;
  final int changedPathCount;
  final String duration;
  final int connections;
  final int sampleMilliseconds;
  final int cooldownSeconds;
  final String warmup;
  final int? rate;
  final List<String> scenarios;
}

final class ProcessResourceSample {
  const ProcessResourceSample({
    required this.phase,
    required this.index,
    required this.cpuPercent,
    required this.rssKib,
  });

  final String phase;
  final int index;
  final double cpuPercent;
  final int rssKib;
}

final class GcMetrics {
  const GcMetrics({
    required this.eventCount,
    required this.majorOrConcurrentEventCount,
    required this.totalTimeMilliseconds,
    required this.maximumPauseMilliseconds,
  });

  factory GcMetrics.parse(
    String output, {
    required double startSeconds,
    required double endSeconds,
  }) {
    var eventCount = 0;
    var majorOrConcurrentEventCount = 0;
    var totalTimeMilliseconds = 0.0;
    var maximumPauseMilliseconds = 0.0;
    final eventPattern = RegExp(
      r'^\[\s*main\s*,\s*([^,]+),\s*\d+,\s*([\d.]+),\s*([\d.]+),',
    );

    for (final line in const LineSplitter().convert(output)) {
      final match = eventPattern.firstMatch(line);
      if (match == null) continue;
      final reason = match.group(1)!.toLowerCase();
      final eventStartSeconds = double.parse(match.group(2)!);
      if (eventStartSeconds < startSeconds || eventStartSeconds > endSeconds) {
        continue;
      }
      final pauseMilliseconds = double.parse(match.group(3)!);
      eventCount++;
      totalTimeMilliseconds += pauseMilliseconds;
      if (pauseMilliseconds > maximumPauseMilliseconds) {
        maximumPauseMilliseconds = pauseMilliseconds;
      }
      if (reason.contains('old space') ||
          reason.contains('mark') ||
          reason.contains('sweep') ||
          reason.contains('compact') ||
          reason.contains('concurrent')) {
        majorOrConcurrentEventCount++;
      }
    }

    return GcMetrics(
      eventCount: eventCount,
      majorOrConcurrentEventCount: majorOrConcurrentEventCount,
      totalTimeMilliseconds: totalTimeMilliseconds,
      maximumPauseMilliseconds: maximumPauseMilliseconds,
    );
  }

  final int eventCount;
  final int majorOrConcurrentEventCount;
  final double totalTimeMilliseconds;
  final double maximumPauseMilliseconds;

  double get averagePauseMilliseconds =>
      eventCount == 0 ? 0 : totalTimeMilliseconds / eventCount;
}

final class SuiteResult {
  const SuiteResult({
    required this.fixture,
    required this.scenario,
    required this.requestsPerSecond,
    required this.p50Milliseconds,
    required this.p90Milliseconds,
    required this.p99Milliseconds,
    required this.p999Milliseconds,
    required this.successRate,
    required this.completedResponses,
    required this.averageCpuPercent,
    required this.peakCpuPercent,
    required this.idleRssMib,
    required this.peakRssMib,
    required this.cooldownRssMib,
    required this.gc,
  });

  factory SuiteResult.fromRaw({
    required String fixture,
    required String scenario,
    required Map<String, dynamic> raw,
    required List<ProcessResourceSample> samples,
    required GcMetrics gc,
  }) {
    final summary = raw['summary'] as Map<String, dynamic>;
    final latency = raw['latencyPercentiles'] as Map<String, dynamic>;
    final statusCodes = raw['statusCodeDistribution'] as Map<String, dynamic>;
    final loadSamples = samples
        .where((sample) => sample.phase == 'load')
        .toList();
    final idle = samples.firstWhere((sample) => sample.phase == 'idle');
    final cooldown = samples.lastWhere((sample) => sample.phase == 'cooldown');
    return SuiteResult(
      fixture: fixture,
      scenario: scenario,
      requestsPerSecond: (summary['requestsPerSec'] as num).toDouble(),
      p50Milliseconds: (latency['p50'] as num).toDouble() * 1000,
      p90Milliseconds: (latency['p90'] as num).toDouble() * 1000,
      p99Milliseconds: (latency['p99'] as num).toDouble() * 1000,
      p999Milliseconds: (latency['p99.9'] as num).toDouble() * 1000,
      successRate: (summary['successRate'] as num).toDouble(),
      completedResponses: statusCodes.values.fold<int>(
        0,
        (total, count) => total + (count as num).toInt(),
      ),
      averageCpuPercent:
          loadSamples.fold<double>(
            0,
            (total, sample) => total + sample.cpuPercent,
          ) /
          loadSamples.length,
      peakCpuPercent: loadSamples
          .map((sample) => sample.cpuPercent)
          .reduce((left, right) => left >= right ? left : right),
      idleRssMib: idle.rssKib / 1024,
      peakRssMib:
          loadSamples
              .map((sample) => sample.rssKib)
              .reduce((left, right) => left >= right ? left : right) /
          1024,
      cooldownRssMib: cooldown.rssKib / 1024,
      gc: gc,
    );
  }

  final String fixture;
  final String scenario;
  final double requestsPerSecond;
  final double p50Milliseconds;
  final double p90Milliseconds;
  final double p99Milliseconds;
  final double p999Milliseconds;
  final double successRate;
  final int completedResponses;
  final double averageCpuPercent;
  final double peakCpuPercent;
  final double idleRssMib;
  final double peakRssMib;
  final double cooldownRssMib;
  final GcMetrics gc;

  double get requestsPerSecondPerCpuPoint =>
      requestsPerSecond / averageCpuPercent;

  double get gcMillisecondsPer100kRequests => completedResponses == 0
      ? 0
      : gc.totalTimeMilliseconds / completedResponses * 100000;
}

final class Fixture {
  const Fixture({
    required this.name,
    required this.directory,
    required this.port,
    required this.buildSteps,
    required this.executable,
    this.environment = const {},
  });

  final String name;
  final String directory;
  final int port;
  final List<Command> buildSteps;
  final String executable;
  final Map<String, String> environment;
}

final class Command {
  const Command(this.executable, this.arguments, {this.workingDirectory});

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}

final class HttpResult {
  const HttpResult(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

final class DeepCollectionEquality {
  const DeepCollectionEquality();

  bool equals(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      return left.entries.every(
        (entry) =>
            right.containsKey(entry.key) &&
            equals(entry.value, right[entry.key]),
      );
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!equals(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }
}
