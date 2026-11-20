import 'dart:convert';

import '../client.dart';
import '../models/numbers.dart';
import '../transport.dart';

part 'handlers.dart';
part 'state.dart';

/// Base URL of clients made by [MockOnlineSim.client]. Never contacted: the
/// mock answers in-process.
const mockBaseUrl = 'https://mock.onlinesim.invalid/api/';

/// In-process fake OnlineSim API for tests: no network, no key, no money, no
/// clock.
///
/// It is an [OnlineSimTransport] that answers like the real backend;
/// [client] returns a normal [OnlineSim] wired to it. Test helpers add SMS,
/// queue failures and expose the state. Deterministic: ids and numbers come
/// from a counter.
///
/// ```dart
/// final mock = MockOnlineSim(balance: 10);
/// final client = mock.client();
/// final tzid = await client.numbers.get('google', country: 44);
/// mock.addSmsAfter(tzid, 'Your code: 123-456', 2);
/// await client.numbers.waitCode(tzid, interval: Duration.zero); // '123456'
/// ```
final class MockOnlineSim implements OnlineSimTransport {
  /// Creates a mock.
  ///
  /// [apiKey] is the key it accepts as `Authorization: Bearer <apiKey>`.
  /// [balance] is the starting balance, USD. [prices] and [rentTariffs]
  /// replace [defaultMockPrices] and [defaultMockRentTariffs]. With
  /// [guardInterval] (seconds) `> 0` an operation without SMS, or an
  /// unconfirmed rent without any SMS, cannot be closed (`NO_COMPLETE_TZID`).
  MockOnlineSim({
    String apiKey = 'mock-key',
    double balance = 100,
    MockPrices prices = defaultMockPrices,
    Map<int, MockRentTariff> rentTariffs = defaultMockRentTariffs,
    int guardInterval = 0,
  }) : _state = _MockState(
          apiKey: apiKey,
          guardInterval: guardInterval,
          prices: prices,
          rentTariffs: rentTariffs,
          balanceMills: _toMills(balance),
        );

  final _MockState _state;

  /// A normal client wired to the mock. [apiKey] defaults to the mock's key;
  /// pass another one (or `''` for none) to test a wrong key.
  OnlineSim client({
    String? apiKey,
    String lang = 'en',
    String? devId,
    Duration timeout = defaultTimeout,
  }) =>
      OnlineSim(
        apiKey: apiKey ?? _state.apiKey,
        baseUrl: mockBaseUrl,
        lang: lang,
        devId: devId,
        timeout: timeout,
        transport: this,
      );

  /// An SMS arrives now at number operation or rent [tzid]. Throws
  /// [StateError] when there is no open operation or rent with that id.
  /// The first rent SMS whose [service] is not `notify` confirms the rent and
  /// charges it; `service: 'notify'` adds a notice with `code` `0` that
  /// confirms nothing.
  void addSms(int tzid, String text, {String? service}) {
    if (!_state.deliver(tzid, text, service)) {
      throw StateError('MockOnlineSim: no open operation or rent $tzid');
    }
  }

  /// The SMS arrives after [polls] state requests for [tzid] (`getState` /
  /// rent `getRentState`, listing it alone or with others): with `polls = 2`
  /// the third poll sees it. Lets `waitCode` run with a zero interval.
  void addSmsAfter(int tzid, String text, int polls, {String? service}) {
    if (!_state.operations.containsKey(tzid) &&
        !_state.rents.containsKey(tzid)) {
      throw StateError('MockOnlineSim: no operation or rent $tzid');
    }
    _state.schedule(tzid, text, polls, service);
  }

  /// The next request (to [endpoint] only, e.g. `getNum.php`, when given)
  /// answers `{"response": code}`.
  void failNext(String code, {String? endpoint}) =>
      _state.failures.add(_Failure(code: code, endpoint: endpoint));

  /// The next request (to [endpoint] only, when given) fails at transport
  /// level: a non-JSON body with HTTP [status].
  void failNextTransport({int status = 502, String? endpoint}) =>
      _state.failures.add(_Failure(status: status, endpoint: endpoint));

  /// Sets the total balance, USD.
  void setBalance(double usd) => _state.balance = _toMills(usd);

  /// Total balance, USD, including the part frozen by open operations and
  /// unconfirmed rents (as `user.balance()` reports it).
  double balance() => _fromMills(_state.balance);

  /// Number operations, oldest first (snapshots).
  List<MockOperation> operations() =>
      [for (final op in _state.operations.values) op._copy()];

  /// Open rents, oldest first (snapshots).
  List<MockRent> rents() => [for (final r in _state.rents.values) r._copy()];

  /// Every request received, in order.
  List<MockRequest> get requests => List.unmodifiable(_state.requests);

  /// Back to the constructor's state: balance, no operations, rents, logs,
  /// schedules or failures.
  void reset() => _state.reset();

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final path = request.url.path;
    final at = path.indexOf('/api/');
    final body = request.body;
    final req = MockRequest(
      method: request.method.toUpperCase(),
      path: at < 0
          ? (path.startsWith('/') ? path.substring(1) : path)
          : path.substring(at + 5),
      query: Map.of(request.url.queryParameters),
      body: body == null ? null : jsonDecode(body),
    );
    final state = _state..requests.add(req);

    final failure = state.takeFailure(req.path);
    if (failure != null) {
      final code = failure.code;
      return code != null
          ? _json({'response': code})
          : _text(failure.status ?? 502, 'Mock transport failure');
    }

    final handler = _routes[req.path];
    if (handler == null) return _text(404, 'Not Found');
    // A wrong key is HTTP 456 (public endpoints check a sent key too); no key
    // at all is HTTP 200.
    final auth = _header(request.headers, 'authorization');
    if (auth != null && auth != 'Bearer ${state.apiKey}') {
      return _json({'response': 'ERROR_WRONG_KEY'}, 456);
    }
    if (auth == null && !_publicPaths.contains(req.path)) {
      return _json({'response': 'ERROR_WRONG_KEY'});
    }
    return _json(handler(state, req));
  }
}

String? _header(Map<String, String> headers, String name) {
  for (final MapEntry(:key, :value) in headers.entries) {
    if (key.toLowerCase() == name) return value;
  }
  return null;
}

TransportResponse _json(Object? body, [int status = 200]) =>
    TransportResponse(status, jsonEncode(body));

TransportResponse _text(int status, String body) =>
    TransportResponse(status, '<html><body>$status $body</body></html>');
