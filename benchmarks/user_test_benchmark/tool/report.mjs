import { execFileSync } from 'node:child_process';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const [
  repositoryRoot,
  resultDirectory,
  templateCommit,
  imageName,
  dockerPlatform,
  imageSizeBytes,
  dockerBuildSeconds,
  hostBuildSeconds,
  hostBinarySizeBytes,
  verificationSeconds,
  port,
  warmupVus,
  warmupDuration,
  rampUp,
  holdDuration,
  startVus,
  maxVus,
  vuIncrement,
  score,
  finalLabel,
  highestPassingVus,
  framework,
  appDirectory,
] = process.argv.slice(2);

const frameworkNames = {
  dart_orpc: 'dart_orpc',
  dart_frog: 'Dart Frog',
  shelf: 'Shelf',
};
const frameworkName = frameworkNames[framework];

const loadDirectory = path.join(resultDirectory, 'load');
const resourceDirectory = path.join(resultDirectory, 'resources');
const attemptsPath = path.join(resultDirectory, 'attempts.tsv');
const attempts = (await readFile(attemptsPath, 'utf8'))
  .trim()
  .split('\n')
  .filter(Boolean)
  .map((line) => {
    const [label, vus, duration, passed, exitCode] = line.split('\t');
    return {
      label,
      vus: Number(vus),
      duration,
      passed: passed === 'true',
      exitCode: Number(exitCode),
    };
  });

const gitCommit = run('git', ['rev-parse', 'HEAD'], repositoryRoot);
const gitStatus = run('git', ['status', '--porcelain'], repositoryRoot);
const lockPath = path.join(repositoryRoot, appDirectory, 'pubspec.lock');
const lockText = await readFile(lockPath, 'utf8').catch(() => '');
const finalSummary = finalLabel ? await readSummary(finalLabel) : null;
const finalAttempt = attempts.find((attempt) => attempt.label === finalLabel);
const summaryFiles = await readdir(loadDirectory);

const metadata = {
  createdAt: new Date().toISOString(),
  benchmark: 'User Test Benchmark',
  templateRepository: 'https://github.com/arjaythedev/twelve-dollar-server-challenge',
  templateCommit,
  framework,
  frameworkName,
  repositoryCommit: gitCommit.trim(),
  worktree: gitStatus.trim() === '' ? 'clean' : 'dirty',
  machine: {
    platform: `${os.type()} ${os.release()} ${os.arch()}`,
    logicalCpus: os.cpus().length,
    physicalMemoryBytes: os.totalmem(),
    dockerVersion: run('docker', ['--version']),
    k6Version: run('k6', ['version']),
    dartVersion: run('dart', ['--version']),
  },
  serverContainer: {
    image: imageName,
    platform: dockerPlatform,
    cpuLimit: 1,
    memoryLimitBytes: 2 * 1024 ** 3,
    swapLimitBytes: 0,
    imageSizeBytes: Number(imageSizeBytes),
    hostAotBinarySizeBytes: Number(hostBinarySizeBytes),
  },
  buildAndVerification: {
    hostAotBuildSeconds: Number(hostBuildSeconds),
    dockerBuildSeconds: Number(dockerBuildSeconds),
    officialTestSuiteSeconds: Number(verificationSeconds),
    dependencyLockSha256: await sha256(lockText),
  },
  loadProfile: {
    warmupVus: Number(warmupVus),
    warmupHold: warmupDuration,
    rampUp,
    summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)', 'p(99.9)'],
    scoredHold: holdDuration,
    startingVus: Number(startVus),
    maximumVus: Number(maxVus) || null,
    interactiveIncrementVus: Number(vuIncrement),
    port: Number(port),
    runnerLocation: 'same host as Docker server; use a separate machine for publishable numbers',
  },
  thresholds: {
    p95Milliseconds: '< 500',
    p99Milliseconds: '< 1000',
    failedRequestRate: '< 0.01',
  },
  score,
  highestPassingVus: Number(highestPassingVus),
  finalRun: finalAttempt == null ? null : {
    label: finalAttempt.label,
    vus: finalAttempt.vus,
    passed: finalAttempt.passed,
  },
  attempts,
  rawLoadFiles: summaryFiles.sort(),
};

await writeFile(
  path.join(resultDirectory, 'metadata.json'),
  `${JSON.stringify(metadata, null, 2)}\n`,
);

const report = [];
report.push(`# User Test Benchmark: ${frameworkName}`);
report.push('');
report.push(`- Date: ${new Date(metadata.createdAt).toLocaleString()}`);
report.push(`- Score: **${score}**`);
report.push(`- Pass gate: ${holdDuration} hold with p95 < 500 ms, p99 < 1,000 ms, and < 1% failed requests.`);
report.push(`- Server limit: 1 vCPU, 2 GiB RAM, no swap; image \`${imageName}\` (${mib(Number(imageSizeBytes))} MiB; ${dockerPlatform}).`);
report.push(`- Fixture source revision: \`${templateCommit}\`.`);
report.push(`- Framework: **${frameworkName}**.`);
report.push(`- Repository commit: \`${gitCommit.trim()}\` (${metadata.worktree} worktree).`);
report.push(`- Load profile: warm-up ${warmupVus} VUs / ${warmupDuration}; ramp ${rampUp}; each scored hold ${holdDuration}; start ${startVus} VUs; interactive increment ${vuIncrement} VUs; ${Number(maxVus) > 0 ? `maximum ${maxVus} VUs` : 'no maximum VU cap'}.`);
report.push(`- Highest passing manually tested level: ${Number(highestPassingVus) > 0 ? `${highestPassingVus} VUs` : 'none'}. Passing level is not an exhaustive capacity limit.`);
report.push('- Network setup: direct HTTP, no Nginx; the k6 load generator ran on the same host as Docker. Use a separate machine for publishable numbers.');
report.push('');
report.push('## Scored load steps');
report.push('');
report.push('| Phase | VUs | Avg | p50 | p90 | p95 | p99 | p99.9 | Max | Requests/s | Requests | Failed req % | Failed checks | Avg CPU | Peak CPU | Peak memory | Result |');
report.push('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |');

for (const attempt of attempts) {
  const summary = await readSummary(attempt.label);
  const resources = await readResources(attempt.label);
  const values = overallValues(summary);
  const phase = attempt.label === 'warmup' ? 'warm-up' : 'manual step';
  report.push(
    `| ${phase} | ${attempt.vus} | ${ms(values.avg)} | ${ms(values.p50)} | ${ms(values.p90)} | ${ms(values.p95)} | ${ms(values.p99)} | ${ms(values.p999)} | ${ms(values.max)} | ${perSecond(values.rate)} | ${integer(values.count)} | ${fractionPercent(values.errorRate)} | ${fractionPercent(values.failedCheckRate)} | ${numberPercent(resources.averageCpu)} | ${numberPercent(resources.peakCpu)} | ${containerMemory(resources.peakMemoryMiB)} | ${attempt.passed ? 'PASS' : attempt.label === 'warmup' ? 'not scored' : 'FAIL'} |`,
  );
}

report.push('');
report.push('Latency and error values include all requests in the k6 user flow. CPU and container memory come from one-second Docker samples; brief peaks between samples may be missed. Docker-reported memory is not process RSS.');
report.push('');
report.push('## Last run by endpoint');
report.push('');
report.push('| Request | Avg | p50 | p90 | p95 | p99 | p99.9 | Max | Requests/s | Requests | Failed req % |');
report.push('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
if (finalSummary == null) {
  report.push('| No scored run completed | — | — | — | — | — | — | — | — | — | — |');
} else {
  for (const endpoint of endpointMetrics(finalSummary)) {
    report.push(
      `| ${endpoint.name} | ${ms(endpoint.avg)} | ${ms(endpoint.p50)} | ${ms(endpoint.p90)} | ${ms(endpoint.p95)} | ${ms(endpoint.p99)} | ${ms(endpoint.p999)} | ${ms(endpoint.max)} | ${perSecond(endpoint.rate)} | ${integer(endpoint.count)} | ${fractionPercent(endpoint.errorRate)} |`,
    );
  }
}

if (finalSummary != null) {
  const finalValues = overallValues(finalSummary);
  report.push('');
  report.push(`## Last run totals (${finalAttempt.vus} VUs, ${finalAttempt.passed ? 'PASS' : 'FAIL'})`);
  report.push('');
  report.push(`- User iterations: ${integer(finalValues.iterations)}.`);
  report.push(`- Peak virtual users: ${integer(finalValues.peakVus)}.`);
  report.push(`- Data received: ${bytes(finalValues.dataReceived)}; sent: ${bytes(finalValues.dataSent)}.`);
  report.push(`- Check success rate: ${fractionPercent(finalValues.checkRate)}.`);
}

report.push('');
report.push('## Build and runtime');
report.push('');
report.push(`- Official correctness suite: passed; ${verificationSeconds} seconds.`);
report.push(`- Host AOT build: ${hostBuildSeconds} seconds.`);
report.push(`- Docker AOT build: ${dockerBuildSeconds} seconds.`);
report.push(`- Host AOT executable: ${mib(Number(hostBinarySizeBytes))} MiB.`);
report.push(`- Docker image: ${mib(Number(imageSizeBytes))} MiB.`);
report.push(`- Runtime: ${metadata.machine.dartVersion.trim()}, ${metadata.machine.platform}, ${metadata.machine.logicalCpus} logical CPUs, ${(metadata.machine.physicalMemoryBytes / 1024 ** 3).toFixed(1)} GiB host memory.`);
report.push(`- Container constraint: CPU quota 1.0, memory 2 GiB, memory+swap 2 GiB.`);
report.push('');
report.push('## Raw files');
report.push('');
report.push('- `load/`: k6 summary JSON and HTML dashboard for every warm-up and scored run.');
report.push('- `resources/`: raw Docker CPU and memory samples.');
report.push('- `logs/`: host build, official test, k6, and image build logs.');
report.push('- `metadata.json`: source, machine, limits, configuration, and score details.');
report.push('');

await writeFile(path.join(resultDirectory, 'README.md'), `${report.join('\n')}\n`);

async function readSummary(label) {
  const file = path.join(loadDirectory, `${label}.json`);
  return JSON.parse(await readFile(file, 'utf8'));
}

async function readResources(label) {
  const file = path.join(resourceDirectory, `${label}.jsonl`);
  const lines = (await readFile(file, 'utf8').catch(() => ''))
    .split('\n')
    .filter(Boolean);
  const samples = lines.flatMap((line) => {
    try {
      const sample = JSON.parse(line);
      return [{
        cpu: parseFloat(sample.CPUPerc),
        memoryMiB: parseMemory(sample.MemUsage),
      }];
    } catch {
      return [];
    }
  });
  if (samples.length === 0) {
    return { averageCpu: null, peakCpu: null, peakMemoryMiB: null };
  }
  return {
    averageCpu: samples.reduce((sum, item) => sum + item.cpu, 0) / samples.length,
    peakCpu: Math.max(...samples.map((item) => item.cpu)),
    peakMemoryMiB: Math.max(...samples.map((item) => item.memoryMiB)),
  };
}

function overallValues(summary) {
  const metrics = summary.metrics ?? {};
  const latency = metrics.http_req_duration?.values ?? {};
  const requests = metrics.http_reqs?.values ?? {};
  return {
    avg: latency.avg,
    p50: latency.med,
    p90: latency['p(90)'],
    p95: latency['p(95)'],
    p99: latency['p(99)'],
    p999: latency['p(99.9)'],
    max: latency.max,
    count: requests.count,
    rate: requests.rate,
    errorRate: metrics.http_req_failed?.values?.rate,
    failedCheckRate: Number.isFinite(metrics.checks?.values?.rate)
      ? 1 - metrics.checks.values.rate
      : null,
    checkRate: metrics.checks?.values?.rate,
    iterations: metrics.iterations?.values?.count,
    peakVus: metrics.vus?.values?.max ?? metrics.vus_max?.values?.max,
    dataReceived: metrics.data_received?.values?.count,
    dataSent: metrics.data_sent?.values?.count,
  };
}

function endpointMetrics(summary) {
  const allMetrics = Object.entries(summary.metrics ?? {});
  const latencyEntries = allMetrics.filter(([name]) =>
    name.startsWith('http_req_duration{') && name.includes('name:'),
  );
  return latencyEntries.map(([metricName, metric]) => {
    const name = metricName.match(/name:([^,}]+)/)?.[1] ?? metricName;
    const tagged = (prefix) => allMetrics.find(([key]) =>
      key.startsWith(`${prefix}{`) && key.includes(`name:${name}`),
    )?.[1]?.values ?? {};
    const values = metric.values ?? {};
    const requests = tagged('http_reqs');
    const failures = tagged('http_req_failed');
    return {
      name,
      avg: values.avg,
      p50: values.med,
      p90: values['p(90)'],
      p95: values['p(95)'],
      p99: values['p(99)'],
      p999: values['p(99.9)'],
      max: values.max,
      count: requests.count,
      rate: requests.rate,
      errorRate: failures.rate,
    };
  }).sort((left, right) => left.name.localeCompare(right.name));
}

function parseMemory(value) {
  const match = value.match(/^([0-9.]+)\s*(B|kB|MB|GB|KiB|MiB|GiB)/);
  if (!match) return NaN;
  const amount = Number(match[1]);
  const multiplier = {
    B: 1,
    kB: 1000,
    MB: 1000 ** 2,
    GB: 1000 ** 3,
    KiB: 1024,
    MiB: 1024 ** 2,
    GiB: 1024 ** 3,
  }[match[2]];
  return amount * multiplier / 1024 ** 2;
}

function run(executable, args, cwd) {
  try {
    return execFileSync(executable, args, { cwd, encoding: 'utf8' }).trim();
  } catch (error) {
    return `${error.stdout ?? ''}${error.stderr ?? ''}`.trim() || 'unavailable';
  }
}

async function sha256(value) {
  const { createHash } = await import('node:crypto');
  return createHash('sha256').update(value).digest('hex');
}

function ms(value) {
  return Number.isFinite(value) ? `${value.toFixed(2)} ms` : '—';
}

function fractionPercent(value) {
  return Number.isFinite(value) ? `${(value * 100).toFixed(2)}%` : '—';
}

function numberPercent(value) {
  return Number.isFinite(value) ? `${value.toFixed(2)}%` : '—';
}

function perSecond(value) {
  return Number.isFinite(value) ? value.toFixed(2) : '—';
}

function integer(value) {
  return Number.isFinite(value) ? Math.round(value).toLocaleString() : '—';
}

function bytes(value) {
  if (!Number.isFinite(value)) return '—';
  return value >= 1024 ** 2
    ? `${(value / 1024 ** 2).toFixed(2)} MiB`
    : `${(value / 1024).toFixed(2)} KiB`;
}

function containerMemory(value) {
  return Number.isFinite(value) ? `${value.toFixed(1)} MiB` : '—';
}

function mib(value) {
  return Number.isFinite(value) ? (value / 1024 ** 2).toFixed(1) : '—';
}
