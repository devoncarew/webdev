// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:webdev/webdev.dart';

main(List<String> arguments) async {
  WebCommandRunner runner = new WebCommandRunner();
  try {
    dynamic result = await runner.run(arguments);
    exit(result is int ? result : 0);
  } catch (e) {
    if (e is UsageException) {
      stderr.writeln('$e');
      exit(64);
    } else {
      // TODO: stacktrace
      stderr.writeln('$e');
      exit(1);
    }
  }
}
