// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:webdev/src/commands/run_command.dart';

import 'src/commands/analyze_command.dart';
import 'src/commands/build_command.dart';
import 'src/commands/create_command.dart';
import 'src/commands/format_command.dart';
import 'src/commands/serve_command.dart';
import 'src/commands/test_command.dart';
import 'src/core.dart';
import 'src/sdk.dart';

// TODO: doctor, fix, upgrade, channel, pub get, pub upgrade?

class WebCommandRunner extends CommandRunner {
  WebCommandRunner()
      : super('webdev', 'A tool for web development with Dart.') {
    argParser.addFlag('version',
        negatable: false, help: 'Reports the version of this tool.');
    argParser.addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show verbose output.');

    addCommand(new CreateCommand());
    addCommand(new AnalyzeCommand());
    addCommand(new RunCommand());
    addCommand(new BuildCommand());
    addCommand(new FormatCommand());
    addCommand(new ServeCommand());
    addCommand(new TestCommand());
  }

  Future runCommand(ArgResults results) async {
    if (results['version']) {
      print(
          '${ansi.emphasized(executableName)} ${ansi.bullet} https://webdev.dartlang.org');
      print(description);
      print('Built on SDK ${ansi.emphasized(sdk.version)}.');
      return null;
    }

    isVerbose = results['verbose'];

    log = isVerbose
        ? new Logger.verbose(ansi: ansi)
        : new Logger.standard(ansi: ansi);

    try {
      return await super.runCommand(results);
    } finally {
      log?.flush();
    }
  }
}
