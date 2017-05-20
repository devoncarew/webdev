// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:webdev/webdev.dart';

abstract class WebCommand extends Command {
  final String name;
  final String description;

  WebCommand(this.name, this.description);

  WebCommandRunner get webRunner => runner;
}
