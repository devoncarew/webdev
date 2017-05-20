// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:path/path.dart' as path;
import 'package:stagehand/stagehand.dart' as stagehand;
import 'package:webdev/src/command.dart';
import 'package:webdev/src/sdk.dart';

// TODO --force

class CreateCommand extends WebCommand {
  Iterable<stagehand.Generator> get generators =>
      stagehand.generators.where((g) => g.categories.contains('web'));

  CreateCommand() : super('create', 'Create a new project.') {
    argParser.addOption(
      'template',
      allowed: generators.map((g) => g.id).toList(),
      help: 'The project template to use.',
      defaultsTo: 'web-simple',
    );
  }

  run() async {
    if (argResults.rest.isEmpty) {
      printUsage();
      return 0;
    }

    String templateId = argResults['template'];
    // TODO: validate

    String dir = argResults.rest.single;
    // TODO: validate

    // TODO:
    print('Creating $templateId...');

    stagehand.Generator generator = stagehand.getGenerator(templateId);
    await generator.generate(
        dir, new DirectoryGeneratorTarget(new io.Directory(dir)));
    print('');

    // entrypoint, TODO:

    // TODO: pub get
    io.Process process =
        await io.Process.start(sdk.pub, ['get'], workingDirectory: dir);
    process.stdout.listen(io.stdout.add);
    process.stderr.listen(io.stderr.add);
    int code = await process.exitCode;
    if (code != 0) return code;

    print('\nCreated project $dir.');

    // TODO: cd and running instructions
  }

  String get usageFooter {
    String desc =
        generators.map((g) => '  ${g.id}: ${g.description}').join('\n');
    return '\nTemplate options:\n$desc';
  }
}

class DirectoryGeneratorTarget extends stagehand.GeneratorTarget {
  final io.Directory dir;

  DirectoryGeneratorTarget(this.dir) {
    dir.createSync();
  }

  Future createFile(String filePath, List<int> contents) {
    io.File file = new io.File(path.join(dir.path, filePath));

    print('  ${file.path}');

    return file
        .create(recursive: true)
        .then((_) => file.writeAsBytes(contents));
  }
}
