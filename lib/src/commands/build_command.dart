// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

class BuildCommand extends WebCommand {
  BuildCommand() : super('build', 'Build the project.') {
    argParser.addOption('mode',
        defaultsTo: 'release',
        allowed: ['release', 'debug'],
        help: 'The build mode (release or debug).');
  }

  @override
  String get invocation => '${super.invocation} [directories...]';

  @override
  run() async {
    List<String> args = ['build'];
    if (argResults.wasParsed('mode')) {
      args.add('--mode');
      args.add(argResults['mode']);
    }
    args.addAll(argResults.rest);
    Process process = await startProcess(sdk.pub, args);
    routeToStdout(process);
    return process.exitCode;
  }
}
