import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Replies to every request with a canned JSON response; no real network.
class StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object? _body;
  String? lastPath;
  Object? lastBody;

  void reply(int status, Object body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
