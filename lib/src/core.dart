// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:webdev/webdev.dart';

final Ansi ansi = new Ansi(Ansi.terminalSupportsAnsi);
Logger log;
bool isVerbose = false;

abstract class WebCommand extends Command {
  final String name;
  final String description;

  WebCommand(this.name, this.description);

  WebCommandRunner get webRunner => runner;
}

Future<Process> startProcess(String executable, List<String> arguments,
    {String cwd}) {
  log.trace('$executable ${arguments.join(' ')}');
  return Process.start(executable, arguments, workingDirectory: cwd);
}

void routeToStdout(Process process,
    {bool logToTrace: false, void listener(String str)}) {
  if (isVerbose) {
    process.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      logToTrace ? log.trace(line) : log.stdout(line);
      if (listener != null) listener(line);
    });
    process.stderr
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      log.stderr(line);
      if (listener != null) listener(line);
    });
  } else {
    if (!logToTrace) {
      process.stdout
          .transform(UTF8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        log.stdout(line);
        if (listener != null) listener(line);
      });
    }

    process.stderr
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      log.stderr(line);
      if (listener != null) listener(line);
    });
  }
}
