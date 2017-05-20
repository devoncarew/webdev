// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:webdev/src/command.dart';
import 'package:webdev/src/sdk.dart';

class FormatCommand extends WebCommand {
  FormatCommand() : super('format', 'Format source files.') {
    argParser.addFlag('dry-run',
        abbr: 'n',
        negatable: false,
        help: 'Show which files would be modified but make no changes. '
            'Return exit code 1 if there are any formatting changes.');
  }

  run() async {
    List args;

    bool filter = false;
    int lineCount = 0;
    if (argResults['dry-run']) {
      args = ['--dry-run'];
    } else {
      args = ['--overwrite'];
      filter = true;
    }
    args.addAll(argResults.rest.isEmpty ? ['.'] : argResults.rest);

    Process process = await Process.start(sdk.dartfmt, args);
    process.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      lineCount++;

      if (!filter || line.startsWith('Formatted ')) {
        stdout.writeln(line);
      }
    });
    process.stderr.listen(stderr.add);
    int code = await process.exitCode;
    if (argResults['dry-run'] && lineCount > 0) return 1;
    return code;
  }
}
