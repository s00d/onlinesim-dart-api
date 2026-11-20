import 'client.dart';
import 'errors.dart';
import 'json.dart';
import 'models/numbers.dart';

/// `waitCode` retries these error codes: the rate limit (HTTP 429), a
/// transient server error, too many concurrent requests.
const _retryable = {
  'TRY_AGAIN_LATER',
  'ERROR_UNDEFINED',
  'INTERVAL_CONCURRENT_REQUESTS_ERROR',
};

/// Numbers for receiving SMS: `client.numbers`.
final class NumbersApi {
  /// Internal: the client builds its sections.
  NumbersApi(this._request);

  final RequestFn _request;

  /// Price (USD) of one number of [service] in [country]; `null` when the
  /// country has no price for it.
  Future<double?> price(String service, {int country = 7}) async {
    final res = asMap(await _request(
      'getPrice.php',
      query: {'service': service, 'country': country},
    ));
    return asDouble(res['price']);
  }

  /// Orders a number. Returns the operation id (`tzid`). [reject] lists
  /// number prefixes to skip, e.g. `['4470', '4471']`.
  Future<int> get(
    String service, {
    int country = 7,
    Iterable<Object>? reject,
  }) async {
    // `number` is a presence flag on getNum: sent by getWithNumber only.
    final res = asMap(await _request(
      'getNum.php',
      query: {'service': service, 'country': country, 'reject': reject},
    ));
    return asInt(res['tzid']) ?? 0;
  }

  /// Orders a number and returns it right away with the operation id.
  Future<NumberOrder> getWithNumber(
    String service, {
    int country = 7,
    Iterable<Object>? reject,
  }) async {
    final res = await _request('getNum.php', query: {
      'service': service,
      'country': country,
      'reject': reject,
      'number': 1,
    });
    return NumberOrder.fromJson(asMap(res));
  }

  /// All operations of the account; `[]` when there are none.
  ///
  /// [messageToCode] (default) makes `msg` the code only, `false` the full
  /// SMS text. [msgList] fills [Operation.msgList] with every SMS.
  Future<List<Operation>> state({
    bool messageToCode = true,
    SortOrder orderBy = SortOrder.asc,
    bool msgList = false,
  }) async {
    try {
      final res = await _request('getState.php', query: {
        'message_to_code': messageToCode,
        'orderby': orderBy.name,
        'msg_list': msgList,
        'number': 1,
      });
      return objects(res, Operation.fromJson);
    } on ApiException catch (e) {
      if (e.code == 'ERROR_NO_OPERATIONS') return [];
      rethrow;
    }
  }

  /// One operation. Throws `ApiException('ERROR_NO_OPERATIONS')` when it does
  /// not exist (any more).
  Future<Operation> stateOne(
    int tzid, {
    bool messageToCode = true,
    bool msgList = false,
  }) async {
    final res = await _request('getState.php', query: {
      'tzid': tzid,
      'message_to_code': messageToCode,
      'msg_list': msgList,
      'number': 1,
    });
    final list = objects(res, Operation.fromJson);
    if (list.isEmpty) throw ApiException('ERROR_NO_OPERATIONS');
    return list.first;
  }

  /// Switches the operation to its next SMS and keeps it open. Throws
  /// `ApiException('ERROR_WRONG_TZID')` for a tzid not of this account.
  Future<void> next(int tzid) async {
    await _request('setOperationRevise.php', query: {'tzid': tzid});
  }

  /// Finishes the operation.
  Future<void> close(int tzid) async {
    await _request('setOperationOk.php', query: {'tzid': tzid});
  }

  /// Finishes the operation and reports the number as bad. After an SMS it
  /// throws `ApiException('0')` and changes nothing.
  Future<void> ban(int tzid) async {
    await _request('setOperationOk.php', query: {'tzid': tzid, 'ban': true});
  }

  /// Services, prices and stock of every country, keyed by country code.
  /// No key needed.
  Future<Map<int, CountryStat>> tariffs() async {
    final res =
        await _request('getNumbersStats.php', query: {'country': 'all'});
    return intKeyed(
      res,
      (v) => v is Map ? CountryStat.fromJson(asMap(v)) : null,
    );
  }

  /// Services, prices and stock of one country. No key needed.
  Future<CountryStat> tariffsOne({int country = 7}) async {
    final res =
        await _request('getNumbersStats.php', query: {'country': country});
    return CountryStat.fromJson(asMap(res));
  }

  /// Polls the operation every [interval] until an SMS code different from
  /// [since] arrives, then closes it (or calls [next] with [keepOpen]) and
  /// returns the code; the full SMS text with [fullMessage].
  ///
  /// A finished operation (`TZ_OVER_OK`, `ERROR_NO_ITEMS`) without a new code
  /// throws [ApiException] with that state as the code. Running out of
  /// [timeout] throws [WaitTimeoutException]. A [TransportException] and the
  /// transient [ApiException] codes `TRY_AGAIN_LATER` (the HTTP 429 rate
  /// limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR` are
  /// retried until the timeout; any other [ApiException] is thrown at once.
  /// [sleep] and [now] are injectable so tests run without real waiting.
  Future<String> waitCode(
    int tzid, {
    Duration interval = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 10),
    bool keepOpen = false,
    bool fullMessage = false,
    String? since,
    Future<void> Function(Duration duration)? sleep,
    DateTime Function()? now,
  }) async {
    final clock = now ?? DateTime.now;
    final pause = sleep ?? Future<void>.delayed;
    final deadline = clock().add(timeout);
    for (;;) {
      Operation? op;
      try {
        op = await stateOne(tzid, messageToCode: !fullMessage);
      } on TransportException {
        // transient: poll again
      } on ApiException catch (e) {
        if (!_retryable.contains(e.code)) rethrow;
      }

      if (op != null) {
        final msg = op.msg;
        if (msg != null && msg.isNotEmpty && msg != since) {
          await (keepOpen ? next(tzid) : close(tzid));
          return msg;
        }
        if (op.response == OperationStatus.overOk ||
            op.response == OperationStatus.errorNoItems) {
          throw ApiException(op.response);
        }
      }

      final left = deadline.difference(clock());
      if (left <= Duration.zero) {
        throw WaitTimeoutException(
          'No code for operation $tzid within ${timeout.inMilliseconds} ms',
        );
      }
      await pause(interval < left ? interval : left);
    }
  }
}
