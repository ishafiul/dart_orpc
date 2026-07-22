import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/check_generator_coverage.dart '
      '<lcov-file> [minimum-percent]',
    );
    exitCode = 64;
    return;
  }

  final report = File(arguments.first);
  if (!report.existsSync()) {
    stderr.writeln('Coverage report not found: ${report.path}');
    exitCode = 66;
    return;
  }

  final minimumPercent = arguments.length == 2
      ? double.parse(arguments[1])
      : 90.0;
  var linesFound = 0;
  var linesHit = 0;

  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }

  if (linesFound == 0) {
    stderr.writeln('Coverage report contains no executable lines.');
    exitCode = 65;
    return;
  }

  final coveragePercent = linesHit * 100 / linesFound;
  stdout.writeln(
    'Generator line coverage: ${coveragePercent.toStringAsFixed(1)}% '
    '($linesHit/$linesFound; minimum ${minimumPercent.toStringAsFixed(1)}%)',
  );

  if (coveragePercent < minimumPercent) {
    stderr.writeln('Generator coverage is below the required threshold.');
    exitCode = 1;
  }
}
