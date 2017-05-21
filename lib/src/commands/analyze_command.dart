// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

// TODO: use package:analysis_server_lib

// TODO: fail by severity

class AnalyzeCommand extends WebCommand {
  AnalyzeCommand() : super('analyze', 'Analyze the project\'s source code.');

  run() async {
    Process process = await startProcess(sdk.dartanalyzer, ['.']);
    routeToStdout(process);
    int exitCode = await process.exitCode;
    return exitCode == 0 ? 0 : 1;
  }
}
