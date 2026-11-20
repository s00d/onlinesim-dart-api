// MockOnlineSim through the real client: every endpoint, every control helper.
import 'dart:convert';

import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Future<void> _noSleep(Duration _) async {}

/// A raw request to the mock: (HTTP status, decoded body). [key] `null` sends
/// no `Authorization` header.
Future<(int, Object?)> _raw(
  MockOnlineSim mock,
  String pathAndQuery, {
  String? key = 'mock-key',
}) async {
  final res = await mock.send(TransportRequest(
    method: 'GET',
    url: Uri.parse('https://x.test/api/$pathAndQuery'),
    headers: {if (key != null) 'Authorization': 'Bearer $key'},
  ));
  return (res.status, jsonDecode(res.body));
}

void main() {
  group('auth and transport', () {
    test('a wrong key is HTTP 456, a missing key HTTP 200; both ApiException',
        () async {
      final mock = MockOnlineSim();
      for (final key in ['nope', '']) {
        await expectLater(
          mock.client(apiKey: key).user.balance(),
          throwsApi('ERROR_WRONG_KEY'),
        );
      }
      final (status, body) = await _raw(mock, 'getBalance.php', key: null);
      expect(status, 200);
      expect(body, {'response': 'ERROR_WRONG_KEY'});
      expect((await _raw(mock, 'getBalance.php', key: 'nope')).$1, 456);
    });

    test('tariffs and free numbers need no key, a sent wrong key is 456',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client(apiKey: '');
      expect((await client.numbers.tariffsOne(country: 44)).code, 44);
      expect((await client.rent.tariffsOne(country: 7)).code, 7);
      expect((await client.free.list()).messages.country, 44);
      await expectLater(
        mock.client(apiKey: 'nope').free.list(),
        throwsApi('ERROR_WRONG_KEY'),
      );
    });

    test('works as the transport of a client built by hand, any base URL',
        () async {
      final mock = MockOnlineSim(apiKey: 'k', balance: 5);
      final client = OnlineSim(apiKey: 'k', transport: mock);
      final b = await client.user.balance();
      expect([b.balance, b.zbalance, b.income], [5, 0, 0]);
      final req = mock.requests.single;
      expect(req.method, 'GET');
      expect(req.path, 'getBalance.php');
      expect(req.query, {'income': '1', 'lang': 'en'});
      expect(req.body, isNull);
    });

    test('an unknown endpoint is a non-JSON 404', () async {
      final res = await MockOnlineSim().send(TransportRequest(
        method: 'GET',
        url: Uri.parse('https://x.test/api/nope.php'),
        headers: const {},
      ));
      expect(res.status, 404);
    });
  });

  group('numbers', () {
    test('price: number, null for unknown service, UNDEFINED_COUNTRY',
        () async {
      final client = MockOnlineSim().client();
      expect(await client.numbers.price('telegram', country: 7), 1.2);
      expect(await client.numbers.price('nope', country: 7), isNull);
      await expectLater(
        client.numbers.price('google', country: 999),
        throwsApi('UNDEFINED_COUNTRY'),
      );
    });

    test('get freezes the price; numbers are deterministic; getWithNumber',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      expect(await client.numbers.get('google', country: 44), 1);
      final order = await client.numbers.getWithNumber('vkcom');
      expect(
        [order.tzid, order.number, order.country, order.time, order.service],
        [2, '+7900000002', 7, 1200, 'vkcom'],
      );
      expect(
        [order.title, order.guardIntervalRemainingSeconds],
        ['vkcom', 0],
      );
      expect(mock.requests.map((r) => r.query['number']), [null, '1']);
      final b = await client.user.balance();
      expect([b.balance, b.zbalance, b.income], [100, 0.7, 0]);
      final (_, raw) =
          await _raw(MockOnlineSim(), 'getNum.php?service=vkcom&number=1');
      expect(raw, containsPair('response_text', 'Waiting for SMS'));
      expect(
        mock.operations().map((o) => [o.tzid, o.number, o.status]),
        [
          [1, '+44900000001', 'TZ_NUM_WAIT'],
          [2, '+7900000002', 'TZ_NUM_WAIT'],
        ],
      );
    });

    test('get errors: unknown country/service, low balance, reject', () async {
      final mock = MockOnlineSim(balance: 0.25);
      final client = mock.client();
      await expectLater(
        client.numbers.get('google', country: 999),
        throwsApi('UNDEFINED_COUNTRY'),
      );
      await expectLater(
        client.numbers.get('nope', country: 7),
        throwsApi('ERROR_NO_SERVICE'),
      );
      await expectLater(
        client.numbers.get('google', country: 7),
        throwsApi('WARNING_LOW_BALANCE'),
      );
      await expectLater(
        client.numbers.get('google', country: 44, reject: ['4490', '7']),
        throwsA(isA<NoNumberException>()),
      );
      expect(mock.requests.last.query['reject'], '4490,7');
      // a non-matching reject passes; the rejected attempt used no number
      final order = await client.numbers
          .getWithNumber('google', country: 44, reject: ['4480']);
      expect(order.number, '+44900000001');
      // 0.25 - 0.2 frozen = 0.05 available
      await expectLater(
        client.numbers.get('google', country: 44),
        throwsApi('WARNING_LOW_BALANCE'),
      );
    });

    test('state: [] without operations, list/one, WAIT → ANSWER → OVER_OK',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      expect(await client.numbers.state(), isEmpty);
      final a = await client.numbers.get('google', country: 44);
      final b = await client.numbers.get('vkcom', country: 7);
      final one = await client.numbers.stateOne(a);
      expect(one.tzid, a);
      expect(one.response, 'TZ_NUM_WAIT');
      expect(one.number, '+44900000001');
      expect(one.sum, 0.2);
      expect(one.guardIntervalRemainingSeconds, 0);
      expect(one.msg, isNull);

      mock.addSms(a, 'Your Google code is G-123 456. Do not share it.');
      final answered = await client.numbers.stateOne(a);
      expect(answered.response, 'TZ_NUM_ANSWER');
      expect(answered.msg, '123456');
      expect(
        (await client.numbers.stateOne(a, messageToCode: false)).msg,
        'Your Google code is G-123 456. Do not share it.',
      );
      expect(
        (await client.numbers.state(orderBy: SortOrder.desc))
            .map((o) => o.tzid),
        [b, a],
      );

      await client.numbers.close(a);
      final closed = await client.numbers.stateOne(a);
      expect(closed.response, 'TZ_OVER_OK');
      expect(closed.time, 0);
      await expectLater(
        client.numbers.stateOne(999),
        throwsApi('ERROR_NO_OPERATIONS'),
      );
    });

    test('no code → full text; next switches SMS; msgList lists all', () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      final tzid = await client.numbers.get('telegram');
      mock.addSms(tzid, 'Welcome!', service: 'telegram');
      expect((await client.numbers.stateOne(tzid)).msg, 'Welcome!');
      await client.numbers.next(tzid);
      final waiting = await client.numbers.stateOne(tzid);
      expect(waiting.response, 'TZ_NUM_WAIT');
      expect(waiting.msg, isNull);
      mock.addSms(tzid, 'code 98765');
      expect((await client.numbers.stateOne(tzid)).msg, '98765');
      final all = (await client.numbers.stateOne(tzid, msgList: true)).msgList!;
      expect(all.map((s) => [s.service, s.msg]), [
        ['telegram', 'Welcome!'],
        ['telegram', '98765'],
      ]);
      expect(
        mock.requests.where((r) => r.path == 'setOperationRevise.php'),
        hasLength(1),
      );
    });

    test('next: {"tzid":"N","response":"1"}; ERROR_WRONG_TZID, ERROR_NO_TZID',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      final tzid = await client.numbers.get('google', country: 44);
      final (status, body) =
          await _raw(mock, 'setOperationRevise.php?tzid=$tzid');
      expect(status, 200);
      expect(body, {'tzid': '$tzid', 'response': '1'});
      await expectLater(
        client.numbers.next(424242),
        throwsApi('ERROR_WRONG_TZID'),
      );
      await expectLater(client.numbers.next(0), throwsApi('ERROR_NO_TZID'));
      await expectLater(client.numbers.close(0), throwsApi('ERROR_NO_TZID'));
    });

    test('close after SMS spends, without refunds; ban after SMS answers "0"',
        () async {
      final mock = MockOnlineSim(balance: 10);
      final client = mock.client();
      final paid = await client.numbers.get('telegram');
      final empty = await client.numbers.get('telegram');
      mock.addSms(paid, '1111');
      await expectLater(client.numbers.ban(paid), throwsApi('0'));
      await client.numbers.close(paid);
      await client.numbers.close(empty);
      final b = await client.user.balance();
      expect([b.balance, b.zbalance], [8.8, 0]);
      expect(mock.balance(), 8.8);
      await expectLater(
        client.numbers.close(paid),
        throwsApi('ERROR_WRONG_TZID'),
      );
      await expectLater(
        client.numbers.close(999),
        throwsApi('ERROR_WRONG_TZID'),
      );
      final banned = await client.numbers.get('google');
      await client.numbers.ban(banned);
      expect(
        mock.operations().firstWhere((o) => o.tzid == banned).status,
        'TZ_OVER_OK',
      );
    });

    test('guardInterval: an operation without SMS cannot be closed', () async {
      final mock = MockOnlineSim(guardInterval: 120);
      final client = mock.client();
      final tzid = await client.numbers.get('google');
      expect(
        (await client.numbers.stateOne(tzid)).guardIntervalRemainingSeconds,
        120,
      );
      await expectLater(
        client.numbers.close(tzid),
        throwsApi('NO_COMPLETE_TZID'),
      );
      mock.addSms(tzid, '5555');
      expect(
        (await client.numbers.stateOne(tzid)).guardIntervalRemainingSeconds,
        0,
      );
      await client.numbers.close(tzid);
    });

    test('waitCode with addSmsAfter and a zero interval: no real waiting',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      final tzid = await client.numbers.get('google', country: 44);
      mock.addSmsAfter(tzid, 'Your code: 4321', 2);
      expect(
        await client.numbers.waitCode(tzid, interval: Duration.zero),
        '4321',
      );
      expect(mock.requests.map((r) => r.path), [
        'getNum.php',
        'getState.php',
        'getState.php',
        'getState.php',
        'setOperationOk.php',
      ]);
      expect(mock.operations().single.status, 'TZ_OVER_OK');
    });

    test('waitCode keepOpen + since waits for the next SMS; list polls count',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      final tzid = await client.numbers.get('google', country: 44);
      mock.addSmsAfter(tzid, '1111', 0);
      final first = await client.numbers.waitCode(
        tzid,
        interval: Duration.zero,
        sleep: _noSleep,
        keepOpen: true,
      );
      expect(first, '1111');
      mock.addSmsAfter(tzid, '2222', 1);
      await client.numbers.state(); // one poll of every operation
      expect(
        await client.numbers.waitCode(
          tzid,
          interval: Duration.zero,
          sleep: _noSleep,
          since: first,
        ),
        '2222',
      );
    });

    test('tariffs from the prices: service_<slug>, count 100; NO_COUNTRY',
        () async {
      final client = MockOnlineSim().client();
      final all = await client.numbers.tariffs();
      expect(all.keys, [7, 44]);
      final vk = all[44]!.services['service_vkcom']!;
      expect(
        [vk.count, vk.popular, vk.code, vk.price, vk.id, vk.service, vk.slug],
        [100, false, 44, 0.36, 2, 'vkcom', 'vkcom'],
      );
      await expectLater(
        client.numbers.tariffsOne(country: 1),
        throwsApi('NO_COUNTRY'),
      );
      final empty = MockOnlineSim(prices: {1: {}}).client();
      // `[]` on the wire
      expect((await empty.numbers.tariffsOne(country: 1)).services, isEmpty);
    });
  });

  group('rent', () {
    test('get reserves, the first SMS confirms and charges; extend; close',
        () async {
      final mock = MockOnlineSim(balance: 10);
      final client = mock.client();
      final rent = await client.rent.get(country: 7, days: 3);
      expect(
        [
          rent.tzid,
          rent.number,
          rent.status,
          rent.checked,
          rent.sum,
          rent.days,
          rent.time,
          rent.timeSeconds,
          rent.daysAutoextend,
          rent.extension,
          rent.guardIntervalRemainingSeconds,
          rent.messages,
        ],
        [1, '900000001', 0, false, 2.5, 0, 20, 1200, 3, 1, 0, isEmpty],
      );
      expect(rent.extend, {1: 1, 3: 2.5, 7: 5});
      // reserved: the total balance stays, the price is frozen
      expect(mock.balance(), 10);
      var b = await client.user.balance();
      expect([b.balance, b.zbalance, b.available], [10, 2.5, 7.5]);
      await expectLater(
        client.rent.extend(rent.tzid), // not confirmed yet
        throwsApi('TRY_AGAIN_LATER'),
      );

      mock.addSms(rent.tzid, 'Bank: 777 888', service: 'bank');
      mock.addSms(rent.tzid, 'no code here');
      final state = await client.rent.stateOne(rent.tzid);
      expect(
        [state.status, state.checked, state.days, state.time],
        [1, true, 3, 3 * 1440],
      );
      expect(state.timeSeconds, 3 * 86400);
      expect(state.messages.map((m) => [m.service, m.code]), [
        ['other', ''],
        ['bank', '777888'],
      ]); // newest first
      expect(mock.balance(), 7.5);
      b = await client.user.balance();
      expect([b.balance, b.zbalance], [7.5, 0]);

      final extended = await client.rent.extend(rent.tzid, days: 1);
      expect(
        [extended.days, extended.daysAutoextend, extended.sum],
        [4, 3, 3.5],
      );
      expect(mock.balance(), 6.5);
      expect(mock.rents().first.days, 4);
      expect(mock.rents().first.initialDays, 3);
      await expectLater(
        client.rent.extend(rent.tzid, days: 2), // unknown period
        throwsApi('TRY_AGAIN_LATER'),
      );
      await expectLater(
        client.rent.extend(999), // unknown tzid
        throwsApi('TRY_AGAIN_LATER'),
      );

      final fixed = await client.rent.get(extension: false);
      mock.addSms(fixed.tzid, '1234');
      final fixedState = await client.rent.stateOne(fixed.tzid);
      expect(fixedState.extension, 0);
      expect(fixedState.extend, isEmpty);
      await expectLater(
        client.rent.extend(fixed.tzid),
        throwsApi('TRY_AGAIN_LATER'),
      );
      expect(
        (await client.rent.state()).map((r) => r.tzid),
        [rent.tzid, fixed.tzid],
      );

      await client.rent.close(fixed.tzid); // confirmed: no refund
      expect(mock.balance(), 5.5);
      expect(mock.rents().map((r) => r.tzid), [rent.tzid]);
      await expectLater(
        client.rent.stateOne(fixed.tzid),
        throwsApi('ERROR_NO_OPERATIONS'),
      );
      await expectLater(
        client.rent.close(fixed.tzid),
        throwsApi('ERROR_NO_OPERATIONS'),
      );
    });

    test('sum: a number in getRentNum, a decimal string in getRentState',
        () async {
      final mock = MockOnlineSim();
      final (_, got) = await _raw(mock, 'rent/getRentNum.php?days=3');
      expect(((got! as Map)['item'] as Map)['sum'], 2.5);
      final (_, listed) = await _raw(mock, 'rent/getRentState.php');
      expect((((listed! as Map)['list'] as List).first as Map)['sum'], '2.50');
    });

    test('unconfirmed rent: close releases; notify SMS is code 0; guard',
        () async {
      final mock = MockOnlineSim(balance: 10, guardInterval: 120);
      final client = mock.client();
      final rent = await client.rent.get(days: 3);
      expect(rent.guardIntervalRemainingSeconds, 120);
      await expectLater(
        client.rent.close(rent.tzid),
        throwsApi('NO_COMPLETE_TZID'),
      );
      mock.addSms(
        rent.tzid,
        'Messages from this sender are not accepted',
        service: 'notify',
      );
      final (_, raw) = await _raw(mock, 'rent/getRentState.php');
      final item = ((raw! as Map)['list'] as List).first as Map;
      expect((item['messages'] as List).first, containsPair('code', 0));
      final state = await client.rent.stateOne(rent.tzid);
      expect(
        [state.status, state.checked, state.guardIntervalRemainingSeconds],
        [0, false, 0],
      );
      expect(
        [state.messages.first.service, state.messages.first.code],
        ['notify', '0'],
      );
      await client.rent.close(rent.tzid);
      expect(mock.balance(), 10); // released, nothing charged
      final b = await client.user.balance();
      expect([b.balance, b.zbalance], [10, 0]);
    });

    test('rent errors: unknown country, unknown days, low balance', () async {
      final client = MockOnlineSim(balance: 1.5).client();
      await expectLater(
        client.rent.get(country: 44),
        throwsApi('UNDEFINED_COUNTRY'),
      );
      await expectLater(client.rent.get(days: 2), throwsApi('UNDEFINED_DAYS'));
      await expectLater(
        client.rent.get(days: 3),
        throwsApi('WARNING_LOW_BALANCE'),
      );
    });

    test('addSmsAfter works for rents; tariffs; [] for an unknown country',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      final tzid = (await client.rent.get()).tzid;
      mock.addSmsAfter(tzid, '6060', 1);
      expect((await client.rent.stateOne(tzid)).messages, isEmpty);
      final listed = (await client.rent.state()).first;
      expect(listed.status, 1);
      final sms = listed.messages.first;
      expect([sms.code, sms.service], ['6060', 'other']);
      final tariffs = await client.rent.tariffs();
      expect(tariffs.keys, [7]);
      final ru = tariffs[7]!;
      expect(
        [ru.code, ru.enabled, ru.name, ru.isNew, ru.position, ru.extend],
        [7, true, 'russia', false, 7, 1],
      );
      expect(ru.days, {1: 1, 3: 2.5, 7: 5});
      expect(ru.count, {1: 100, 3: 100, 7: 100});
      expect(ru.extCounts, {1: 100, 3: 100, 7: 100});
      expect(ru.confirm, isFalse);
      await expectLater(
        client.rent.tariffsOne(country: 44),
        throwsApi('NO_COUNTRY'),
      );
    });
  });

  group('user and free', () {
    test('profile, webhook set/validate/clear, logs recorded on SMS', () async {
      final mock = MockOnlineSim(apiKey: 'secret');
      final client = mock.client();
      final profile = await client.user.profile();
      expect([
        profile.id,
        profile.apikey,
        profile.webhookUrl
      ], [
        1,
        'secret',
        null,
      ]);
      await expectLater(
        client.user.setWebhookUrl('not a url'),
        throwsApi('VALIDATION_ERROR', 'The webhook url must be a valid URL.'),
      );
      await client.user.setWebhookUrl('ftp://x'); // any scheme://… URL
      await client.user.setWebhookUrl('https://example.com/hook');
      final req = mock.requests.last;
      expect([req.method, req.path], ['POST', 'profile.php']);
      expect(req.body, {
        'profile': {'webhook_url': 'https://example.com/hook'},
      });
      expect(
        (await client.user.profile()).webhookUrl,
        'https://example.com/hook',
      );

      final tzid = await client.numbers.get('google', country: 44);
      mock.addSms(tzid, 'code 1234');
      final rent = await client.rent.get();
      mock.addSms(rent.tzid, 'code 5678');
      mock.addSms(rent.tzid, 'no code');
      final logs = await client.user.webhookLogs();
      expect([logs.total, logs.currentPage, logs.perPage], [3, 1, 10]);
      expect(
        logs.data.map((l) => [l.type, l.params.operationId, l.params.code]),
        [
          [WebhookType.rentSms, rent.tzid, ''],
          [WebhookType.rentSms, rent.tzid, '5678'],
          [WebhookType.receivingSms, tzid, '1234'],
        ],
      );
      // activation: +number, seconds left, order time;
      // rent: digits without +, minutes left, SMS time
      final activation = logs.data[2].params;
      expect(
        [activation.number, activation.timeLeft, activation.timeStart],
        ['+44900000001', 1200, '2026-01-01 00:00:01'],
      );
      final rentLog = logs.data[1].params;
      expect(
        [rentLog.number, rentLog.timeLeft, rentLog.timeStart],
        ['7900000002', 1440, '2026-01-01 00:00:03'],
      );

      await client.user.clearWebhookUrl();
      expect((await client.user.profile()).webhookUrl, isNull);
    });

    test('balance includes the frozen part; payment history is empty',
        () async {
      final mock = MockOnlineSim(balance: 3);
      final client = mock.client();
      await client.numbers.get('telegram');
      final b = await client.user.balance();
      expect([b.balance, b.zbalance, b.income], [3, 1.2, 0]);
      final history = await client.user.paymentHistory();
      expect(history.paylist, isEmpty);
      expect(history.domains, ['onlinesim.io']);
      final (_, raw) = await _raw(mock, 'getPaymentHistory.php');
      expect(raw, containsPair('forms', {'1': 'Card'}));
      expect(
        raw,
        containsPair('buttons', {
          'USD': [5, 10, 20],
        }),
      );
      expect(history.orders.data, isEmpty);
      expect(history.orders.total, 0);
      expect(history.orders.currentPage, 1);
    });

    test('free list: countries, numbers by short number, selected messages',
        () async {
      final client = MockOnlineSim().client();
      final uk = await client.free.list();
      expect(uk.countries.map((c) => c.country), [44, 7]);
      expect(uk.numbers.keys, ['7459608320']);
      expect(
        [
          uk.messages.number,
          uk.messages.country,
          uk.messages.total,
          uk.messages.perPage,
        ],
        ['7459608320', 44, 2, 10],
      );
      expect(uk.messages.data.first.code, '195895');
      expect(uk.messages.data.first.createdAt, '2026-01-01T00:00:00.000000Z');
      // count clamped to 10..500
      expect((await client.free.list(count: 0)).messages.perPage, 10);
      expect((await client.free.list(count: 9999)).messages.perPage, 500);
      // unknown country → the first one
      expect((await client.free.list(country: 999)).messages.country, 44);
      final (_, raw) = await _raw(MockOnlineSim(), 'getFreeList', key: null);
      expect(raw, containsPair('content', null));
      expect(raw, containsPair('ignore', isA<String>()));
      final ru = await client.free.list(country: 7);
      expect(ru.messages.data.first.code, '51423');
      expect(ru.messages.data.first.myNumber, '9001234567');
    });
  });

  group('control API', () {
    test('failNext answers an error code once, optionally per endpoint',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      mock.failNext('NO_NUMBER', endpoint: 'getNum.php');
      expect((await client.user.balance()).balance, 100); // other endpoint
      await expectLater(
        client.numbers.get('google'),
        throwsA(isA<NoNumberException>()),
      );
      expect(await client.numbers.get('google'), 1);
      mock.failNext('TRY_AGAIN_LATER');
      await expectLater(client.user.profile(), throwsApi('TRY_AGAIN_LATER'));
    });

    test('failNextTransport fails once with non-JSON; waitCode retries it',
        () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      mock.failNextTransport();
      await expectLater(
        client.user.balance(),
        throwsA(
          isA<TransportException>().having((e) => e.status, 'status', 502),
        ),
      );

      final tzid = await client.numbers.get('google');
      mock
        ..addSms(tzid, '3030')
        ..failNextTransport(status: 503, endpoint: 'getState.php');
      expect(
        await client.numbers.waitCode(
          tzid,
          interval: Duration.zero,
          sleep: _noSleep,
        ),
        '3030',
      );
    });

    test('addSms/addSmsAfter reject unknown ids; setBalance; requests; reset',
        () async {
      final mock = MockOnlineSim(balance: 1);
      final client = mock.client(lang: 'ru');
      expect(
        () => mock.addSms(5, 'x'),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('no open operation or rent 5'))),
      );
      expect(
        () => mock.addSmsAfter(5, 'x', 1),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('no operation or rent 5'))),
      );
      mock.setBalance(50);
      expect(mock.balance(), 50);
      final tzid = await client.numbers.get('telegram');
      await client.numbers.close(tzid);
      expect(() => mock.addSms(tzid, 'late'), throwsStateError); // closed
      final first = mock.requests.first;
      expect([first.method, first.path], ['GET', 'getNum.php']);
      expect(
        first.query,
        {'service': 'telegram', 'country': '7', 'lang': 'ru'},
      );

      mock
        ..failNext('NO_NUMBER')
        ..reset();
      expect(mock.balance(), 1);
      expect(mock.operations(), isEmpty);
      expect(mock.rents(), isEmpty);
      expect(mock.requests, isEmpty);
      // ids restart, failure queue cleared
      expect(await client.numbers.get('google', country: 44), 1);
    });

    test('operations() returns snapshots', () async {
      final mock = MockOnlineSim();
      final client = mock.client();
      final tzid = await client.numbers.get('google');
      final before = mock.operations().single;
      await client.numbers.close(tzid);
      expect(before.status, 'TZ_NUM_WAIT');
      expect(mock.operations().single.status, 'TZ_OVER_OK');
      expect(before.messages.clear, throwsUnsupportedError);
    });
  });
}
