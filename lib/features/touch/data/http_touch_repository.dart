import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

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
  Future<(Analysis, PictureBytes)> sample() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/sample/sample.json'),
    ) as Map<String, dynamic>;
    final data = await rootBundle.load('assets/sample/sample.png');
    final png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return (Analysis.fromJson(json), PictureBytes(png, 'image/png'));
  }
}
