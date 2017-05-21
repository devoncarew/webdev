// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:webdev/src/commands/create_command.dart';

main() {
  group('command', () {
    test('--version', () {
      TestProject p = project();
      try {
        expect(p.run('--version').exitCode, 0);
      } finally {
        p.dispose();
      }
    });

    group('analyze', defineAnalyze);
    group('build', defineBuild);
    group('create', defineCreate);
    group('format', defineFormat);
    group('serve', defineServe);
    group('test', defineTest);
  });
}

defineAnalyze() {
  TestProject p;

  tearDown(() => p?.dispose());

  test('no errors', () {
    p = project(mainSrc: 'int get foo => 1;');
    ProcessResult result = p.run('analyze');
    expect(result.exitCode, 0);
  });

  test('finds errors', () {
    p = project(mainSrc: 'int foo => 1;');
    ProcessResult result = p.run('analyze');
    expect(result.exitCode, 1);
  });

  test('fatal infos', () {
    p = project(mainSrc: "import 'dart:async';\nint get foo => 1;\n");
    ProcessResult result = p.run('analyze', ['--fatal-infos']);
    expect(result.exitCode, 1);
  });
}

defineBuild() {
  TestProject p;

  tearDown(() => p?.dispose());

  test('not applicable', () {
    p = project(mainSrc: 'int get foo => 1;\n');
    ProcessResult result = p.run('build');
    expect(result.exitCode, isNot(0));
  });

  test('performs build', () {
    p = project(mainSrc: 'int get foo => 1;\n');
    p.file('web/web.dart', 'void main() { print("hello"); }\n');
    ProcessResult result = p.run('build');
    expect(result.exitCode, 0);
    File artifact = p.findFile('build/web/web.dart.js');
    expect(artifact, isNotNull);
    expect(artifact.lengthSync(), greaterThan(0));
  });
}

defineServe() {
  TestProject p;

  tearDown(() => p?.dispose());

  test('not applicable', () {
    p = project(mainSrc: 'int get foo => 1;\n');
    ProcessResult result = p.run('serve');
    expect(result.exitCode, isNot(0));
  });

//  test('connect to server', () {
//    // TODO: run the server async, test it
//  });
}

defineCreate() {
  TestProject p;

  setUp(() => p = null);

  tearDown(() => p?.dispose());

  test('default template exists', () {
    expect(CreateCommand.legalIds, contains(CreateCommand.kDefaultTemplateId));
  });

  test('list templates', () {
    p = project();
    ProcessResult result = p.run('create', ['--list']);
    expect(result.exitCode, 0);
    expect(result.stdout, contains('Available templates'));
    expect(result.stdout, contains(CreateCommand.kDefaultTemplateId));
  });

  test('no directory given', () {
    p = project();
    ProcessResult result = p.run('create');
    expect(result.exitCode, 0);
    Directory web = new Directory(path.join(p.dir.path, 'web'));
    expect(web.existsSync(), false);
  });

  test('directory already exists', () {
    p = project();
    ProcessResult result = p.run('create', [
      '--no-pub',
      '--template',
      CreateCommand.kDefaultTemplateId,
      p.dir.path
    ]);
    expect(result.exitCode, 1);
  });

  test('bad template id', () {
    p = project();
    ProcessResult result =
        p.run('create', ['--no-pub', '--template', 'foo-bar', p.dir.path]);
    expect(result.exitCode, isNot(0));
  });

  for (String templateId in CreateCommand.legalIds) {
    test('create $templateId', () {
      p = project();
      ProcessResult result = p.run('create',
          ['--force', '--no-pub', '--template', templateId, p.dir.path]);
      expect(result.exitCode, 0);
      String entry = CreateCommand.getGenerator(templateId).entrypoint.path;
      File entryFile = new File(path.join(p.dir.path, entry));
      expect(entryFile.existsSync(), true);
    });
  }
}

defineFormat() {
  TestProject p;

  tearDown(() => p?.dispose());

  test('no changes', () {
    p = project(mainSrc: 'int get foo => 1;\n');
    ProcessResult result = p.run('format');
    expect(result.exitCode, 0);
    expect(result.stdout, isEmpty);
  });

  test('with changes', () {
    p = project(mainSrc: 'int get  foo => 1;\n');
    ProcessResult result = p.run('format');
    expect(result.exitCode, 0);
    expect(result.stdout, startsWith('Formatted '));
  });

  test('dry run', () {
    p = project(mainSrc: 'int get  foo => 1;\n');
    ProcessResult result = p.run('format', ['--dry-run']);
    expect(result.exitCode, 1);
    expect(result.stdout, startsWith('lib/main.dart'));
  });
}

defineTest() {
  TestProject p;

  tearDown(() => p?.dispose());

  final String testSrc = '''
import 'package:test/test.dart';
import 'package:${TestProject.name}/main.dart';

main() {
  test('test', () {
    expect(foo, 1);
  });
}
''';

  test('run clean', () {
    p = project(mainSrc: 'int get foo => 1;');
    p.file('test/main_test.dart', testSrc);
    ProcessResult result = p.run('test');
    expect(result.exitCode, 0);
  });

  test('finds issues', () {
    p = project(mainSrc: 'int get foo => 2;');
    p.file('test/main_test.dart', testSrc);
    ProcessResult result = p.run('test');
    expect(result.exitCode, 1);
  });

  test('supports concurrency', () {
    p = project(mainSrc: 'int get foo => 2;');
    p.file('test/main_test.dart', testSrc);
    ProcessResult result = p.run('test', ['--concurrency', '4']);
    expect(result.exitCode, 1);
  });
}

TestProject project({String mainSrc}) => new TestProject(mainSrc: mainSrc);

class TestProject {
  Directory dir;

  static String get name => 'webdev_temp';

  TestProject({String mainSrc}) {
    dir = Directory.systemTemp.createTempSync('webdev');
    if (mainSrc != null) file('lib/main.dart', mainSrc);
    file('pubspec.yaml', 'name: $name\ndev_dependencies:\n  test: any\n');
    file('pubspec.lock', new File('pubspec.lock').readAsStringSync());
    file('.packages', _createPackages());
  }

  void file(String name, String contents) {
    File f = new File(path.join(dir.path, name));
    f.parent.createSync();
    f.writeAsStringSync(contents);
  }

  void dispose() {
    dir.deleteSync(recursive: true);
  }

  ProcessResult run(String command, [List<String> args]) {
    List<String> arguments = [
      path.absolute(path.join(Directory.current.path, 'bin', 'webdev.dart')),
      command
    ];
    if (args != null) arguments.addAll(args);
    return Process.runSync(
      Platform.resolvedExecutable,
      arguments,
      workingDirectory: dir.path,
    );
  }

  String _createPackages() {
    String contents = new File('.packages').readAsStringSync();
    contents += "${name}:${dir.path}/lib";
    return contents;
  }

  File findFile(String name) {
    File file = new File(path.join(dir.path, name));
    return file.existsSync() ? file : null;
  }
}
