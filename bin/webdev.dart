// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:webdev/webdev.dart';

Future main(List<String> arguments) async {
  final WebCommandRunner runner = new WebCommandRunner();
  try {
    dynamic result = await runner.run(arguments);
    exit(result is int ? result : 0);
  } catch (e) {
    if (e is UsageException) {
      stderr.writeln('$e');
      exit(64);
    } else {
      stderr.writeln('$e');
      exit(1);
    }
  }
}
