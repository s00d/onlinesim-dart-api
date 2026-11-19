import 'dart:convert';

import 'package:http/http.dart' as http;

/// One HTTP request the client sends.
final class TransportRequest {
  /// Creates a request.
  const TransportRequest({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
  });

  /// `GET` or `POST`.
  final String method;

  /// Full URL with the query string.
  final Uri url;

  /// Request headers (`Accept`, `Authorization`, `Content-Type`).
  final Map<String, String> headers;

  /// JSON body of a `POST`; `null` for `GET`.
  final String? body;
}

/// The HTTP answer a transport returns: status and body text.
final class TransportResponse {
  /// Creates a response.
  const TransportResponse(this.status, this.body);

  /// HTTP status code.
  final int status;

  /// Body decoded as UTF-8.
  final String body;
}

/// What the client needs from HTTP: send one request, return status and body.
///
/// The default is [HttpTransport] (`package:http`, works on every platform
/// including the web). Implement it to route requests elsewhere, or use
/// `MockOnlineSim`, which is a transport answering in-process. Throw anything
/// on a network failure: the client turns it into a `TransportException`.
abstract interface class OnlineSimTransport {
  /// Sends [request] and returns the answer, whatever its HTTP status.
  Future<TransportResponse> send(TransportRequest request);
}

/// [OnlineSimTransport] over a `package:http` [http.Client].
final class HttpTransport implements OnlineSimTransport {
  /// Wraps [client]; a new `http.Client()` when omitted. Pass an `IOClient`
  /// (proxy, custom TLS) or any other `http.Client` implementation.
  HttpTransport([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final req = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    final body = request.body;
    if (body != null) req.bodyBytes = utf8.encode(body);
    final res = await http.Response.fromStream(await _client.send(req));
    // Not `res.body`: without a charset in Content-Type it decodes as Latin-1.
    return TransportResponse(
      res.statusCode,
      utf8.decode(res.bodyBytes, allowMalformed: true),
    );
  }

  /// Closes the underlying `http.Client`.
  void close() => _client.close();
}
