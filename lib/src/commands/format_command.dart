// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import '../core.dart';
import '../sdk.dart';

class FormatCommand extends WebCommand {
  FormatCommand() : super('format', 'Format source files.') {
    argParser.addFlag('dry-run',
        abbr: 'n',
        negatable: false,
        help: 'Show which files would be modified, but make no changes and '
            'return an exit code of 1 if there would be any formatting changes.');
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

    Process process = await startProcess(sdk.dartfmt, args);
    process.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      lineCount++;

      if (!filter || line.startsWith('Formatted ')) {
        log.stdout(line);
      } else {
        log.trace(line);
      }
    });
    process.stderr
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen(log.stderr);

    int code = await process.exitCode;
    return (argResults['dry-run'] && lineCount > 0) ? 1 : code;
  }
}
