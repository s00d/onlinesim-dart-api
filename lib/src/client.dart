import 'dart:async';
import 'dart:convert';

import 'errors.dart';
import 'free.dart';
import 'json.dart';
import 'numbers.dart';
import 'rent.dart';
import 'transport.dart';
import 'user.dart';

/// Default API base.
const defaultBaseUrl = 'https://onlinesim.host/api/';

/// Default per-request timeout.
const defaultTimeout = Duration(seconds: 30);

const _bodyExcerpt = 500;

/// The one request function the sections call. [endpoint] is relative to the
/// base URL, suffix included (`getNum.php`). Query values that are `null`,
/// empty strings or empty lists are omitted, booleans become `1`/`0`, lists a
/// comma list. A non-null [body] is sent as JSON with `POST`.
///
/// Returns the payload with `response` stripped (a map), or the body as is
/// when it has no `response` key (bare arrays, tariffs).
typedef RequestFn = Future<Object?> Function(
  String endpoint, {
  Map<String, Object?> query,
  Object? body,
});

/// OnlineSim API client.
///
/// ```dart
/// final client = OnlineSim(apiKey: 'your-api-key');
/// final balance = await client.user.balance();
/// ```
final class OnlineSim {
  /// Creates a client.
  ///
  /// [apiKey] is sent as `Authorization: Bearer <apiKey>` (not needed for
  /// tariffs and free numbers). [baseUrl] may omit the trailing slash. [lang]
  /// is the language of server texts; [devId] the partner developer id, sent
  /// only when set. [timeout] applies to each request. [transport] defaults to
  /// an [HttpTransport] owned (and closed by [close]) by this client.
  OnlineSim({
    String? apiKey,
    String baseUrl = defaultBaseUrl,
    String lang = 'en',
    String? devId,
    Duration timeout = defaultTimeout,
    OnlineSimTransport? transport,
  })  : _apiKey = apiKey == null || apiKey.isEmpty ? null : apiKey,
        _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _lang = lang,
        _devId = devId == null || devId.isEmpty ? null : devId,
        _timeout = timeout,
        _transport = transport ?? HttpTransport(),
        _ownsTransport = transport == null;

  final String? _apiKey;
  final Uri _baseUri;
  final String _lang;
  final String? _devId;
  final Duration _timeout;
  final OnlineSimTransport _transport;
  final bool _ownsTransport;

  /// Numbers for receiving SMS.
  late final NumbersApi numbers = NumbersApi(_request);

  /// Rented numbers.
  late final RentApi rent = RentApi(_request);

  /// The account.
  late final UserApi user = UserApi(_request);

  /// Public free numbers.
  late final FreeApi free = FreeApi(_request);

  /// Releases the default transport. A transport passed to the constructor
  /// stays open: its owner closes it.
  void close() {
    final transport = _transport;
    if (_ownsTransport && transport is HttpTransport) transport.close();
  }

  Future<Object?> _request(
    String endpoint, {
    Map<String, Object?> query = const {},
    Object? body,
  }) async {
    final params = <String, String>{};
    for (final MapEntry(:key, :value)
        in {...query, 'lang': _lang, 'dev_id': _devId}.entries) {
      final encoded = _encode(value);
      if (encoded != null) params[key] = encoded;
    }
    final headers = {
      'Accept': 'application/json',
      if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      if (body != null) 'Content-Type': 'application/json',
    };
    final request = TransportRequest(
      method: body == null ? 'GET' : 'POST',
      url: _baseUri.resolve(endpoint).replace(queryParameters: params),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );

    final TransportResponse response;
    try {
      response = await _transport.send(request).timeout(_timeout);
    } on TimeoutException {
      throw TransportException(
        'Request timed out after ${_timeout.inMilliseconds} ms',
      );
    } on OnlineSimException {
      rethrow;
    } catch (error) {
      throw TransportException('Network error: $error');
    }

    final status = response.status;
    final text = response.body;
    final excerpt =
        text.length > _bodyExcerpt ? text.substring(0, _bodyExcerpt) : text;
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw TransportException(
        'HTTP $status: response is not JSON',
        status: status,
        body: excerpt,
      );
    }
    // The body is checked before the status: a wrong key is HTTP 456 with
    // {"response":"ERROR_WRONG_KEY"}, the rate limit HTTP 429 with
    // {"response":"TRY_AGAIN_LATER"}.
    if (data is Map && data.containsKey('response')) {
      return _unwrap(data.cast<String, Object?>());
    }
    if (status < 200 || status >= 300) {
      throw TransportException('HTTP $status', status: status, body: excerpt);
    }
    return data;
  }
}

/// Success: strip `response`, return the rest. Error code: throw.
Map<String, Object?> _unwrap(Map<String, Object?> data) {
  final response = data['response'];
  if (response == 1 || response == '1') {
    return Map.of(data)..remove('response');
  }
  if (response is Map) {
    // profile.php validation errors:
    // {"response":{"webhook_url":["The webhook url must be a valid URL."]}}
    final message = response.values
        .expand((v) => v is List ? v : [v])
        .map((v) => '$v')
        .join('; ');
    throw ApiException('VALIDATION_ERROR', message);
  }
  final code = asString(response) ?? '$response';
  // Debug backends echo the code as `message`; prefer the readable fallback.
  final raw = data['message'];
  final message = raw is String && raw != code ? raw : null;
  if (code == 'NO_NUMBER') {
    throw NoNumberException(code, message);
  }
  throw ApiException(code, message);
}

String? _encode(Object? value) => switch (value) {
      null || '' => null,
      final bool b => b ? '1' : '0',
      final Iterable<Object?> list => list.isEmpty ? null : list.join(','),
      _ => '$value',
    };
