// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';
import 'package:webkit_inspection_protocol/src/runtime.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    show ConsoleAPIEvent, LogEntry, RemoteObject, ExceptionDetails;
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    as wip show StackTrace;
import 'package:yaml/yaml.dart' as yaml;

import '../browsers.dart';
import '../core.dart';
import '../sdk.dart';
import '../source_maps.dart';
import '../utils.dart';

// TODO: --port               The base port to listen on.
// (defaults to "8080")

// TODO: --hostname           The hostname to listen on.
//(defaults to "localhost")

// TODO: support --chrome

// TODO: support --browser

// TODO: support starting w/ a url

// TODO: some exceptions from devtools are not being reported

class RunCommand extends WebCommand {
  final SourceMapManager sourceMapManager =
      new SourceMapManager(logger: (String str) {
    log.trace(str);
  });

  String selfRefName;

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

  @override
  String get summary {
    return '${super.summary}\n'
        'Use with --live to watch the filesystem and auto-refresh Chrome.';
  }

  @override
  String get invocation => '${super.invocation} <file>';

  @override
  run() async {
    if (argResults.rest.length > 1) {
      usageException(
          'Too many entry-point files given: ${argResults.rest.join(' ')}');
      return 1;
    }

    // Try and parse the selfRefName name.
    try {
      yaml.YamlDocument doc =
          yaml.loadYamlDocument(new File('pubspec.yaml').readAsStringSync());
      selfRefName = doc.contents.value['name'];
    } catch (_) {
      // ignore
    }

    String entry =
        argResults.rest.isEmpty ? 'web/index.html' : argResults.rest.first;

    Uri entryUri;
    try {
      entryUri = Uri.parse(entry);
      if (entryUri.scheme.isEmpty) {
        entryUri = null;
      }
    } catch (_) {}

    if (entryUri == null) {
      if (!FileSystemEntity.isFileSync(entry)) {
        usageException('Entry-point file not found: $entry.');
        return 1;
      }

      // TODO: Also support dart files?
      if (path.extension(entry) != '.html') {
        usageException('Please select an html file to run ($entry).');
        return 1;
      }
    }

    // check for chrome
    Chrome chrome = Chrome.locate();
    if (chrome == null) {
      // TODO: print a message about --chrome
      log.stderr('Unable to locate chrome.');
      return 1;
    }

    // start pub serve
    String serveDir;
    if (entryUri != null) {
      serveDir = 'web';
    } else {
      serveDir = path.split(path.relative(entry)).first;
    }

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
      Uri uri = entryUri != null
          ? entryUri
          : Uri.parse(baseUrl).resolve(path.split(entry).sublist(1).join('/'));
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
          logMappedTrace(trace);
        }
      });

      // If --live, watch the file system and send a browser refresh.
      if (argResults['live']) {
        DebounceTimer timer = new DebounceTimer(() {
          if (tab != null) {
            final String symbol = ansi.useAnsi ? '⟳  ' : '';

            if (tab.isConnected) {
              log.stdout(ansi.emphasized('\n${symbol}Reloading page...'));
              sourceMapManager.clearCache();
              tab.reload().catchError((e) {
                log.stderr('Error reloading page: $e');
              });
            } else {
              log.stdout(ansi.emphasized('\n$symbol'
                  'Reload not performed (no active Chrome connection)'));
            }
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

      // If the browser process dies, kill pub serve.
      chromeProcess.onExit.then((_) {
        pubServeProcess?.kill();
      });

      tab.onDisconnect.listen((_) {
        // Poll to re-connect while the browser process is alive.

        // Delay slightly to see if the chrome process will exit completely.
        new Timer(new Duration(milliseconds: 500), () {
          log.stderr(ansi.emphasized('Connection to Chrome lost.\n'));

          tab.reconnectWhile(log, () => chromeProcess.isAlive).then((_) {
            log.stderr(ansi.emphasized('\nChrome connection restored.'));
          });
        });
      });

      return await pubServeProcess.exitCode;
    } finally {
      pubServeProcess?.kill();
      chromeProcess?.kill();
    }
  }

  void logMappedTrace(wip.StackTrace trace) {
    final Ansi ansi = log.ansi;
    final String bullet = ansi.bullet;
    final List<Frame> frames =
        trace.callFrames.map((f) => new Frame.fromCallFrame(f)).toList();

    sourceMapManager.mapFrames(frames).then((List<Frame> mappedFrames) {
      if (trace.description != null) {
        log.stderr('exception $bullet ${ansi.error(trace.description)}');
      }

      log.stderr(Frame
          .formatFrames(mappedFrames, selfRefName: selfRefName)
          .map((line) {
        return 'exception $bullet   ${ansi.error(line)}';
      }).join('\n'));
    }).catchError((e) {
      log.stdout('error resolving source maps: $e');

      if (trace.description != null) {
        log.stderr('exception $bullet ${ansi.error(trace.description)}');
      }

      log.stderr(Frame.formatFrames(frames).map((line) {
        return 'exception $bullet   ${ansi.error(line)}';
      }).join('\n'));
    });
  }
}

class DebounceTimer {
  final VoidFunction callback;
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
