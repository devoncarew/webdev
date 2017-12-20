// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

// TODO: Additional commands to expose:
//downgrade   Downgrade the current package's dependencies to oldest versions.
//deps        Print package dependencies.
//publish     Publish the current package to pub.dartlang.org.
//uploader    Manage uploaders for a package on pub.dartlang.org.

class PubCommand extends WebCommand {
  PubCommand() : super('pub', 'Perform package management operations.') {
    addSubcommand(new _PubGetCommand());
    addSubcommand(new _PubUpgradeCommand());
  }
}

class _PubGetCommand extends WebCommand {
  _PubGetCommand() : super('get', "Get the current package's dependencies.") {
    argParser.addFlag('offline',
        negatable: false,
        help: 'Use cached packages instead of accessing the network.');
    argParser.addFlag('dry-run',
        abbr: 'n',
        negatable: false,
        help: "Report what dependencies would change but don't change any.");
  }

  @override
  run() async {
    List<String> args = ['get'];
    if (log.isVerbose) args.add('--verbose');
    if (argResults['offline']) args.add('--offline');
    if (argResults['dry-run']) args.add('--dry-run');
    args.add('--no-precompile');
    final Process process = await startProcess(sdk.pub, args);
    routeToStdout(process);
    return process.exitCode;
  }
}

class _PubUpgradeCommand extends WebCommand {
  _PubUpgradeCommand()
      : super('upgrade',
            "Upgrade the current package's dependencies to latest versions.") {
    argParser.addFlag('offline',
        negatable: false,
        help: 'Use cached packages instead of accessing the network.');
    argParser.addFlag('dry-run',
        abbr: 'n',
        negatable: false,
        help: "Report what dependencies would change but don't change any.");
  }

  @override
  run() async {
    List<String> args = ['upgrade'];
    if (log.isVerbose) args.add('--verbose');
    if (argResults['offline']) args.add('--offline');
    if (argResults['dry-run']) args.add('--dry-run');
    args.add('--no-precompile');
    final Process process = await startProcess(sdk.pub, args);
    routeToStdout(process);
    return process.exitCode;
  }
}
