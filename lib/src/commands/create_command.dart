// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:stagehand/stagehand.dart' as stagehand;

import '../core.dart';
import '../sdk.dart';

class CreateCommand extends WebCommand {
  static String kDefaultTemplateId = 'web-simple';

  static Iterable<stagehand.Generator> get generators =>
      stagehand.generators.where((g) => g.categories.contains('web'));

  static List<String> get legalIds => generators.map((g) => g.id).toList();

  static stagehand.Generator getGenerator(String templateId) =>
      stagehand.getGenerator(templateId);

  CreateCommand() : super('create', 'Create a new project.') {
    argParser.addOption(
      'template',
      allowed: legalIds,
      help: 'The project template to use.',
      defaultsTo: kDefaultTemplateId,
    );
    argParser.addFlag('pub',
        defaultsTo: true,
        help: "Whether to run 'pub get' after the project has been created.");
    argParser.addFlag(
      'list',
      negatable: false,
      help: 'List the available templates.',
    );
    argParser.addFlag(
      'force',
      negatable: false,
      help:
          'Force project generation, even if the target directory already exists.',
    );
  }

  String get invocation => '${super.invocation} <directory>';

  run() async {
    if (argResults['list']) {
      log.stdout(usageFooter.trimLeft());
      return 0;
    }

    if (argResults.rest.isEmpty) {
      printUsage();
      return 0;
    }

    String templateId = argResults['template'];

    String dir = argResults.rest.first;
    io.Directory targetDir = new io.Directory(dir);
    if (targetDir.existsSync() && !argResults['force']) {
      log.stderr(
          "Directory '$dir' already exists (use '--force' to force project generation).");
      return 1;
    }

    log.stdout(
        'Creating a ${ansi.emphasized(templateId)} project in $dir...\n');

    stagehand.Generator generator = getGenerator(templateId);
    await generator.generate(
      path.basename(dir),
      new DirectoryGeneratorTarget(generator, new io.Directory(dir)),
    );

    if (argResults['pub']) {
      log.stdout('');
      Progress progress = log.progress('Running pub get');
      io.Process process = await startProcess(
        sdk.pub,
        ['get', '--no-precompile'],
        cwd: dir,
      );
      routeToStdout(process, logToTrace: true);
      int code = await process.exitCode;
      if (code != 0) return code;
      progress.finish(showTiming: true);
    }

    log.stdout('\nCreated project ${ansi.emphasized('$dir')}.');

    // TODO: cd and running instructions
  }

  String get usageFooter {
    int width = legalIds.map((s) => s.length).fold(0, math.max);
    String desc = generators
        .map((g) => '  ${g.id.padLeft(width)}: ${g.description}')
        .join('\n');
    return '\nAvailable templates:\n$desc';
  }
}

class DirectoryGeneratorTarget extends stagehand.GeneratorTarget {
  final stagehand.Generator generator;
  final io.Directory dir;

  DirectoryGeneratorTarget(this.generator, this.dir) {
    dir.createSync();
  }

  Future createFile(String filePath, List<int> contents) {
    io.File file = new io.File(path.join(dir.path, filePath));

    String name = path.relative(file.path, from: dir.path);
    if (filePath == generator.entrypoint.path) {
      log.stdout('  ${ansi.emphasized(name)}');
    } else {
      log.stdout('  $name');
    }

    return file
        .create(recursive: true)
        .then((_) => file.writeAsBytes(contents));
  }
}
