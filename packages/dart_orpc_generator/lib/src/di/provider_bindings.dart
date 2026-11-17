import 'declarations.dart';
import 'errors.dart';
import 'resolution.dart';

/// A provider as one module sees it, with where it came from.
final class ProviderBinding {
  const ProviderBinding({required this.instance, required this.sourceLabel});

  /// A provider built by the module that declares it.
  factory ProviderBinding.local(
    ModuleDeclaration module,
    ProviderDeclaration provider,
  ) => ProviderBinding(
    instance: InstanceRef(
      kind: InstanceKind.provider,
      moduleKey: module.key,
      token: provider.token,
    ),
    sourceLabel:
        'provider "${provider.token.typeName}" from module "${module.name}"',
  );

  final InstanceRef instance;

  /// Where the provider comes from, for messages.
  final String sourceLabel;

  DependencyToken get token => instance.token;
}

/// Providers a module can see, by token key.
///
/// Adding the same instance again is a no-op; adding a different instance
/// for a key already present throws [AmbiguousProviderError].
final class ProviderBindings {
  ProviderBindings(this.module, [Map<String, ProviderBinding>? initial])
    : _bindings = {...?initial};

  final ModuleDeclaration module;
  final Map<String, ProviderBinding> _bindings;

  Map<String, ProviderBinding> get asMap => Map.unmodifiable(_bindings);

  Iterable<ProviderBinding> get values => _bindings.values;

  ProviderBinding? operator [](String key) => _bindings[key];

  void add(ProviderBinding binding) {
    final key = binding.token.key;
    final existing = _bindings[key];
    if (existing == null) {
      _bindings[key] = binding;
      return;
    }
    if (existing.instance == binding.instance) return;
    throw AmbiguousProviderError(
      module: module,
      typeName: binding.token.typeName,
      firstSource: existing.sourceLabel,
      secondSource: binding.sourceLabel,
    );
  }
}
