// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

// TODO: --port               The base port to listen on.
// (defaults to "8080")

// TODO: --hostname           The hostname to listen on.
//(defaults to "localhost")

// TODO: we lose ansi coloring in `webdev serve`

class ServeCommand extends WebCommand {
  ServeCommand() : super('serve', '''Run a local web development server.

By default, this serves "web/" and "test/", but an explicit list of
directories to serve can be provided as well.''') {
    argParser.addOption('mode',
        defaultsTo: 'debug',
        allowed: ['release', 'debug'],
        help: 'The build mode (release or debug).');
  }

  @override
  String get invocation => '${super.invocation} [directories...]';

  @override
  run() async {
    List<String> args = ['serve'];
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
