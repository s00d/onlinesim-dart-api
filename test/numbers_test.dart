import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('price', () async {
    final (client, t) = fakeClient([
      json({'response': '1', 'price': 0.36}),
    ]);
    expect(await client.numbers.price('vkcom', country: 44), 0.36);
    expect(t.last.url.path, '/api/getPrice.php');
    expect(query(t.last), {'service': 'vkcom', 'country': '44'});
  });

  test('price is null when the server has none', () async {
    final (client, _) = fakeClient([
      json({'response': '1', 'price': null}),
    ]);
    expect(await client.numbers.price('vkcom'), isNull);
  });

  test('get sends no `number` flag and reject as a comma list', () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'tzid': 1520}),
    ]);
    expect(
      await client.numbers.get('google', country: 44, reject: ['4470', 4471]),
      1520,
    );
    expect(t.last.url.path, '/api/getNum.php');
    expect(
      query(t.last),
      {'service': 'google', 'country': '44', 'reject': '4470,4471'},
    );
  });

  test('get defaults to country 7 and omits an empty reject', () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'tzid': 1}),
    ]);
    await client.numbers.get('google', reject: []);
    expect(query(t.last), {'service': 'google', 'country': '7'});
  });

  test('getWithNumber sends number=1 and returns the order', () async {
    final (client, t) = fakeClient([
      json({
        'response': 1,
        'tzid': 1520,
        'number': '+447459608320',
        'country': 44,
        'time': 1200,
        'service': 'google',
      }),
    ]);
    final order = await client.numbers.getWithNumber('google', country: 44);
    expect(
      [order.tzid, order.number, order.country, order.time, order.service],
      [1520, '+447459608320', 44, 1200, 'google'],
    );
    expect(
      query(t.last),
      {'service': 'google', 'country': '44', 'number': '1'},
    );
  });

  test('state sends booleans as 1/0, lowercase orderby and the number flag',
      () async {
    final (client, t) = fakeClient([json(fixture('getState'))]);
    final ops =
        await client.numbers.state(orderBy: SortOrder.desc, msgList: true);
    expect(t.last.url.path, '/api/getState.php');
    expect(query(t.last), {
      'message_to_code': '1',
      'orderby': 'desc',
      'msg_list': '1',
      'number': '1',
    });
    expect(ops, hasLength(2));
    final first = ops[0];
    expect(first.tzid, 594);
    expect(first.response, OperationStatus.numAnswer);
    expect(first.msg, '195895');
    expect(first.number, '+77781746533');
    expect(first.sum, 0.3);
    expect(first.guardIntervalRemainingSeconds, 0);
    expect(ops[1].msg, isNull);
    expect(ops[1].guardIntervalRemainingSeconds, 120);
  });

  test('state defaults', () async {
    final (client, t) = fakeClient([json(<Object?>[])]);
    await client.numbers.state();
    expect(query(t.last), {
      'message_to_code': '1',
      'orderby': 'asc',
      'msg_list': '0',
      'number': '1',
    });
  });

  test('state returns [] on ERROR_NO_OPERATIONS', () async {
    final (client, _) = fakeClient([
      json({'response': 'ERROR_NO_OPERATIONS'}),
    ]);
    expect(await client.numbers.state(), isEmpty);
  });

  test('state parses msg as a list with msgList', () async {
    final (client, _) = fakeClient([
      json([
        {
          'tzid': 1,
          'response': 'TZ_NUM_ANSWER',
          'msg': [
            {'service': 'vk', 'msg': '1234'},
          ],
        },
      ]),
    ]);
    final op = (await client.numbers.state(msgList: true)).single;
    expect(op.msg, isNull);
    expect(op.msgList!.single.msg, '1234');
    expect(op.msgList!.single.service, 'vk');
  });

  test('stateOne returns the operation', () async {
    final ops = fixture('getState')! as List;
    final (client, t) = fakeClient([
      json([ops[0]]),
    ]);
    final op = await client.numbers.stateOne(594, messageToCode: false);
    expect(op.tzid, 594);
    expect(query(t.last), {
      'tzid': '594',
      'message_to_code': '0',
      'msg_list': '0',
      'number': '1',
    });
  });

  test('stateOne raises ERROR_NO_OPERATIONS', () async {
    final (client, _) = fakeClient([
      json({'response': 'ERROR_NO_OPERATIONS'}),
      json(<Object?>[]),
    ]);
    await expectLater(
      client.numbers.stateOne(1),
      throwsApi('ERROR_NO_OPERATIONS'),
    );
    await expectLater(
      client.numbers.stateOne(1),
      throwsApi('ERROR_NO_OPERATIONS'),
    );
  });

  test('next', () async {
    final (client, t) = fakeClient([
      json({'response': '1', 'tzid': '1520'}),
    ]);
    await client.numbers.next(1520);
    expect(t.last.url.path, '/api/setOperationRevise.php');
    expect(query(t.last), {'tzid': '1520'});
  });

  test('close', () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'tzid': 1520}),
    ]);
    await client.numbers.close(1520);
    expect(t.last.url.path, '/api/setOperationOk.php');
    expect(query(t.last), {'tzid': '1520'});
  });

  test('ban', () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'tzid': 1520}),
    ]);
    await client.numbers.ban(1520);
    expect(query(t.last), {'tzid': '1520', 'ban': '1'});
  });

  test('close surfaces NO_COMPLETE_TZID', () async {
    final (client, _) = fakeClient([
      json({'response': 'NO_COMPLETE_TZID'}),
    ]);
    await expectLater(client.numbers.close(1), throwsApi('NO_COMPLETE_TZID'));
  });

  test('tariffs requests country=all and normalises [] services', () async {
    final uk = fixtureMap('getNumbersStats_44');
    final (client, t) = fakeClient([
      json({
        '44': uk,
        '7': {...uk, 'code': 7, 'services': <Object?>[]},
      }),
    ]);
    final all = await client.numbers.tariffs();
    expect(t.last.url.path, '/api/getNumbersStats.php');
    expect(query(t.last), {'country': 'all'});
    expect(all.keys, [44, 7]);
    expect(all[44]!.services['service_vkcom']!.slug, 'vkcom');
    expect(all[7]!.services, isEmpty);
  });

  test('tariffsOne', () async {
    final (client, t) = fakeClient([json(fixture('getNumbersStats_44'))]);
    final uk = await client.numbers.tariffsOne(country: 44);
    expect(query(t.last), {'country': '44'});
    expect(uk.code, 44);
    expect(uk.name, 'united_kingdom');
    expect(uk.localeName, 'United Kingdom');
    expect(uk.other, 0.63);
    expect(uk.enabled, isTrue);
    final vk = uk.services['service_vkcom']!;
    expect(
      [vk.count, vk.popular, vk.code, vk.price, vk.id, vk.service, vk.slug],
      [363, false, 44, 0.36, 1, 'VK', 'vkcom'],
    );
  });

  test('tariffsOne: other=false and count "?" become null', () async {
    final (client, _) = fakeClient([
      json({
        'name': 'x',
        'code': 1,
        'other': false,
        'services': {
          'service_a': {'count': '?', 'slug': 'a', 'price': 1},
        },
      }),
    ]);
    final c = await client.numbers.tariffsOne(country: 1);
    expect(c.other, isNull);
    expect(c.services['service_a']!.count, isNull);
  });

  test('tariffsOne raises NO_COUNTRY', () async {
    final (client, _) = fakeClient([
      json({'response': 'NO_COUNTRY'}),
    ]);
    await expectLater(
      client.numbers.tariffsOne(country: 999),
      throwsApi('NO_COUNTRY'),
    );
  });
}
