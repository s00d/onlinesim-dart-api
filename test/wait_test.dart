import 'dart:convert';

import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// getState answers from [steps] (a partial operation, or a reply/exception
/// to use as is); close/next answer OK. `sleep` only moves the fake clock.
final class _Harness implements OnlineSimTransport {
  _Harness(List<Object> steps) : _steps = [...steps];

  final List<Object> _steps;
  final List<String> log = [];
  int clock = 0;

  late final OnlineSim client = OnlineSim(apiKey: 'k', transport: this);

  Future<void> sleep(Duration d) async {
    log.add('sleep ${d.inMilliseconds}');
    clock += d.inMilliseconds;
  }

  DateTime now() => DateTime.fromMillisecondsSinceEpoch(clock);

  Future<String> wait(
    int tzid, {
    Duration? interval,
    Duration? timeout,
    bool keepOpen = false,
    bool fullMessage = false,
    String? since,
  }) =>
      client.numbers.waitCode(
        tzid,
        interval: interval ?? const Duration(seconds: 5),
        timeout: timeout ?? const Duration(minutes: 10),
        keepOpen: keepOpen,
        fullMessage: fullMessage,
        since: since,
        sleep: sleep,
        now: now,
      );

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final q = request.url.queryParameters;
    final tzid = int.parse(q['tzid']!);
    switch (request.url.pathSegments.last) {
      case 'getState.php':
        log.add('state $tzid code=${q['message_to_code']}');
        final step =
            _steps.isEmpty ? const <String, Object?>{} : _steps.removeAt(0);
        if (step is TransportResponse) return step;
        if (step is! Map) throw step;
        return json([
          {'tzid': tzid, 'response': 'TZ_NUM_WAIT', ...step},
        ]);
      case 'setOperationOk.php':
        log.add('close $tzid');
      case 'setOperationRevise.php':
        log.add('next $tzid');
    }
    return TransportResponse(200, jsonEncode({'response': 1, 'tzid': tzid}));
  }
}

void main() {
  test('returns the code once it arrives and closes the operation', () async {
    final h = _Harness([
      <String, Object?>{},
      <String, Object?>{},
      {'response': 'TZ_NUM_ANSWER', 'msg': '195895'},
    ]);
    expect(await h.wait(7), '195895');
    expect(h.log, [
      'state 7 code=1',
      'sleep 5000',
      'state 7 code=1',
      'sleep 5000',
      'state 7 code=1',
      'close 7',
    ]);
  });

  test('keepOpen calls next; since skips the old code; fullMessage asks text',
      () async {
    final h = _Harness([
      {'msg': 'old'},
      {'msg': 'Your code is 2991'},
    ]);
    final code = await h.wait(
      7,
      keepOpen: true,
      since: 'old',
      fullMessage: true,
      interval: const Duration(seconds: 1),
    );
    expect(code, 'Your code is 2991');
    expect(h.log, [
      'state 7 code=0',
      'sleep 1000',
      'state 7 code=0',
      'next 7',
    ]);
  });

  for (final status in [
    OperationStatus.overOk,
    OperationStatus.errorNoItems,
  ]) {
    test('raises ApiException($status) at once for a finished operation',
        () async {
      final h = _Harness([
        {'response': status},
      ]);
      await expectLater(h.wait(7), throwsApi(status));
      expect(h.log, ['state 7 code=1']);
    });
  }

  test('a finished operation that still carries a new code returns it',
      () async {
    final h = _Harness([
      {'response': 'TZ_OVER_OK', 'msg': '1234'},
    ]);
    expect(await h.wait(7), '1234');
  });

  test('raises WaitTimeoutException; the last sleep is cut to the deadline',
      () async {
    final h = _Harness([]);
    await expectLater(
      h.wait(
        7,
        interval: const Duration(seconds: 4),
        timeout: const Duration(seconds: 10),
      ),
      throwsA(isA<WaitTimeoutException>()),
    );
    expect(h.log.where((l) => l.startsWith('sleep')), [
      'sleep 4000',
      'sleep 4000',
      'sleep 2000',
    ]);
    expect(h.log.where((l) => l.startsWith('state')), hasLength(4));
    expect(h.clock, 10000);
  });

  test('retries a transient TransportException', () async {
    final h = _Harness([
      raw('<html>502</html>', status: 502),
      {'msg': '42'},
    ]);
    expect(await h.wait(7), '42');
    expect(
        h.log, ['state 7 code=1', 'sleep 5000', 'state 7 code=1', 'close 7']);
  });

  test('retries a network error', () async {
    final h = _Harness([
      StateError('connection reset'),
      {'msg': '42'},
    ]);
    expect(await h.wait(7), '42');
  });

  test('raises any ApiException at once', () async {
    final h = _Harness([
      json({'response': 'ERROR_NO_OPERATIONS'}),
    ]);
    await expectLater(h.wait(7), throwsApi('ERROR_NO_OPERATIONS'));
    expect(h.log, ['state 7 code=1']);
  });
}
