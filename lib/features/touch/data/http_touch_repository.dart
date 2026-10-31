import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../learn/domain/learn.dart';
import '../domain/region.dart';
import 'touch_repository.dart';

/// Talks to the Resonant backend (see backend/), which holds the Meta API key.
/// The phone never sees the key.
class HttpTouchRepository implements TouchRepository {
  HttpTouchRepository({required this.baseUrl, http.Client? client})
    : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String _dataUrl(PictureBytes p) => 'data:${p.mime};base64,${base64Encode(p.bytes)}';

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
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
      throw TouchApiException('Cannot reach the server. Check your connection.');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw TouchApiException('The server sent something unexpected. Try again.');
    }
    if (res.statusCode != 200) {
      throw TouchApiException((json['error'] as String?) ?? 'Something went wrong. Try again.');
    }
    return json;
  }

  @override
  Future<Analysis> analyze(PictureBytes picture) async {
    final json = await _post('/api/analyze', {
      'image': _dataUrl(picture),
    }, const Duration(seconds: 120));
    return Analysis.fromJson(json);
  }

  @override
  Future<String> ask(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
  }) async {
    final json = await _post('/api/ask', {
      'image': _dataUrl(picture),
      'question': question,
      'title': title,
      'regionLabel': regionLabel,
    }, const Duration(seconds: 60));
    return json['answer'] as String;
  }

  @override
  Future<String> chat(
    PictureBytes picture, {
    required String question,
    required String title,
    String regionLabel = '',
    List<({String q, String a})> history = const [],
  }) async {
    final json = await _post('/api/chat', {
      'image': _dataUrl(picture),
      'question': question,
      'title': title,
      'regionLabel': regionLabel,
      'history': [for (final h in history) {'q': h.q, 'a': h.a}],
    }, const Duration(seconds: 60));
    return json['answer'] as String;
  }

  Map<String, dynamic> _learnBody(Analysis a) => {
    'title': a.title,
    'overview': a.overview,
    'regions': [
      for (final r in a.regions)
        {'id': r.id, 'label': r.label, 'spoken': r.spoken, 'detail': r.detail},
    ],
  };

  @override
  Future<Lesson> lesson(Analysis analysis) async =>
      Lesson.fromJson(await _post('/api/lesson', _learnBody(analysis), const Duration(seconds: 60)));

  @override
  Future<Quiz> quiz(Analysis analysis) async =>
      Quiz.fromJson(await _post('/api/quiz', _learnBody(analysis), const Duration(seconds: 60)));

  @override
  Future<Grade> grade({
    required String question,
    required String expected,
    required String answer,
  }) async {
    final json = await _post('/api/grade', {
      'question': question,
      'expected': expected,
      'answer': answer,
    }, const Duration(seconds: 60));
    return Grade.fromJson(json);
  }

  @override
  Future<LiveVoiceConnection> liveVoice({
    required String title,
    String overview = '',
    String regionLabel = '',
    String regionSpoken = '',
    String regionDetail = '',
  }) async {
    final json = await _post('/api/livekit-token', {
      'title': title,
      'overview': overview,
      'regionLabel': regionLabel,
      'regionSpoken': regionSpoken,
      'regionDetail': regionDetail,
    }, const Duration(seconds: 30));
    return LiveVoiceConnection(
      url: json['url'] as String,
      token: json['token'] as String,
      room: json['room'] as String,
    );
  }

  @override
  Future<(Analysis, PictureBytes)> sample() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/sample/sample.json'),
    ) as Map<String, dynamic>;
    final data = await rootBundle.load('assets/sample/sample.png');
    final png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return (Analysis.fromJson(json), PictureBytes(png, 'image/png'));
  }
}
