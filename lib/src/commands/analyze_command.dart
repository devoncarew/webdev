// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

// TODO: use package:analysis_server_lib

class AnalyzeCommand extends WebCommand {
  AnalyzeCommand() : super('analyze', 'Analyze the project\'s source code.') {
    argParser.addFlag('fatal-infos',
        negatable: false, help: 'Treat infos as fatal.');
    argParser.addFlag('fatal-warnings',
        negatable: false, help: 'Treat warnings as fatal');
  }

  @override
  run() async {
    List<String> args = [];
    if (argResults['fatal-infos']) args.add('--fatal-infos');
    if (argResults['fatal-warnings']) args.add('--fatal-warnings');
    args.add('.');

    Process process = await startProcess(sdk.dartanalyzer, args);
    routeToStdout(process);
    int exitCode = await process.exitCode;
    return exitCode == 0 ? 0 : 1;
  }
}
