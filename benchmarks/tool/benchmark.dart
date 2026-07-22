import 'dart:async';
import 'dart:convert';
import 'dart:io';

final Directory benchmarkRoot = File.fromUri(
  Platform.script,
).parent.parent.absolute;
final Directory buildDirectory = Directory('${benchmarkRoot.path}/build');

const echoPayload = {'message': 'benchmark', 'count': 42, 'enabled': true};

final fixtures = <Fixture>[
  Fixture(
    name: 'dart_orpc',
    directory: 'apps/dart_orpc_benchmark',
    port: 18081,
    buildSteps: const [
      Command('dart', ['pub', 'get']),
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
  if (!{'plaintext', 'json', 'echo'}.contains(scenario)) {
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
      if (scenario == 'echo') {
        ohaArguments.addAll([
          '-m',
          'POST',
          '-H',
          'content-type: application/json',
          '-d',
          jsonEncode(echoPayload),
        ]);
      }
      ohaArguments.add('http://127.0.0.1:${fixture.port}/$scenario');

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
  load [--scenario plaintext|json|echo] [--duration 30s] [--connections 64]
       [--fixture dart_orpc|shelf|dart_frog|serverpod]
''');
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
