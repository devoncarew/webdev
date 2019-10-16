// Copyright (c) 2017, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:http_client/console.dart';
import 'package:source_maps/source_maps.dart' as source_maps;
import 'package:webkit_inspection_protocol/src/runtime.dart';

typedef void LoggingFunction(String str);

class SourceMapManager {
  final Map<String, source_maps.Mapping> parsedMappings = new Map();
  final ConsoleClient httpClient = new ConsoleClient();
  final LoggingFunction logger;

  SourceMapManager({this.logger});

  /// Attempt to map the given frames, loading any source maps that are required
  /// to do so.
  ///
  /// If a frame cannot be mapped, the original frame information is returned.
  Future<List<Frame>> mapFrames(List<Frame> frames) async {
    final Set<String> urls = new Set();
    for (Frame frame in frames) {
      urls.add(frame.url);
    }

    urls.removeAll(parsedMappings.keys);

    // load all mappings for urls
    await Future.wait(urls.map((url) => _loadMappingForUrl(url)));

    return frames.map((Frame frame) {
      final source_maps.Mapping mapping = parsedMappings[frame.url];
      if (mapping == null) {
        return frame;
      } else {
        source_maps.SourceMapSpan span =
            mapping.spanFor(frame.lineNumber, frame.columnNumber);
        if (span == null) {
          return frame;
        } else {
          // We add one to the mapped line and column - they're 0 based, but
          // people would expect to read them as 1 based.
          return new Frame(frame.functionName, span.start.sourceUrl.toString(),
              span.start.line + 1, span.start.column + 1,
              wasMapped: true);
        }
      }
    }).toList();
  }

  // Store the mapping in parsedMappings, or null or no mapping was available.
  Future _loadMappingForUrl(String url) async {
    parsedMappings[url] = null;

    Response response = await httpClient.send(new Request('GET', url));
    if (response.statusCode != 200) {
      return;
    }

    final String source = await response.readAsString();
    // "//# sourceMappingURL=lib__framework__framework.js.map"
    int index = source.indexOf('\n//# sourceMappingURL=');
    if (index == -1) {
      return;
    }

    String mapUrl = source.substring(index + 1);
    if (mapUrl.indexOf('\n') != -1) {
      mapUrl = mapUrl.substring(0, mapUrl.indexOf('\n'));
    }
    mapUrl = mapUrl.substring(mapUrl.indexOf('=') + 1);
    mapUrl = Uri.parse(url).resolve(mapUrl).toString();

    response = await httpClient.send(new Request('GET', mapUrl));
    if (response.statusCode != 200) {
      return;
    }

    if (logger != null) {
      logger('loading sourcemap for $url');
    }

    source_maps.Mapping mapping =
        source_maps.parse(await response.readAsString(), mapUrl: mapUrl);
    parsedMappings[url] = mapping;
  }

  void clearCache() {
    parsedMappings.clear();
  }
}

class Frame {
  final String functionName;
  final String url;
  final int lineNumber;
  final int columnNumber;
  final bool wasMapped;

  Frame(
    this.functionName,
    this.url,
    this.lineNumber,
    this.columnNumber, {
    this.wasMapped: false,
  });

  Frame.fromCallFrame(CallFrame frame)
      : this.functionName = frame.functionName,
        this.url = frame.url,
        this.lineNumber = frame.lineNumber,
        this.columnNumber = frame.columnNumber,
        this.wasMapped = false;

  /// Pretty print the url location - map it to a local file if possible.
  String getDisplayLocation({String selfRefName}) {
    if (!wasMapped) return url;

    // http://localhost:8080/packages/foo/bar.dart
    if (!url.startsWith('http://localhost:')) return url;

    String file = Uri.parse(url).path;
    if (file.startsWith('/')) {
      file = file.substring(1);
    }

    if (file.startsWith('packages/$selfRefName/')) {
      file = file.substring('packages/$selfRefName'.length);
      file = 'lib$file';
    } else if (file.startsWith('packages/')) {
      file = file.substring('packages/'.length);
      file = 'package:$file';
    }

    return file;
  }

  static List<String> formatFrames(List<Frame> frames, {String selfRefName}) {
    int width = frames.fold(0, (int val, Frame frame) {
      return math.max(val, frame.functionName.length);
    });

    return frames.map((Frame frame) {
      return '${frame.functionName}()'.padRight(width + 2) +
          ' ${frame.getDisplayLocation(selfRefName: selfRefName)} '
              '${frame.lineNumber}:${frame.columnNumber}';
    }).toList();
  }
}
