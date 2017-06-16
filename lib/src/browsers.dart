// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    as wip;

class Chrome {
  static final String macosBundlePath = 'Contents/MacOS/Google Chrome';

  static Chrome locate() {
    if (Platform.isMacOS) {
      final String defaultPath = '/Applications/Google Chrome.app';

      if (FileSystemEntity.isDirectorySync(defaultPath)) {
        // Contents/MacOS/Google Chrome
        return new Chrome.from(path.join(defaultPath, macosBundlePath));
      }
    }

    // TODO: try `which`

    return null;
  }

  factory Chrome.from(String executable) {
    return FileSystemEntity.isFileSync(executable)
        ? new Chrome._(executable)
        : null;
  }

  final String executable;

  Chrome._(this.executable);

  Future<ChromeProcess> start({String url, int debugPort: 9222}) {
    String dataDir = path.absolute('.chromeDataDir');
    List<String> args = [
      '--no-default-browser-check',
      '--no-first-run',
      '--user-data-dir=$dataDir',
      '--remote-debugging-port=$debugPort'
    ];
    if (url != null) {
      args.add(url);
    }
    return Process.start(executable, args).then((Process process) {
      return new ChromeProcess(process, debugPort);
    });
  }
}

class ChromeProcess {
  final Process process;
  final int debugPort;
  bool _processAlive = true;

  ChromeProcess(this.process, this.debugPort);

  Future<ChromeTab> connectToTab(
    String url, {
    Duration timeout: const Duration(seconds: 20),
  }) async {
    wip.ChromeConnection connection =
        new wip.ChromeConnection(Uri.parse(url).host, debugPort);

    wip.ChromeTab wipTab = await connection.getTab((wip.ChromeTab tab) {
      return tab.url == url;
    }, retryFor: timeout);

    process.exitCode.then((_) {
      _processAlive = false;
    });

    return wipTab == null ? null : new ChromeTab(wipTab);
  }

  bool get isAlive => _processAlive;

  /// Returns `true` if the signal is successfully delivered to the process.
  /// Otherwise the signal could not be sent, usually meaning that the process
  /// is already dead.
  bool kill() => process.kill();

  Future<int> get onExit => process.exitCode;
}

class ChromeTab {
  final wip.ChromeTab wipTab;
  wip.WipConnection _wip;

  StreamController _disconnectStream = new StreamController.broadcast();
  StreamController<wip.LogEntry> _entryAddedController =
      new StreamController.broadcast();
  StreamController<wip.ConsoleAPIEvent> _consoleAPICalledController =
      new StreamController.broadcast();
  StreamController<wip.ExceptionThrownEvent> _exceptionThrownController =
      new StreamController.broadcast();

  num _lostConnectionTime;

  ChromeTab(this.wipTab);

  Future connect(Logger log) async {
    _wip = await wipTab.connect();

    _wip.log.enable();
    _wip.log.onEntryAdded.listen((wip.LogEntry entry) {
      if (_lostConnectionTime == null ||
          entry.timestamp > _lostConnectionTime) {
        _entryAddedController.add(entry);
      }
    });

    _wip.runtime.enable();
    _wip.runtime.onConsoleAPICalled.listen((wip.ConsoleAPIEvent event) {
      if (_lostConnectionTime == null ||
          event.timestamp > _lostConnectionTime) {
        _consoleAPICalledController.add(event);
      }
    });

    _exceptionThrownController.addStream(_wip.runtime.onExceptionThrown);

    _wip.page.enable();

    if (log.isVerbose) {
      _wip.onNotification.listen((e) {
        log.trace(e.toString());
      });
    }

    _wip.onClose.listen((_) {
      _wip = null;
      _disconnectStream.add(null);
      _lostConnectionTime = new DateTime.now().millisecondsSinceEpoch;
    });
  }

  bool get isConnected => _wip != null;

  Stream get onDisconnect => _disconnectStream.stream;

  Stream<wip.LogEntry> get onLogEntryAdded => _entryAddedController.stream;

  Stream<wip.ConsoleAPIEvent> get onConsoleAPICalled =>
      _consoleAPICalledController.stream;

  Stream<wip.ExceptionThrownEvent> get onExceptionThrown =>
      _exceptionThrownController.stream;

  Future reload() => _wip.page.reload();

  Future reconnectWhile(Logger log, bool shouldReconnect()) {
    assert(_wip == null);

    var tryConnect;
    Completer completer = new Completer();

    tryConnect = () {
      connect(log).then((_) {
        completer.complete();
      }).catchError((e) {
        if (shouldReconnect()) {
          new Timer(new Duration(seconds: 2), tryConnect);
        }
      });
    };

    new Timer(new Duration(seconds: 2), tryConnect);

    return completer.future;
  }
}
