import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('list: no .php suffix, only the set parameters', () async {
    final (client, t) = fakeClient([json(fixture('getFreeList'))]);
    final list = await client.free.list(
      country: 44,
      number: '7459608320',
      count: 20,
    );
    expect(t.last.url.path, '/api/getFreeList');
    expect(
      query(t.last),
      {'country': '44', 'number': '7459608320', 'count': '20'},
    );
    expect(list.countries.map((c) => c.country), [44, 380]);
    expect(list.numbers['7459608320']!.fullNumber, '447459608320');
    expect(list.messages.data.first.code, '195895');
    expect(list.messages.data.first.inNumber, 'Amazon');
    expect(list.messages.number, '7459608320');
    expect(list.messages.country, 44);
    expect(list.messages.total, 426);
  });

  test('list normalises [] numbers', () async {
    final (client, t) = fakeClient([
      json({
        'response': 1,
        'countries': <Object?>[],
        'numbers': <Object?>[],
        'messages': {'data': <Object?>[]},
      }),
    ]);
    final list = await client.free.list();
    expect(list.numbers, isEmpty);
    expect(query(t.last), isEmpty);
  });
}
