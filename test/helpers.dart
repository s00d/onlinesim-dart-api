import 'dart:convert';
import 'dart:io';

import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

/// A canned JSON answer.
TransportResponse json(Object? body, {int status = 200}) =>
    TransportResponse(status, jsonEncode(body));

/// A canned non-JSON answer.
TransportResponse raw(String body, {int status = 200}) =>
    TransportResponse(status, body);

/// Decoded `test/fixtures/<name>.json`.
Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

/// [fixture] as a map.
Map<String, Object?> fixtureMap(String name) =>
    (fixture(name)! as Map).cast<String, Object?>();

/// Transport that answers [replies] in order (a [TransportResponse], or any
/// other object to throw) and records every request.
final class FakeTransport implements OnlineSimTransport {
  FakeTransport(List<Object> replies) : _queue = [...replies];

  final List<Object> _queue;

  /// Requests received, in order.
  final List<TransportRequest> calls = [];

  /// The only request made; fails when there were more or none.
  TransportRequest get last {
    expect(calls, hasLength(1), reason: 'expected exactly one request');
    return calls.single;
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    calls.add(request);
    if (_queue.isEmpty) fail('unexpected request ${request.url}');
    final reply = _queue.removeAt(0);
    if (reply is TransportResponse) return reply;
    throw reply;
  }
}

/// Client on a [FakeTransport] answering [replies].
(OnlineSim, FakeTransport) fakeClient(
  List<Object> replies, {
  String? apiKey = 'test-key',
  String baseUrl = 'https://api.test/api/',
  String lang = 'en',
  String? devId,
}) {
  final transport = FakeTransport(replies);
  final client = OnlineSim(
    apiKey: apiKey,
    baseUrl: baseUrl,
    lang: lang,
    devId: devId,
    transport: transport,
  );
  return (client, transport);
}

/// Query of a request without the `lang` every request carries.
Map<String, String> query(TransportRequest call) =>
    Map.of(call.url.queryParameters)..remove('lang');

/// Matches an [ApiException] with [code] (and [message], when given).
Matcher apiError(String code, [String? message]) {
  var m = isA<ApiException>().having((e) => e.code, 'code', code);
  if (message != null) m = m.having((e) => e.message, 'message', message);
  return m;
}

/// Throws an [ApiException] with [code].
Matcher throwsApi(String code, [String? message]) =>
    throwsA(apiError(code, message));
