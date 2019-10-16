// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:analysis_server_lib/analysis_server_lib.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../core.dart';
import '../sdk.dart';
import '../utils.dart';

class AnalyzeCommand extends WebCommand {
  AnalyzeCommand() : super('analyze', 'Analyze the project\'s source code.') {
    argParser.addFlag('fatal-warnings',
        negatable: true, defaultsTo: true, help: "Treat warnings as fatal.");
    argParser.addFlag('fatal-infos',
        negatable: false, help: 'Treat infos as fatal.');
  }

  @override
  run() async {
    Progress progress = log.progress('Checking project');
    final Stopwatch stopwatch = new Stopwatch()..start();

    // init
    final List<String> serverArgs = [];
    AnalysisServer client = await createClient(serverArgs);

    Completer completer = new Completer();
    client.processCompleter.future.then((int code) {
      if (!completer.isCompleted) {
        completer.completeError('analysis exited early (exit code $code)');
      }
    });

    await client.server.onConnected.first.timeout(new Duration(seconds: 10));

    bool hadServerError = false;

    // handle errors
    client.server.onError.listen((ServerError error) {
      StackTrace trace = error.stackTrace == null
          ? null
          : new StackTrace.fromString(error.stackTrace);

      log.stderr('$error');
      log.stderr('${trace.toString().trim()}');

      hadServerError = true;
    });

    client.server.setSubscriptions(['STATUS']);
    client.server.onStatus.listen((ServerStatus status) {
      if (status.analysis == null) return;

      if (!status.analysis.isAnalyzing) {
        // notify finished
        if (!completer.isCompleted) {
          completer.complete(true);
        }
        client.dispose();
      }
    });

    Map<String, List<AnalysisError>> errorMap = new Map();
    client.analysis.onErrors.listen((AnalysisErrors e) {
      errorMap[e.file] = e.errors;
    });

    String analysisRoot = path.canonicalize(Directory.current.path);
    client.analysis.setAnalysisRoots([analysisRoot], []);

    // wait for finish
    try {
      await completer.future;
    } catch (error, st) {
      progress.cancel();

      log.stderr('$error');
      log.stderr('$st');

      return 1;
    }

    progress.finish();

    // sort, filter, print errors
    List<String> sources = errorMap.keys.toList();
    List<AnalysisError> errors = sortFilterErrors(errorMap);

    final Ansi ansi = log.ansi;

    final Map<String, String> colorMap = {
      'ERROR': ansi.red,
      'WARNING': ansi.yellow,
    };

    if (errors.isNotEmpty) {
      log.stdout('');

      for (AnalysisError error in errors) {
        final String issueColor = colorMap[error.severity] ?? '';
        final String severity = error.severity.toLowerCase();
        String location = error.location.file;
        if (location.startsWith(analysisRoot)) {
          location = location.substring(analysisRoot.length + 1);
        }
        final String locationDesc =
            '$location:${error.location.startLine}:${error.location.startColumn}';

        String message = error.message;
        if (message.endsWith('.')) {
          message = message.substring(0, message.length - 1);
        }

        log.stdout('  $issueColor$severity${ansi.none} ${ansi.bullet} '
            '${ansi.bold}$message${ansi.none} at $locationDesc ${ansi.bullet} '
            '(${error.code})');
      }

      log.stdout('');
    }

    final NumberFormat secondsFormat = new NumberFormat('0.0');
    double seconds = stopwatch.elapsedMilliseconds / 1000.0;
    log.stdout(
        '${errors.isEmpty ? "No" : formatNumber(errors.length)} ${pluralize("issue", errors.length)} '
        'found; analyzed ${formatNumber(sources.length)} source ${pluralize("file", sources.length)} '
        'in ${secondsFormat.format(seconds)}s.');

    // return the results
    if (hadServerError) return 64;
    if (errors.isEmpty) return 0;

    final int maxSeverity = errors
        .map((error) => _severityLevel(error.severity))
        .reduce((a, b) => math.max(a, b));
    if (maxSeverity == 2) return 1;

    final bool fatalWarnings = argResults['fatal-warnings'];
    final bool fatalInfos = argResults['fatal-infos'];
    if (maxSeverity == 1 && fatalWarnings) return 1;
    if (fatalInfos) return 1;

    return 0;
  }

  List<AnalysisError> sortFilterErrors(
      Map<String, List<AnalysisError>> errorMap) {
    List<AnalysisError> errors = errorMap.values.fold([], (List a, List b) {
      a.addAll(b);
      return a;
    });

    // Don't show todos.
    errors.removeWhere((e) => e.code == 'todo');

    // sort by severity, file, offset
    errors.sort((AnalysisError one, AnalysisError two) {
      int comp = _severityLevel(two.severity) - _severityLevel(one.severity);
      if (comp != 0) return comp;

      if (one.location.file != two.location.file) {
        return one.location.file.compareTo(two.location.file);
      }

      return one.location.offset - two.location.offset;
    });

    return errors;
  }

  static Future<AnalysisServer> createClient(List<String> serverArgs) {
    return AnalysisServer.create(
      onRead: (String msg) {
        const int max = 140;
        String s = msg.length > max ? '${msg.substring(0, max)}...' : msg;
        log.trace('<-- $s');
      },
      onWrite: (String msg) {
        log.trace('[--> $msg]');
      },
      sdkPath: sdk.dir,
      serverArgs: serverArgs,
      clientId: 'webdev',
      clientVersion: sdk.version,
    );
  }

  static int _severityLevel(String severity) {
    if (severity == 'ERROR') return 2;
    if (severity == 'WARNING') return 1;
    return 0;
  }
}
