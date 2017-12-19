// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import '../core.dart';
import '../sdk.dart';
import '../utils.dart';

class FormatCommand extends WebCommand {
  FormatCommand() : super('format', 'Format source files.') {
    argParser.addFlag('dry-run',
        abbr: 'n',
        negatable: false,
        help: 'Show which files would be modified, but make no changes and '
            'return an exit code of 1 if there would be any formatting changes.');
  }

  @override
  run() async {
    final bool dryRun = argResults['dry-run'];
    int changeCount = 0;
    List<String> args = <String>[dryRun ? '--dry-run' : '--overwrite'];
    args.addAll(argResults.rest.isEmpty ? ['.'] : argResults.rest);

    final Process process = await startProcess(sdk.dartfmt, args);
    process.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      if (dryRun) {
        changeCount++;

        log.stdout(line);
      } else {
        if (line.startsWith('Formatted ')) {
          changeCount++;
          log.stdout(line);
        } else {
          log.trace(line);
        }
      }
    });
    process.stderr
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen(log.stderr);

    int code = await process.exitCode;

    if (changeCount == 0) {
      log.stdout('No changed files.');
    } else {
      log.stdout('$changeCount changed ${pluralize('file', changeCount)}.');
    }

    if (argResults['dry-run'] && changeCount > 0) return 1;
    return code;
  }
}
