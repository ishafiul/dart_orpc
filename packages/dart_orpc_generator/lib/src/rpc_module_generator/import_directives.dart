part of '../rpc_module_generator.dart';

Future<Set<String>> _collectImportDirectivesForModule(
  _ResolvedModule rootModule, {
  required BuildStep buildStep,
  required List<_ResolvedInstantiation> importedProviderInstantiations,
}) async {
  final currentLibraryAsset = buildStep.inputId;
  final imports = <String>{};

  Future<void> addElementImport(Element? element) async {
    if (element == null) {
      return;
    }
    final library = element.library;
    if (library == null || library.isInSdk) {
      return;
    }
    final asset = await buildStep.resolver.assetIdForElement(element);
    if (asset != currentLibraryAsset) {
      imports.add("import '${_packageImportUriFor(asset)}';");
    }
  }

  for (final importedModule in rootModule.importedModules) {
    final moduleAsset = await buildStep.resolver.assetIdForElement(
      importedModule.moduleElement,
    );
    if (moduleAsset != currentLibraryAsset) {
      imports.add("import '${_packageImportUriFor(_orpcAssetFor(moduleAsset))}';");
    }
  }

  for (final instantiation in [
    ...importedProviderInstantiations,
    ...rootModule.providerInstantiations,
  ]) {
    await addElementImport(instantiation.providerElement);
  }

  for (final controller in rootModule.controllerBindings) {
    await addElementImport(controller.controllerElement);
    for (final procedure in controller.procedures) {
      await addElementImport(procedure.inputTypeElement);
      await addElementImport(procedure.outputTypeElement);
      for (final parameter in procedure.restInvocationParameters) {
        await addElementImport(parameter.typeElement);
      }
    }
  }

  return imports;
}

AssetId _orpcAssetFor(AssetId asset) => asset.changeExtension('.orpc.dart');

String _packageImportUriFor(AssetId asset) {
  if (!asset.path.startsWith('lib/')) {
    throw ArgumentError.value(
      asset,
      'asset',
      'dart_orpc module generation only supports libraries under lib/.',
    );
  }
  return 'package:${asset.package}/${asset.path.substring(4)}';
}
