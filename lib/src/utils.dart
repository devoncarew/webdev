// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

/// The directory used to store per-user settings for Dart tooling.
Directory getDartPrefsDirectory() {
  return new Directory(path.join(getUserHomeDir(), '.dart'));
}

String getUserHomeDir() {
  String envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
  String value = Platform.environment[envKey];
  return value == null ? '.' : value;
}

typedef void VoidFunction();
