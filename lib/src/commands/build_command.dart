// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:webdev/src/command.dart';
import 'package:webdev/src/sdk.dart';

// TODO: release / debug

class BuildCommand extends WebCommand {
  BuildCommand() : super('build', 'Build the project.');

  run() async {
    Process process = await Process.start(sdk.pub, ['build']);
    process.stdout.pipe(stdout);
    process.stderr.pipe(stderr);
    return process.exitCode;
  }
}
