// Opt-in integration test against a LOCAL backend. Skipped unless both are set:
//   ONLINESIM_IT_BASE=https://on.test/api/  ONLINESIM_IT_KEY=<apikey>
// With ONLINESIM_IT_MOCK=1 it also runs the number lifecycle on the
// provider-free `test` driver (`spec/verify/backend_mock.php setup` first, a
// key of a user without webhook_url, teardown after).
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

final _env = Platform.environment;
final _base = _env['ONLINESIM_IT_BASE'] ?? '';
final _key = _env['ONLINESIM_IT_KEY'] ?? '';
final _enabled = _base.isNotEmpty && _key.isNotEmpty;
final _lifecycle = _enabled && _env['ONLINESIM_IT_MOCK'] == '1';

bool _isLocal(String host) =>
    host == 'localhost' ||
    host == '127.0.0.1' ||
    host.endsWith('.test') ||
    host.endsWith('.localhost');

/// Test-only transport: local backends use a self-signed certificate. Not part
/// of the SDK API.
HttpTransport _insecureTransport() => HttpTransport(IOClient(
      HttpClient()..badCertificateCallback = (cert, host, port) => true,
    ));

void main() {
  if (_enabled && !_isLocal(Uri.parse(_base).host)) {
    throw StateError(
        'refusing non-local integration host ${Uri.parse(_base).host}');
  }
  final transport = _insecureTransport();
  final client = OnlineSim(apiKey: _key, baseUrl: _base, transport: transport);
  tearDownAll(transport.close);

  group('integration: read-only', () {
    test('user.balance', () async {
      final b = await client.user.balance();
      expect(b.balance, isA<double>());
      expect(b.zbalance, isA<double>());
    });

    test('user.profile', () async {
      expect((await client.user.profile()).id, greaterThan(0));
    });

    test('numbers.tariffsOne(44)', () async {
      expect((await client.numbers.tariffsOne(country: 44)).code, 44);
    });

    test('numbers.state', () async {
      expect(await client.numbers.state(), isA<List<Operation>>());
    });

    test('rent.tariffsOne(7)', () async {
      expect((await client.rent.tariffsOne(country: 7)).code, 7);
    });

    test('rent.state', () async {
      for (final r in await client.rent.state()) {
        expect(r.sum, isA<double>());
        expect(r.tzid, greaterThan(0));
      }
    });

    test('user.paymentHistory', () async {
      final h = await client.user.paymentHistory();
      expect(h.orders.currentPage, 1);
    });

    test('user.webhookLogs', () async {
      expect((await client.user.webhookLogs()).currentPage, 1);
    });

    test('free.list', () async {
      expect((await client.free.list()).countries, isA<List<FreeCountry>>());
    });

    test('wrong key → ApiException ERROR_WRONG_KEY', () async {
      final bad =
          OnlineSim(apiKey: 'wrong-key', baseUrl: _base, transport: transport);
      await expectLater(
        bad.user.balance(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'ERROR_WRONG_KEY')),
      );
    });
  },
      skip: _enabled ? false : 'set ONLINESIM_IT_BASE and ONLINESIM_IT_KEY',
      timeout: const Timeout(Duration(seconds: 30)));

  group('integration: number lifecycle (test driver)', () {
    const country = 44;
    const service = 'google';

    /// Injects an SMS through the test driver callback (local backends only).
    Future<void> injectSms(int tzid, String text) async {
      final res = await transport.send(TransportRequest(
        method: 'POST',
        url: Uri.parse(_base).resolve('sms_in_getaways/test'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'id': tzid, 'phoneFrom': 'VK', 'text': text}),
      ));
      expect(res.status, 200);
    }

    test('price → get → getWithNumber → state → SMS → waitCode → close',
        () async {
      expect(
        await client.numbers.price(service, country: country),
        isA<double>(),
      );
      final tzid = await client.numbers.get(service, country: country);
      final order =
          await client.numbers.getWithNumber(service, country: country);
      expect(order.number, matches(RegExp(r'^\+?44\d+$')));
      expect(order.country, country);

      final ids = (await client.numbers.state()).map((op) => op.tzid);
      expect(ids, containsAll([tzid, order.tzid]));
      expect((await client.numbers.stateOne(tzid)).response, startsWith('TZ_'));

      // The test driver answers NO_NUMBER to any reject list: proves `reject`
      // is sent.
      await expectLater(
        client.numbers.get(service, country: country, reject: ['4470']),
        throwsA(isA<NoNumberException>()),
      );

      // No SMS yet: the guard interval keeps it open.
      await expectLater(
        client.numbers.close(order.tzid),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'NO_COMPLETE_TZID')),
      );

      await injectSms(tzid, 'VK: 195895 is your code');
      expect(
        await client.numbers.waitCode(
          tzid,
          interval: const Duration(seconds: 1),
          timeout: const Duration(seconds: 30),
        ),
        '195895',
      );
    });

    test('setWebhookUrl → validation error → clearWebhookUrl', () async {
      await client.user.setWebhookUrl('https://example.com/hook');
      expect(
        (await client.user.profile()).webhookUrl,
        'https://example.com/hook',
      );
      await expectLater(
        client.user.setWebhookUrl('not a url'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_ERROR')),
      );
      await client.user.clearWebhookUrl();
      expect((await client.user.profile()).webhookUrl, isNull);
    });
  },
      skip: _lifecycle ? false : 'set ONLINESIM_IT_MOCK=1 as well',
      timeout: const Timeout(Duration(seconds: 60)));
}
