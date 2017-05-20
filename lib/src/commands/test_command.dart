// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:webdev/src/command.dart';
import 'package:webdev/src/sdk.dart';

// TODO: pass some args

// TODO: name, platform, concurrency, reporter

class TestCommand extends WebCommand {
  TestCommand() : super('test', 'Run unit tests.');

  run() async {
    Process process = await Process.start(sdk.pub, ['run', 'test']);
    process.stdout.listen(stdout.add);
    process.stderr.listen(stderr.add);
    return process.exitCode;
  }
}
