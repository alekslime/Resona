import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resonant/features/touch/data/http_touch_repository.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// An AssetBundle that reads the real asset files off disk.
class FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).readAsString();

  @override
  void evict(String key) {}
}

/// A client that drips the response out in tiny chunks, the way SSE arrives
/// over a real network: events split mid-line, mid-word, anywhere.
class ChunkedClient extends http.BaseClient {
  ChunkedClient(this.response);
  final http.Response response;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = response.bodyBytes;
    final chunks = <List<int>>[];
    for (var i = 0; i < bytes.length; i += 7) {
      chunks.add(bytes.sublist(i, (i + 7).clamp(0, bytes.length)));
    }
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

String get sampleJson => File('assets/sample/sample.json').readAsStringSync();

/// The same payload on one line, the way SSE carries it (JSON.stringify).
String get sampleJsonLine => jsonEncode(jsonDecode(sampleJson));

String sse(List<(String, String)> events) =>
    events.map((e) => 'event: ${e.$1}\ndata: ${e.$2}\n\n').join();

HttpTouchRepository repo(http.Client client) => HttpTouchRepository(
    baseUrl: 'http://x', client: client, bundle: FileBundle());

void main() {
  group('analyze', () {
    test('streams progress per part, then returns the analysis', () async {
      final seen = <AnalyzeProgress>[];
      final client = MockClient((req) async {
        expect(req.url.path, '/api/analyze-stream');
        return http.Response(
          sse([
            ('progress', '{"done":1,"total":2,"label":"sun"}'),
            ('progress', '{"done":2,"total":2,"label":"cloud"}'),
            ('done', sampleJsonLine),
          ]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });
      final a = await repo(client).analyze(tinyPicture, onProgress: seen.add);
      expect(a.title, 'The water cycle');
      expect(
        seen.map((p) => '${p.done}/${p.total} ${p.label}'),
        ['1/2 sun', '2/2 cloud'],
      );
    });

    test('progress survives events split across network chunks', () async {
      final seen = <AnalyzeProgress>[];
      final client = ChunkedClient(
        http.Response(
          sse([
            ('progress', '{"done":1,"total":1,"label":"sun"}'),
            ('done', sampleJsonLine),
          ]),
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      );
      final a = await repo(client).analyze(tinyPicture, onProgress: seen.add);
      expect(a.title, 'The water cycle');
      expect(seen.length, 1);
    });

    test('falls back to plain analyze when the server has no stream endpoint',
        () async {
      final paths = <String>[];
      final client = MockClient((req) async {
        paths.add(req.url.path);
        if (req.url.path == '/api/analyze-stream') {
          return http.Response('nope', 404);
        }
        return http.Response(sampleJson, 200);
      });
      final seen = <AnalyzeProgress>[];
      final a = await repo(client).analyze(tinyPicture, onProgress: seen.add);
      expect(a.title, 'The water cycle');
      expect(paths, ['/api/analyze-stream', '/api/analyze']);
      expect(seen, isEmpty);
    });

    test('falls back when the stream endpoint answers non-SSE', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/analyze-stream') {
          return http.Response('ok', 200,
              headers: {'content-type': 'text/plain'});
        }
        return http.Response(sampleJson, 200);
      });
      expect(
          (await repo(client).analyze(tinyPicture)).title, 'The water cycle');
    });

    test('a stream error event speaks the plain error', () async {
      final client = MockClient(
        (_) async => http.Response(
          sse([
            (
              'error',
              '{"error":"Too many requests. Wait a minute and try again."}'
            ),
          ]),
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      );
      expect(
        () => repo(client).analyze(tinyPicture),
        throwsA(
          isA<TouchApiException>().having(
            (e) => e.message,
            'message',
            'Too many requests. Wait a minute and try again.',
          ),
        ),
      );
    });

    test('a stream that ends without done fails plainly', () async {
      final client = MockClient(
        (_) async => http.Response(
          sse([
            ('progress', '{"done":1,"total":2,"label":"sun"}'),
          ]),
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      );
      expect(
        () => repo(client).analyze(tinyPicture),
        throwsA(isA<TouchApiException>()),
      );
    });
  });

  group('gallery', () {
    test('bundled entries plus backend extras, bundled wins on id clash',
        () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'samples': [
              {
                'id': 'sample',
                'title': 'Water (server)',
                'kind': 'diagram',
                'regions': 4,
                'json': '/sample/sample.json',
                'image': '/sample/sample.png',
              },
              {
                'id': 'cell',
                'title': 'Plant cell',
                'kind': 'diagram',
                'regions': 6,
                'json': '/sample/cell.json',
                'image': '/sample/cell.png',
              },
            ],
          }),
          200,
        ),
      );
      final entries = await repo(client).gallery();
      expect(entries.map((e) => e.id), ['sample', 'chart', 'cell']);
      expect(entries.first.bundled, isTrue); // the offline copy wins
      expect(entries.first.title, 'The water cycle');
      expect(entries.last.remoteJson, '/sample/cell.json');
    });

    test('an unreachable server still offers the bundled pictures', () async {
      final client =
          MockClient((_) async => throw const SocketException('down'));
      final entries = await repo(client).gallery();
      expect(entries.map((e) => e.id), ['sample', 'chart']);
      expect(entries.every((e) => e.bundled), isTrue);
    });

    test('opening a remote entry downloads its outlines and picture', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('.json')) {
          return http.Response(sampleJson, 200);
        }
        return http.Response.bytes([1, 2, 3], 200);
      });
      final (analysis, picture) = await repo(client).openGallery(
        const GallerySample(
          id: 'cell',
          title: 'Plant cell',
          kind: 'diagram',
          regions: 6,
          remoteJson: '/sample/cell.json',
          remoteImage: '/sample/cell.png',
        ),
      );
      expect(analysis.title, 'The water cycle');
      expect(picture.bytes, [1, 2, 3]);
    });

    test('opening a bundled entry never touches the network', () async {
      final client = MockClient((_) async => throw StateError('network used'));
      final (analysis, _) =
          await repo(client).openGallery(bundledSamples.first);
      expect(analysis.title, 'The water cycle');
    });
  });

  group('sample', () {
    test('loads each bundled picture by id', () async {
      final r = repo(MockClient((_) async => throw StateError('network used')));
      expect((await r.sample()).$1.title, 'The water cycle');
      expect((await r.sample(id: 'chart')).$1.title, 'Spring rainfall');
    });
  });

  group('health', () {
    test('a live backend reports whether it can analyze', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"ok":true,"metaConfigured":true}',
          200,
        ),
      );
      final h = await repo(client).health();
      expect((h.reachable, h.metaConfigured), (true, true));
    });

    test('a keyless backend is reachable but cannot analyze', () async {
      final client = MockClient(
        (_) async => http.Response('{"ok":true,"metaConfigured":false}', 200),
      );
      final h = await repo(client).health();
      expect((h.reachable, h.metaConfigured), (true, false));
    });

    test('a dead server is data, not an error', () async {
      final down =
          repo(MockClient((_) async => throw const SocketException('down')));
      expect((await down.health()).reachable, isFalse);
      final sick = repo(MockClient((_) async => http.Response('bad', 500)));
      expect((await sick.health()).reachable, isFalse);
      final junk =
          repo(MockClient((_) async => http.Response('not json', 200)));
      expect((await junk.health()).reachable, isFalse);
    });
  });
}
