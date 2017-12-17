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

// TODO: bash shell completion

final String _descFragment = 'A tool for Dart web development';

class WebCommandRunner extends CommandRunner {
  WebCommandRunner() : super('webdev', '$_descFragment.') {
    argParser.addFlag('version',
        negatable: false, help: 'Reports the version of this tool.');
    argParser.addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show verbose output.');

    addCommand(new AnalyzeCommand());
    addCommand(new BuildCommand());
    addCommand(new CreateCommand());
    addCommand(new FormatCommand());
    // TODO: addCommand(new PubCommand());
    addCommand(new RunCommand());
    addCommand(new ServeCommand());
    addCommand(new TestCommand());
  }

  @override
  Future runCommand(ArgResults results) async {
    if (results['version']) {
      print(
          '${ansi.emphasized(executableName)} ${ansi.bullet} webdev.dartlang.org');
      print('');
      print('$_descFragment; built on SDK ${ansi.emphasized(sdk.version)}.');
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
