import 'package:test/test.dart';

import 'helpers.dart';

List<Object?> _list() => fixtureMap('rent_getRentState')['list']! as List;

const _detail = {'pagination': '0', 'number': '1'};

void main() {
  test('get sends extension explicitly, pagination=0 and number; parses sum',
      () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'item': _list()[0]}),
    ]);
    final rent = await client.rent.get(country: 7, days: 3);
    expect(t.last.url.path, '/api/rent/getRentNum.php');
    expect(
      query(t.last),
      {'country': '7', 'days': '3', 'extension': '1', ..._detail},
    );
    expect(rent.tzid, 430);
    expect(rent.sum, 5.14);
    expect(rent.extend, {1: 14.7, 3: 25.3, 7: 51});
    expect(rent.messages.single.code, '195895');
    expect(rent.messages.single.createdAt, '2026-11-19 10:00:00');
    expect(rent.number, '781746533');
    expect(rent.timeSeconds, 18034680);
    expect(rent.extension, 1);
    expect(rent.dayExtend, 4.7);
    expect(rent.checked, isTrue);
  });

  test('decodes sum as a number or a string; notify SMS code 0 → "0"',
      () async {
    final item = {
      ...(_list()[0]! as Map).cast<String, Object?>(),
      'status': 0,
      'checked': false,
      'sum': 1.5,
      'messages': [
        {
          'id': 2,
          'service': 'notify',
          'text': 'Messages from this sender are not accepted',
          'code': 0,
          'created_at': '2026-11-19 10:01:12',
        },
        {
          'id': 1,
          'service': 'Google',
          'text': 'G-070051',
          'code': '070051',
          'created_at': '2026-11-19 10:01:00',
        },
      ],
    };
    final (client, _) = fakeClient([
      json({'response': 1, 'item': item}),
      json({
        'response': 1,
        'list': [
          {...item, 'sum': '2.40'},
        ],
      }),
    ]);
    final rent = await client.rent.get(country: 7, days: 3);
    expect([rent.status, rent.checked, rent.sum], [0, false, 1.5]);
    expect(rent.messages.map((m) => m.code), ['0', '070051']);
    expect((await client.rent.stateOne(rent.tzid)).sum, 2.4);
  });

  test('get with extension: false sends extension=0', () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'item': _list()[1]}),
    ]);
    await client.rent.get(extension: false);
    expect(query(t.last)['extension'], '0');
  });

  test('state normalises sum and the [] extend map', () async {
    final (client, t) = fakeClient([json(fixture('rent_getRentState'))]);
    final list = await client.rent.state();
    expect(t.last.url.path, '/api/rent/getRentState.php');
    expect(query(t.last), _detail);
    expect(list.map((r) => r.sum), [5.14, 0]);
    expect(list[1].extend, isEmpty);
    expect(list[1].messages, isEmpty);
  });

  test('stateOne', () async {
    final (client, t) = fakeClient([
      json({
        'response': 1,
        'list': [_list()[0]],
      }),
    ]);
    final rent = await client.rent.stateOne(430);
    expect(rent.tzid, 430);
    expect(rent.sum, 5.14);
    expect(query(t.last), {'tzid': '430', ..._detail});
  });

  test('stateOne raises ERROR_NO_OPERATIONS for an empty list', () async {
    final (client, _) = fakeClient([
      json({'response': 1, 'list': <Object?>[]}),
    ]);
    await expectLater(
      client.rent.stateOne(1),
      throwsApi('ERROR_NO_OPERATIONS'),
    );
  });

  test('extend', () async {
    final (client, t) = fakeClient([
      json({'response': 1, 'item': _list()[0]}),
    ]);
    expect((await client.rent.extend(430, days: 3)).tzid, 430);
    expect(t.last.url.path, '/api/rent/extendRentState.php');
    expect(query(t.last), {'tzid': '430', 'days': '3', ..._detail});
  });

  test('tariffs', () async {
    final (client, t) = fakeClient([json(fixture('rent_tariffsRent'))]);
    final all = await client.rent.tariffs();
    expect(t.last.url.path, '/api/rent/tariffsRent.php');
    expect(query(t.last), isEmpty);
    expect(all.keys, [7, 380]);
    expect(all[7]!.days, {3: 5.14, 7: 9.11, 15: 16.07, 30: 24.11});
    expect(all[380]!.enabled, isFalse);
    expect(all[380]!.extCounts, isEmpty);
  });

  test('tariffsOne', () async {
    final ru = fixtureMap('rent_tariffsRent')['7'];
    final (client, t) = fakeClient([json(ru)]);
    final tariff = await client.rent.tariffsOne();
    expect(query(t.last), {'country': '7'});
    expect(tariff.code, 7);
    expect(tariff.name, 'russia');
    expect(tariff.extend, 1);
    expect(tariff.confirm, isFalse);
    expect(tariff.count, {3: 1, 7: 1, 15: 1, 30: 1});
    expect(tariff.extCounts, {3: 1, 7: 1, 15: 1, 30: 1});
  });

  test('tariffsOne raises NO_COUNTRY for the [] answer', () async {
    final (client, _) = fakeClient([json(<Object?>[])]);
    await expectLater(
      client.rent.tariffsOne(country: 999),
      throwsApi('NO_COUNTRY'),
    );
  });

  test('close', () async {
    final (client, t) = fakeClient([
      json({'response': '1'}),
    ]);
    await client.rent.close(430);
    expect(t.last.url.path, '/api/rent/closeRentNum.php');
    expect(query(t.last), {'tzid': '430'});
  });

  test('close surfaces NO_CLOSE_RENT_US', () async {
    final (client, _) = fakeClient([
      json({'response': 'NO_CLOSE_RENT_US'}),
    ]);
    await expectLater(client.rent.close(1), throwsApi('NO_CLOSE_RENT_US'));
  });
}
