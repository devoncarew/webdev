// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:webdev/src/commands/analyze_command.dart';
import 'package:webdev/src/commands/build_command.dart';
import 'package:webdev/src/commands/create_command.dart';
import 'package:webdev/src/commands/format_command.dart';
import 'package:webdev/src/commands/test_command.dart';
import 'package:webdev/src/sdk.dart';

// create, run, serve, format doc, fix?

// verbose, and process logging

final Ansi ansi = new Ansi(Ansi.terminalSupportsAnsi);

class WebCommandRunner extends CommandRunner {
  WebCommandRunner() : super('webdev', 'A tool for Dart web development.') {
    argParser.addFlag('version',
        negatable: false, help: 'Reports the version of this tool.');

    addCommand(new AnalyzeCommand());
    addCommand(new BuildCommand());
    addCommand(new CreateCommand());
    addCommand(new FormatCommand());
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

    return super.runCommand(results);
  }
}
