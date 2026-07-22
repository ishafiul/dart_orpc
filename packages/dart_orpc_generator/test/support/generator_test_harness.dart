import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_orpc_generator/dart_orpc_generator.dart';

Future<GeneratorBuilderRun> runModuleBuilder(
  String source, {
  Map<String, String> additionalSources = const {},
}) async {
  final readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();

  final sources = <String, String>{
    'a|lib/example.dart': source,
    for (final entry in additionalSources.entries)
      'a|${entry.key}': entry.value,
  };

  final partResult = await testBuilder(
    dartOrpcBuilder(BuilderOptions(const {})),
    sources,
    rootPackage: 'a',
    readerWriter: readerWriter,
    generateFor: {'a|lib/example.dart'},
  );

  final generatedPartAsset = AssetId(
    'a',
    '.dart_tool/build/generated/a/lib/example.dart_orpc.g.part',
  );
  var generatedFieldRefs = '';
  if (readerWriter.testing.exists(generatedPartAsset)) {
    generatedFieldRefs = readerWriter.testing.readString(generatedPartAsset);
    readerWriter.testing.writeString(AssetId('a', 'lib/example.g.dart'), '''
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example.dart';

${readerWriter.testing.readString(generatedPartAsset)}
''');
  }

  final moduleResult = await testBuilder(
    dartOrpcModuleBuilder(BuilderOptions(const {})),
    sources,
    rootPackage: 'a',
    readerWriter: readerWriter,
    generateFor: {'a|lib/example.dart'},
  );

  return GeneratorBuilderRun(
    readerWriter: readerWriter,
    partResult: partResult,
    moduleResult: moduleResult,
    generatedFieldRefs: generatedFieldRefs,
  );
}

final class GeneratorBuilderRun {
  const GeneratorBuilderRun({
    required this.readerWriter,
    required this.partResult,
    required this.moduleResult,
    required this.generatedFieldRefs,
  });

  final TestReaderWriter readerWriter;
  final TestBuilderResult partResult;
  final TestBuilderResult moduleResult;
  final String generatedFieldRefs;

  bool get succeeded => partResult.succeeded && moduleResult.succeeded;

  List<AssetId> get outputs => [...partResult.outputs, ...moduleResult.outputs];

  List<String> get errors => [...partResult.errors, ...moduleResult.errors];

  String get generatedOutput {
    final outputAsset = readerWriter.testing.assets.firstWhere(
      (asset) =>
          asset.package == 'a' && asset.path.endsWith('example.orpc.dart'),
    );
    return readerWriter.testing.readString(outputAsset);
  }

  Iterable<AssetId> get moduleOutputs =>
      moduleResult.outputs.where((asset) => asset.path.endsWith('.orpc.dart'));
}

int countMatches(String value, String pattern) {
  return RegExp(RegExp.escape(pattern)).allMatches(value).length;
}
