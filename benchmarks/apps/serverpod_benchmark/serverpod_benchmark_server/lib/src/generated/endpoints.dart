/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import '../benchmark/benchmark_endpoint.dart' as _i2;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'benchmark': _i2.BenchmarkEndpoint()
        ..initialize(
          server,
          'benchmark',
          null,
        ),
    };
    connectors['benchmark'] = _i1.EndpointConnector(
      name: 'benchmark',
      endpoint: endpoints['benchmark']!,
      methodConnectors: {
        'plaintext': _i1.MethodConnector(
          name: 'plaintext',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['benchmark'] as _i2.BenchmarkEndpoint)
                  .plaintext(session),
        ),
        'json': _i1.MethodConnector(
          name: 'json',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['benchmark'] as _i2.BenchmarkEndpoint).json(
                session,
              ),
        ),
        'echo': _i1.MethodConnector(
          name: 'echo',
          params: {
            'input': _i1.ParameterDescription(
              name: 'input',
              type: _i1.getType<Map<String, String>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['benchmark'] as _i2.BenchmarkEndpoint).echo(
                session,
                params['input'],
              ),
        ),
      },
    );
  }
}
