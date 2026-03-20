import 'dart:io';

import 'package:dart_orpc_cli/dart_orpc_cli.dart';
import 'package:test/test.dart';

void main() {
  group('WatchPlan.discover', () {
    test(
      'finds the workspace root and packages directory for a nested app project',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'dart_orpc_cli_watch_plan_',
        );
        addTearDown(() async {
          if (await sandbox.exists()) {
            await sandbox.delete(recursive: true);
          }
        });

        final workspacePubspec = File.fromUri(
          sandbox.uri.resolve('pubspec.yaml'),
        );
        await workspacePubspec.writeAsString(
          'name: root\nworkspace:\n  - apps/**\n',
        );

        final projectDirectory = Directory.fromUri(
          sandbox.uri.resolve('apps/basic_app/'),
        );
        await projectDirectory.create(recursive: true);
        await File.fromUri(
          projectDirectory.uri.resolve('pubspec.yaml'),
        ).writeAsString('''
name: basic_app
dependencies:
  dart_orpc: ^0.1.0
''');

        await Directory.fromUri(sandbox.uri.resolve('packages/')).create();

        final project = await DartOrpcProject.discover(
          currentDirectory: sandbox,
          projectPath: 'apps/basic_app',
          entrypoint: 'bin/server.dart',
        );
        final plan = await WatchPlan.discover(project: project);

        expect(
          normalizeDirectoryPath(plan.projectDirectory.path),
          endsWith('/apps/basic_app'),
        );
        expect(
          normalizeDirectoryPath(plan.workspaceRoot!.path),
          normalizeDirectoryPath(sandbox.path),
        );
        expect(
          normalizeDirectoryPath(plan.packagesDirectory!.path),
          normalizeDirectoryPath(
            Directory.fromUri(sandbox.uri.resolve('packages/')).path,
          ),
        );
      },
    );
  });

  group('WatchPlan.isRelevantPath', () {
    test('accepts source changes and ignores generated outputs', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'dart_orpc_cli_watch_paths_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      await File.fromUri(
        sandbox.uri.resolve('pubspec.yaml'),
      ).writeAsString('name: root\nworkspace:\n  - apps/**\n');

      final projectDirectory = Directory.fromUri(
        sandbox.uri.resolve('apps/basic_app/'),
      );
      await projectDirectory.create(recursive: true);
      await File.fromUri(
        projectDirectory.uri.resolve('pubspec.yaml'),
      ).writeAsString('''
name: basic_app
dependencies:
  dart_orpc: ^0.1.0
''');

      final packagesDirectory = Directory.fromUri(
        sandbox.uri.resolve('packages/'),
      );
      await packagesDirectory.create(recursive: true);

      final project = await DartOrpcProject.discover(
        currentDirectory: sandbox,
        projectPath: 'apps/basic_app',
        entrypoint: 'bin/server.dart',
      );
      final plan = await WatchPlan.discover(project: project);

      expect(
        plan.isRelevantPath(
          normalizePath(
            projectDirectory.uri.resolve('lib/user_service.dart').toFilePath(),
          ),
        ),
        isTrue,
      );
      expect(
        plan.isRelevantPath(
          normalizePath(
            projectDirectory.uri.resolve('lib/app.g.dart').toFilePath(),
          ),
        ),
        isFalse,
      );
      expect(
        plan.isRelevantPath(
          normalizePath(
            packagesDirectory.uri
                .resolve('dart_orpc_core/lib/src/rpc_context.dart')
                .toFilePath(),
          ),
        ),
        isTrue,
      );
      expect(
        plan.isRelevantPath(
          normalizePath(
            packagesDirectory.uri
                .resolve('dart_orpc_core/.dart_tool/build/asset_graph.json')
                .toFilePath(),
          ),
        ),
        isFalse,
      );
    });
  });
}
