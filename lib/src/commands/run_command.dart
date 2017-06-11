// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    show ConsoleAPIEvent, LogEntry, RemoteObject, ExceptionDetails;
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    as wip show StackTrace;

import '../browsers.dart';
import '../core.dart';
import '../sdk.dart';

// TODO: --port               The base port to listen on.
// (defaults to "8080")

// TODO: --hostname           The hostname to listen on.
//(defaults to "localhost")

// TODO: support --chrome

// TODO: support --browser

class RunCommand extends WebCommand {
  RunCommand()
      : super('run',
            "Start 'pub serve' and open the given app in Chrome (defaults to 'web/index.html').") {
    // TODO: --live should also analyze the code - (and use the analysis server)
    argParser.addFlag('live',
        negatable: false,
        help: 'Watch the filesystem for changes and reload the app.');
    argParser.addOption('mode',
        defaultsTo: 'debug',
        allowed: ['release', 'debug'],
        help: 'The build mode (release or debug).');
  }

  String get summary {
    return '${super.summary}\n'
        'Use with --live to watch the filesystem and auto-refresh Chrome.';
  }

  String get invocation => '${super.invocation} <file>';

  run() async {
    if (argResults.rest.length > 1) {
      usageException(
          'Too many entry-point files given: ${argResults.rest.join(' ')}');
      return 1;
    }

    String entryFile =
        argResults.rest.isEmpty ? 'web/index.html' : argResults.rest.first;

    if (!FileSystemEntity.isFileSync(entryFile)) {
      usageException('Entry-point file not found: ${entryFile}.');
      return 1;
    }

    // TODO: also support dart files

    if (path.extension(entryFile) != '.html') {
      usageException('Please select an html file to run (${entryFile}).');
      return 1;
    }

    // check for chrome
    Chrome chrome = Chrome.locate();
    if (chrome == null) {
      // TODO: print a message about --chrome
      log.stderr('Unable to locate chrome.');
      return 1;
    }

    // start pub serve
    String serveDir = path.split(path.relative(entryFile)).first;
    List<String> args = ['serve'];
    if (argResults.wasParsed('mode')) {
      args.add('--mode');
      args.add(argResults['mode']);
    }
    args.add(serveDir);

    // "Serving webdev_sample web on http://localhost:8080"
    final RegExp hostRegex = new RegExp(r'Serving .* on ([\w:\/]+)');
    Completer<String> pubServeStarted = new Completer();

    Process pubServeProcess = await startProcess(sdk.pub, args);
    routeToStdout(pubServeProcess, listener: (String line) {
      if (!pubServeStarted.isCompleted && hostRegex.hasMatch(line)) {
        pubServeStarted.complete(hostRegex.firstMatch(line).group(1));
      }
    });

    ChromeProcess chromeProcess;

    try {
      // wait for server active
      String baseUrl = await pubServeStarted.future;

      // start chrome
      Uri uri = Uri
          .parse(baseUrl)
          .resolve(path.split(entryFile).sublist(1).join('/'));
      chromeProcess = await chrome.start(url: uri.toString());
      log.stdout('Starting Chrome tab for $uri...');

      // connect to tab
      ChromeTab tab = await chromeProcess.connectToTab(uri.toString());
      if (tab == null) {
        log.stderr('Unable to connect to Chrome.');
        pubServeProcess.kill(); // TODO: clean this up in other situations too
        return 1;
      }

      // Fail if we can't connect to the browser.
      await new Future.delayed(new Duration(seconds: 2)); // TODO:
      await tab.connect(log);

      Ansi ansi = log.ansi;
      String bullet = ansi.bullet;

      tab.onLogEntryAdded.listen((LogEntry event) {
        if (event.level == 'error') {
          String str = '${event.level} $bullet ${ansi.error(event.text)}';
          if (event.url != null) {
            str = '$str (${event.url})';
          }
          log.stderr(str);
        } else {
          String str = '${event.level} $bullet ${ansi.emphasized(event.text)}';
          if (event.url != null) {
            str = '$str (${event.url})';
          }
          log.stdout(str);
        }
      });

      tab.onConsoleAPICalled.listen((ConsoleAPIEvent event) {
        if (event.type == 'log' ||
            event.type == 'info' ||
            event.type == 'debug') {
          RemoteObject obj = event.args.first;
          log.stdout('${event.type} $bullet ${ansi.emphasized(obj.value)}');
        } else if (event.type == 'warning') {
          RemoteObject obj = event.args.first;
          log.stdout(
              '${event.type} $bullet ${ansi.yellow}${obj.value}${ansi.none}');
        } else if (event.type == 'error') {
          RemoteObject obj = event.args.first;
          log.stderr('${event.type} $bullet ${ansi.error(obj.value)}');
        }
      });

      tab.onExceptionThrown.listen((event) {
        ExceptionDetails details = event.exceptionDetails;
        String text = details.exception?.toString() ?? details.text;
        log.stderr('exception $bullet ${ansi.error(text)}');

        wip.StackTrace trace = details.stackTrace;
        if (trace != null) {
          if (trace.description != null) {
            log.stderr('exception $bullet ${ansi.error(trace.description)}');
          }
          log.stderr(trace.printFrames().map((line) {
            return 'exception $bullet   ${ansi.error(line)}';
          }).join('\n'));
        }
      });

      // If --live, watch the file system and send a browser refresh.
      if (argResults['live']) {
        DebounceTimer timer = new DebounceTimer(() {
          if (tab != null) {
            String symbol = ansi.useAnsi ? '⟳  ' : '';
            log.stdout(ansi.emphasized('\n${symbol}Reloading page...'));
            tab.reload().catchError((e) {
              log.stderr('Error reloading page: $e');
            });
          }
        });

        Set<String> watchDirs = new Set.from(['lib', 'web']);
        watchDirs.add(serveDir);
        for (String dir in watchDirs) {
          if (!FileSystemEntity.isDirectorySync(dir)) continue;

          Watcher watcher = new Watcher(dir);
          watcher.events.listen((WatchEvent event) {
            // TODO: filter to json, dart, js, css, html, htm
            timer.fire();
          });
        }
      }

      // TODO: listen for a sigkill and kill chrome

      // If the browser process dies, kill pub serve.
      chromeProcess.onExit.then((_) {
        pubServeProcess?.kill();
      });

      tab.onDisconnect.listen((_) {
        // TODO: Poll to re-connect while the browser process is alive.

        // Delay slightly to see if the chrome process will exit completely.
        new Timer(new Duration(milliseconds: 500), () {
          log.stderr('Connection to Chrome lost.');
        });
      });

      return await pubServeProcess.exitCode;
    } finally {
      pubServeProcess?.kill();
      chromeProcess?.kill();
    }
  }
}

class DebounceTimer {
  final Function callback;
  final Duration debounceTime;

  Timer _timer;

  DebounceTimer(
    this.callback, {
    this.debounceTime: const Duration(milliseconds: 100),
  });

  void fire() {
    _timer?.cancel();
    _timer = new Timer(debounceTime, callback);
  }
}
