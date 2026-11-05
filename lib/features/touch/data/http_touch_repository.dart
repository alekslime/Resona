import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import '../domain/region.dart';
import '../../learn/domain/library.dart';
import 'touch_repository.dart';

/// Talks to the Resonant backend (see backend/), which holds the Meta API key.
/// The phone never sees the key.
/// The streaming endpoint is missing (an older backend) or misbehaving: fall
/// back to the plain JSON endpoint instead of failing the picture.
class _StreamUnsupported implements Exception {
  const _StreamUnsupported();
}

class HttpTouchRepository implements TouchRepository {
  HttpTouchRepository(
      {required this.baseUrl,
      http.Client? client,
      AssetBundle? bundle,
      this.slowAfter = const Duration(seconds: 4)})
      : _http = client ?? http.Client(),
        _bundle = bundle ?? rootBundle;

  final String baseUrl;
  final http.Client _http;
  final AssetBundle _bundle;

  /// How long a call runs silent before its [onSlow] fires. Short in tests.
  final Duration slowAfter;

  /// One slow-timer for one request: fires [onSlow] once, or never when the
  /// response lands first. The caller cancels it in a finally.
  Timer? _armSlow(void Function()? onSlow) =>
      onSlow == null ? null : Timer(slowAfter, onSlow);

  String _dataUrl(PictureBytes p) =>
      'data:${p.mime};base64,${base64Encode(p.bytes)}';

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
    Duration timeout, [
    void Function()? onSlow,
  ]) async {
    final slow = _armSlow(onSlow);
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw TouchApiException('That took too long. Try again.');
    } catch (_) {
      throw TouchApiException(
          'Cannot reach the server. Check your connection.');
    } finally {
      slow?.cancel();
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw TouchApiException(
          'The server sent something unexpected. Try again.');
    }
    if (res.statusCode != 200) {
      throw TouchApiException(
          (json['error'] as String?) ?? 'Something went wrong. Try again.');
    }
    return json;
  }

  @override
  Future<Analysis> analyze(
    PictureBytes picture, {
    void Function(AnalyzeProgress progress)? onProgress,
    void Function()? onSlow,
  }) async {
    // One announcement for the whole call, even if the stream attempt and
    // the plain fallback are both slow.
    var announced = false;
    void once() {
      if (announced) return;
      announced = true;
      onSlow?.call();
    }

    final slow = onSlow == null ? null : once;
    try {
      return await _analyzeStream(picture, onProgress, slow);
    } on _StreamUnsupported {
      // An older backend without /api/analyze-stream: same result, no progress.
      final json = await _post(
          '/api/analyze',
          {
            'image': _dataUrl(picture),
          },
          const Duration(seconds: 120),
          slow);
      return Analysis.fromJson(json);
    }
  }

  /// POST /api/analyze-stream and parse its server-sent events: "progress"
  /// per outlined part, then "done" with the full payload or "error".
  Future<Analysis> _analyzeStream(
    PictureBytes picture,
    void Function(AnalyzeProgress progress)? onProgress,
    void Function()? onSlow,
  ) async {
    final slow = _armSlow(onSlow);
    try {
      final req = http.Request('POST', Uri.parse('$baseUrl/api/analyze-stream'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'image': _dataUrl(picture)});
      final http.StreamedResponse res;
      try {
        res = await _http.send(req).timeout(const Duration(seconds: 150));
      } on TimeoutException {
        throw TouchApiException('That took too long. Try again.');
      } catch (_) {
        throw TouchApiException(
            'Cannot reach the server. Check your connection.');
      }
      if (res.statusCode == 404) throw const _StreamUnsupported();
      if (res.statusCode != 200) {
        throw TouchApiException(_errorOf(await res.stream.bytesToString()));
      }
      if (!(res.headers['content-type'] ?? '').contains('text/event-stream')) {
        throw const _StreamUnsupported();
      }
      Analysis? done;
      var buf = '';
      void feed(String raw) {
        final event = _sseEvent(raw);
        if (event == null) return;
        slow?.cancel(); // a response arrived: the server is awake
        switch (event.$1) {
          case 'progress':
            final p = event.$2;
            onProgress?.call(
              AnalyzeProgress(
                done: (p['done'] as num).toInt(),
                total: (p['total'] as num).toInt(),
                label: (p['label'] as String?) ?? '',
              ),
            );
          case 'done':
            done = Analysis.fromJson(event.$2);
          case 'error':
            throw TouchApiException(
              (event.$2['error'] as String?) ??
                  'Something went wrong. Try again.',
            );
        }
      }

      try {
        await for (final chunk in res.stream
            .transform(utf8.decoder)
            .timeout(const Duration(seconds: 150))) {
          buf +=
              chunk; // network chunks split mid-event, so re-split on blank lines
          final parts = buf.split('\n\n');
          buf = parts.removeLast();
          for (final raw in parts) {
            feed(raw);
          }
        }
      } on TimeoutException {
        throw TouchApiException('That took too long. Try again.');
      }
      if (buf.trim().isNotEmpty) {
        feed(buf);
      }
      if (done == null) {
        throw TouchApiException(
            'The server sent something unexpected. Try again.');
      }
      return done!;
    } finally {
      slow?.cancel();
    }
  }

  /// One server-sent event: "event: <name>\ndata: <json>". Null when the block
  /// is a heartbeat, a partial write, or anything else unparseable.
  (String, Map<String, dynamic>)? _sseEvent(String raw) {
    String? event;
    final data = <String>[];
    for (final line in raw.split('\n')) {
      if (line.startsWith('event:')) event = line.substring(6).trim();
      if (line.startsWith('data:')) data.add(line.substring(5).trim());
    }
    if (event == null || data.isEmpty) return null;
    try {
      return (event, jsonDecode(data.join('\n')) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String _errorOf(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error'] as String? ??
          'Something went wrong. Try again.';
    } catch (_) {
      return 'Something went wrong. Try again.';
    }
  }

  @override
  Future<String> chat(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    final json = await _post(
        '/api/chat',
        {
          'image': _dataUrl(picture),
          'question': question,
          'title': title,
          'regionLabel': regionLabel,
          'history': [
            for (final h in history) {'q': h.q, 'a': h.a}
          ],
        },
        const Duration(seconds: 60),
        onSlow);
    return json['answer'] as String;
  }

  @override
  Future<String> chatText({
    required String question,
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    final json = await _post(
        '/api/chat',
        {
          'question': question,
          'history': [
            for (final h in history) {'q': h.q, 'a': h.a}
          ],
        },
        const Duration(seconds: 60),
        onSlow);
    return json['answer'] as String;
  }

  @override
  Future<GeneratedQuiz> quiz({
    required String topic,
    List<({String q, String a})> history = const [],
    void Function()? onSlow,
  }) async {
    final json = await _post(
        '/api/quiz',
        {
          'topic': topic,
          'history': [
            for (final h in history) {'q': h.q, 'a': h.a}
          ],
        },
        const Duration(seconds: 90),
        onSlow);
    try {
      return GeneratedQuiz(
        topic: json['topic'] as String,
        questions: [
          for (var i = 0; i < (json['questions'] as List).length; i++)
            _quizQuestion(
                i, (json['questions'] as List)[i] as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      throw TouchApiException('The quiz came back unreadable. Try again.');
    }
  }

  /// One server question with client-side letters (A-D) and a stable id.
  LibraryQuizQuestion _quizQuestion(int index, Map<String, dynamic> q) {
    final options = q['options'] as List;
    return LibraryQuizQuestion(
      id: 'cq$index',
      prompt: q['prompt'] as String,
      options: [
        for (var i = 0; i < options.length; i++)
          LibraryQuizOption(
            letter: String.fromCharCode(65 + i),
            text: options[i] as String,
          ),
      ],
      correctIndex: (q['correctIndex'] as num).toInt(),
      explanation: q['explanation'] as String,
    );
  }

  @override
  Future<LiveVoiceConnection> liveVoice({
    required String title,
    String overview = '',
    String regionLabel = '',
    String regionSpoken = '',
    String regionDetail = '',
  }) async {
    final json = await _post(
        '/api/livekit-token',
        {
          'title': title,
          'overview': overview,
          'regionLabel': regionLabel,
          'regionSpoken': regionSpoken,
          'regionDetail': regionDetail,
        },
        const Duration(seconds: 30));
    return LiveVoiceConnection(
      url: json['url'] as String,
      token: json['token'] as String,
      room: json['room'] as String,
    );
  }

  @override
  Future<(Analysis, PictureBytes)> sample({String id = 'sample'}) async {
    final safe = RegExp(r'^[a-z0-9-]+$').hasMatch(id) ? id : 'sample';
    try {
      final json = jsonDecode(
        await _bundle.loadString('assets/sample/$safe.json'),
      ) as Map<String, dynamic>;
      final data = await _bundle.load('assets/sample/$safe.png');
      final png =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return (Analysis.fromJson(json), PictureBytes(png, 'image/png'));
    } catch (_) {
      throw TouchApiException('The sample picture could not be loaded.');
    }
  }

  @override
  Future<List<GallerySample>> gallery() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/api/samples'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return bundledSamples;
      final list =
          (jsonDecode(res.body) as Map<String, dynamic>)['samples'] as List? ??
              [];
      final bundledIds = bundledSamples.map((s) => s.id).toSet();
      final extras = [
        for (final e in list)
          if (e is Map && e['id'] is String && !bundledIds.contains(e['id']))
            GallerySample(
              id: e['id'] as String,
              title: (e['title'] as String?) ?? e['id'] as String,
              kind: (e['kind'] as String?) ?? 'other',
              regions: (e['regions'] as num?)?.toInt() ?? 0,
              remoteJson: e['json'] as String?,
              remoteImage: e['image'] as String?,
            ),
      ];
      return [...bundledSamples, ...extras];
    } catch (_) {
      return bundledSamples; // offline: the bundled pictures always work
    }
  }

  @override
  Future<(Analysis, PictureBytes)> openGallery(GallerySample entry) async {
    if (entry.bundled) return sample(id: entry.id);
    if (entry.remoteJson == null || entry.remoteImage == null) {
      throw TouchApiException('That sample is missing its picture.');
    }
    try {
      final jsonRes = await _http
          .get(Uri.parse('$baseUrl${entry.remoteJson}'))
          .timeout(const Duration(seconds: 30));
      final imgRes = await _http
          .get(Uri.parse('$baseUrl${entry.remoteImage}'))
          .timeout(const Duration(seconds: 30));
      if (jsonRes.statusCode != 200 || imgRes.statusCode != 200) {
        throw TouchApiException('That sample could not be loaded. Try again.');
      }
      return (
        Analysis.fromJson(jsonDecode(jsonRes.body) as Map<String, dynamic>),
        PictureBytes(imgRes.bodyBytes, 'image/png'),
      );
    } on TouchApiException {
      rethrow;
    } catch (_) {
      throw TouchApiException(
          'Cannot reach the server. Check your connection.');
    }
  }

  @override
  Future<ServerHealth> health() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return const ServerHealth(reachable: false, metaConfigured: false);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return ServerHealth(
        reachable: true,
        metaConfigured: json['metaConfigured'] == true,
      );
    } catch (_) {
      return const ServerHealth(reachable: false, metaConfigured: false);
    }
  }
}
