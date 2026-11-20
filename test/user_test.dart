import 'dart:convert';

import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('balance sends income=1 and parses the decimal string', () async {
    final (client, t) = fakeClient([json(fixture('getBalance'))]);
    final b = await client.user.balance();
    expect([b.balance, b.zbalance, b.income], [1442.33, 1023.41, 9.78]);
    expect(b.available, closeTo(418.92, 1e-9));
    expect(t.last.url.path, '/api/getBalance.php');
    expect(query(t.last), {'income': '1'});
  });

  test('balance without income', () async {
    final (client, _) = fakeClient([
      json({'response': '1', 'balance': '0.000', 'zbalance': 0}),
    ]);
    final b = await client.user.balance();
    expect([b.balance, b.zbalance, b.income], [0, 0, null]);
  });

  test('profile', () async {
    final (client, t) = fakeClient([json(fixture('getProfile'))]);
    final p = await client.user.profile();
    expect(t.last.url.path, '/api/getProfile.php');
    expect(p.id, 1);
    expect(p.webhookUrl, 'https://example.com/hook');
    expect(p.numberReject, ['333']);
    expect(p.numberCountry, 1);
    expect(p.apiAccess, isTrue);
    expect(p.locale, 'ru');
    expect(p.isApi, isTrue);
  });

  test('profile: number_reject as a map', () async {
    final (client, _) = fakeClient([
      json({
        'response': '1',
        'profile': {
          'id': 2,
          'number_reject': {'0': '4470', '1': '4471'},
        },
      }),
    ]);
    expect((await client.user.profile()).numberReject, ['4470', '4471']);
  });

  test('balance: available = balance − max(zbalance, 0)', () async {
    final (client, _) = fakeClient([
      json({'response': '1', 'balance': '10.000', 'zbalance': -2.5}),
    ]);
    final b = await client.user.balance();
    expect([b.zbalance, b.available], [-2.5, 10]);
  });

  test('profile: number int|null, country string|null', () async {
    final (client, _) = fakeClient([
      json({
        'response': '1',
        'profile': {'id': 1, 'number': 79001234567, 'country': 'RU'},
      }),
    ]);
    final p = await client.user.profile();
    expect([p.number, p.country], [79001234567, 'RU']);
  });

  test('paymentHistory keeps a JSON-array paylist; nullable order fields',
      () async {
    final body = fixtureMap('getPaymentHistory');
    final paylist = [
      {'id': 0, 'name': 'Card'},
      {'id': 1, 'name': 'Crypto'},
    ];
    final order = {
      'id': 1,
      'sum': '10.00',
      'currency': null,
      'form_text': null,
      'stat': 0,
      'created_at': '2026-06-14 09:12:12',
    };
    final (client, _) = fakeClient([
      json({
        ...body,
        'paylist': paylist,
        'orders': {
          ...(body['orders']! as Map).cast<String, Object?>(),
          'data': [order],
        },
      }),
    ]);
    final h = await client.user.paymentHistory();
    expect(h.paylist, {'0': paylist[0], '1': paylist[1]});
    final o = h.orders.data.single;
    expect([o.currency, o.formText], [null, null]);
  });

  test('paymentHistory normalises the [] paylist', () async {
    final (client, t) = fakeClient([json(fixture('getPaymentHistory'))]);
    final h = await client.user.paymentHistory(page: 2);
    expect(t.last.url.path, '/api/getPaymentHistory.php');
    expect(query(t.last), {'page': '2'});
    expect(h.paylist, isEmpty);
    expect(h.domains, ['on-io.test']);
    expect(h.currency, {'USD': 1});
    expect(h.orders.total, 106);
    expect(h.orders.lastPage, 11);
    final order = h.orders.data.single;
    expect([
      order.id,
      order.sum,
      order.currency,
      order.stat
    ], [
      9462,
      '89.00',
      'USD',
      2,
    ]);
    expect(order.raw['merchant_name'], 'cashout');
  });

  test('setWebhookUrl posts JSON', () async {
    final (client, t) = fakeClient([
      json({
        'response': '1',
        'user': {'id': 2},
      }),
    ]);
    await client.user.setWebhookUrl('https://example.com/hook');
    final call = t.last;
    expect(call.method, 'POST');
    expect(call.url.path, '/api/profile.php');
    expect(call.headers['Content-Type'], 'application/json');
    expect(call.headers['Authorization'], 'Bearer test-key');
    expect(jsonDecode(call.body!), {
      'profile': {'webhook_url': 'https://example.com/hook'},
    });
  });

  test('clearWebhookUrl posts webhook_url: null', () async {
    final (client, t) = fakeClient([
      json({
        'response': '1',
        'user': {'id': 2},
      }),
    ]);
    await client.user.clearWebhookUrl();
    expect(t.last.method, 'POST');
    expect(jsonDecode(t.last.body!), {
      'profile': {'webhook_url': null},
    });
  });

  test('webhookLogs returns the paginator', () async {
    final (client, t) = fakeClient([
      json({
        'response': '1',
        'data': {
          'current_page': 1,
          'data': [
            {
              'id': 7,
              'user_id': 2,
              'webhook_url': 'https://example.com/hook',
              'type': 'receiving_sms',
              'params': {
                'webhook_type': 'receiving_sms',
                'operation_id': 1520,
                'code': '195895',
              },
              'status': 'success',
              'error': null,
              'created_at': '2026-11-19 10:00:01',
              'updated_at': '2026-11-19 10:00:01',
            },
          ],
          'from': 1,
          'to': 1,
          'last_page': 1,
          'per_page': 10,
          'total': 1,
        },
      }),
    ]);
    final page = await client.user.webhookLogs();
    expect(t.last.url.path, '/api/webhook-logs');
    expect(query(t.last), {'page': '1'});
    expect([page.currentPage, page.from, page.to, page.total], [1, 1, 1, 1]);
    final log = page.data.single;
    expect(log.type, WebhookType.receivingSms);
    expect(log.params.operationId, 1520);
    expect(log.params.code, '195895');
    expect(log.status, 'success');
    expect(log.error, isNull);
  });
}
