// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:webdev/src/command.dart';
import 'package:webdev/src/sdk.dart';

// TODO: use package:analysis_server_lib

// TODO: fails by severity

class AnalyzeCommand extends WebCommand {
  AnalyzeCommand() : super('analyze', 'Analyze the project\'s source code.');

  run() async {
    Process process = await Process.start(sdk.dartanalyzer, ['.']);
    process.stdout.listen(stdout.add);
    process.stderr.listen(stderr.add);
    return process.exitCode;
  }
}
