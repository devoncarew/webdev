// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

// TODO: handle name, platform, reporter

class TestCommand extends WebCommand {
  TestCommand() : super('test', 'Run unit tests.') {
    argParser.addOption('concurrency',
        abbr: 'j',
        defaultsTo: '2',
        help: 'The number of concurrent test suites run.');
  }

  @override
  run() async {
    List<String> args = ['run', 'test'];
    if (argResults.wasParsed('concurrency')) {
      args.add('--concurrency');
      args.add(argResults['concurrency']);
    }
    args.addAll(argResults.rest);

    Process process = await startProcess(sdk.pub, args);
    routeToStdout(process);
    return process.exitCode;
  }
}
