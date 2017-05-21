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

void routeToStdout(Process process, {bool logToTrace: false}) {
  if (isVerbose) {
    process.stdout
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen(logToTrace ? log.trace : log.stdout);
    process.stderr
        .transform(UTF8.decoder)
        .transform(const LineSplitter())
        .listen(log.stderr);
  } else {
    if (!logToTrace) process.stdout.listen(stdout.add);
    process.stderr.listen(stderr.add);
  }
}
