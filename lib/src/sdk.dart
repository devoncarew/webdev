// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:path/path.dart' as path;

final Sdk sdk = new Sdk();

class Sdk {
  final String dir;

  Sdk() : dir = getSdkPath();

  String get dartanalyzer => path.join(dir, 'bin', _binName('dartanalyzer'));

  String get dartfmt => path.join(dir, 'bin', _binName('dartfmt'));

  String get pub => path.join(dir, 'bin', _binName('pub'));

  String get version =>
      new File(path.join(dir, 'version')).readAsStringSync().trim();

  static String _binName(String base) =>
      Platform.isWindows ? '$base.bat' : base;
}
