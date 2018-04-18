// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import '../core.dart';
import '../sdk.dart';

// TODO: handle the platform option

// TODO: we don't properly handle ansi rewriting with -rcompact

class TestCommand extends WebCommand {
  TestCommand() : super('test', 'Run unit tests.') {
    argParser.addMultiOption('name',
        abbr: 'n',
        splitCommas: true,
        help: 'A substring of the name of the test to run; '
            'regular expression syntax is supported.');
    argParser.addMultiOption('plain-name',
        abbr: 'N',
        splitCommas: true,
        help: 'A plain-text substring of the name of the test to run.');
    argParser.addOption('reporter',
        abbr: 'r',
        allowed: ['compact', 'expanded', 'json'],
        defaultsTo: 'expanded',
        help: 'The reporter used to print test results.');
  }

  @override
  String get invocation => '${super.invocation} [file or directories...]';

  @override
  run() async {
    List<String> args = ['run', 'test'];
    if (argResults.wasParsed('name')) {
      final List names = argResults['name'];
      for (String name in names) {
        args.add('--name=$name');
      }
    }
    if (argResults.wasParsed('plain-name')) {
      final List names = argResults['plain-name'];
      for (String name in names) {
        args.add('--plain-name=$name');
      }
    }
    args.add(ansi.useAnsi ? '--color' : '--no-color');
    args.add('--reporter=${argResults['reporter']}');
    args.addAll(argResults.rest);

    final Process process = await startProcess(sdk.pub, args);
    routeToStdoutStreaming(process);
    return process.exitCode;
  }
}
