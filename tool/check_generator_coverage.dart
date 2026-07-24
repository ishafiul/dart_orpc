import 'dart:io';

import 'check_coverage.dart' as coverage;

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/check_generator_coverage.dart '
      '<lcov-file> [minimum-percent]',
    );
    exitCode = 64;
    return;
  }
  coverage.main([...arguments, 'Generator']);
}
