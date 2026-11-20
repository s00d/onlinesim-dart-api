import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

final class _HangingTransport implements OnlineSimTransport {
  @override
  Future<TransportResponse> send(TransportRequest request) =>
      Completer<TransportResponse>().future;
}

void main() {
  group('client options and encoding', () {
    test('sends the key as a Bearer header, never in the query, plus lang',
        () async {
      final (client, t) = fakeClient([
        json({'response': '1', 'price': 0.36}),
      ]);
      await client.numbers.price('vkcom', country: 44);
      final call = t.last;
      expect(call.method, 'GET');
      expect(call.headers['Authorization'], 'Bearer test-key');
      expect(call.headers['Accept'], 'application/json');
      expect(call.headers.containsKey('Content-Type'), isFalse);
      expect(call.body, isNull);
      expect(call.url.queryParameters.containsKey('apikey'), isFalse);
      expect(call.url.queryParameters['lang'], 'en');
      expect(call.url.queryParameters.containsKey('dev_id'), isFalse);
    });

    test('applies lang, devId and a base URL without trailing slash', () async {
      final (client, t) = fakeClient(
        [
          json({'response': '1', 'price': 1}),
        ],
        baseUrl: 'https://api.test/api',
        lang: 'ru',
        devId: '42',
      );
      await client.numbers.price('vkcom');
      final url = t.last.url;
      expect('${url.origin}${url.path}', 'https://api.test/api/getPrice.php');
      expect(url.queryParameters['lang'], 'ru');
      expect(url.queryParameters['dev_id'], '42');
    });

    test('sends no Authorization header without a key', () async {
      for (final key in [null, '']) {
        final (client, t) = fakeClient([
          json({'response': '1', 'price': 1}),
        ], apiKey: key);
        await client.numbers.price('vkcom');
        expect(t.last.headers.containsKey('Authorization'), isFalse);
      }
    });

    test('uses https://onlinesim.host/api/ by default', () async {
      final t = FakeTransport([
        json({'response': '1', 'price': 1}),
      ]);
      await OnlineSim(transport: t).numbers.price('vkcom');
      expect(
        t.last.url.toString(),
        startsWith('https://onlinesim.host/api/getPrice.php?'),
      );
      expect(defaultBaseUrl, 'https://onlinesim.host/api/');
    });

    test('close() leaves a transport it does not own alone', () {
      final (client, _) = fakeClient([]);
      client.close(); // FakeTransport has nothing to close; must not throw
    });
  });

  group('response handling', () {
    test('maps NO_NUMBER to NoNumberException (an ApiException)', () async {
      final (client, _) = fakeClient([
        json({'response': 'NO_NUMBER'}),
      ]);
      await expectLater(
        client.numbers.get('google', country: 44),
        throwsA(isA<NoNumberException>()
            .having((e) => e.code, 'code', 'NO_NUMBER')
            .having((e) => e.message, 'message',
                'No numbers available for this service right now')),
      );
    });

    test('maps HTTP 429 TRY_AGAIN_LATER (rate limit) to ApiException',
        () async {
      final (client, _) = fakeClient([
        json({'response': 'TRY_AGAIN_LATER'}, status: 429),
      ]);
      await expectLater(
        client.numbers.state(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'TRY_AGAIN_LATER')
            .having((e) => e, 'not NoNumber', isNot(isA<NoNumberException>()))),
      );
    });

    test('maps a missing key (HTTP 200 ERROR_WRONG_KEY) to ApiException',
        () async {
      final (client, _) = fakeClient([
        json({'response': 'ERROR_WRONG_KEY'}),
      ], apiKey: null);
      await expectLater(
        client.user.balance(),
        throwsApi('ERROR_WRONG_KEY', 'Wrong or missing API key'),
      );
    });

    test('maps only NO_NUMBER to NoNumberException; new codes have messages',
        () async {
      final (client, _) = fakeClient([
        json({'response': 'FORWARD_NOT_SUPPORTED'}),
      ]);
      await expectLater(
        client.numbers.get('google'),
        throwsA(isA<ApiException>()
            .having((e) => e, 'type', isNot(isA<NoNumberException>()))
            .having((e) => e.message, 'message',
                'Number forwarding is no longer available')),
      );
      for (final code in [
        'ACCOUNT_CLEANED',
        'USER_NOT_ACTIVATED',
        'ERROR_UNDEFINED',
        '0',
      ]) {
        expect(errorMessages[code], isNotEmpty, reason: code);
      }
      for (final code in [
        'ERROR_NO_KEY',
        'NO_NUMBER_FOR_FORWARD',
        'ACCOUNT_IDENTIFICATION_REQUIRED',
        'API_DISABLED',
      ]) {
        expect(errorMessages.containsKey(code), isFalse, reason: code);
      }
    });

    test('maps HTTP 456 ERROR_WRONG_KEY to ApiException (body before status)',
        () async {
      final (client, _) = fakeClient([
        json({'response': 'ERROR_WRONG_KEY'}, status: 456),
      ]);
      await expectLater(
        client.user.balance(),
        throwsApi('ERROR_WRONG_KEY', 'Wrong or missing API key'),
      );
    });

    test('prefers the server message, but not when it only echoes the code',
        () async {
      final (client, _) = fakeClient([
        json({'response': 'TRY_AGAIN_LATER', 'message': 'Maintenance'}),
        json({'response': 'UNDEFINED_COUNTRY', 'message': 'UNDEFINED_COUNTRY'}),
        json({'response': 'SOMETHING_NEW'}),
      ]);
      await expectLater(
        client.numbers.get('x'),
        throwsApi('TRY_AGAIN_LATER', 'Maintenance'),
      );
      await expectLater(
        client.numbers.get('x'),
        throwsApi('UNDEFINED_COUNTRY', 'Unknown country'),
      );
      await expectLater(
        client.numbers.get('x'),
        throwsApi('SOMETHING_NEW', 'SOMETHING_NEW'),
      );
    });

    test('maps a validation object to VALIDATION_ERROR with field messages',
        () async {
      final (client, _) = fakeClient([
        json({
          'response': {
            'webhook_url': [
              'The webhook url must be a valid URL.',
              'Too long.'
            ],
            'name': ['Required.'],
          },
        }),
      ]);
      await expectLater(
        client.user.setWebhookUrl('nope'),
        throwsApi(
          'VALIDATION_ERROR',
          'The webhook url must be a valid URL.; Too long.; Required.',
        ),
      );
    });

    test('maps a non-JSON body to TransportException with status and body',
        () async {
      final (client, _) = fakeClient([
        raw('<html>Bad gateway</html>', status: 502),
      ]);
      await expectLater(
        client.user.balance(),
        throwsA(isA<TransportException>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.body, 'body', '<html>Bad gateway</html>')),
      );
    });

    test('cuts the body excerpt to 500 characters', () async {
      final (client, _) = fakeClient([raw('x' * 2000, status: 500)]);
      await expectLater(
        client.user.balance(),
        throwsA(isA<TransportException>()
            .having((e) => e.body.length, 'body length', 500)),
      );
    });

    test('maps a JSON error status without `response` to TransportException',
        () async {
      final (client, _) = fakeClient([
        json({'error': 'boom'}, status: 500),
      ]);
      await expectLater(
        client.user.balance(),
        throwsA(isA<TransportException>()
            .having((e) => e.status, 'status', 500)
            .having((e) => e.message, 'message', 'HTTP 500')),
      );
    });

    test('maps a network failure to TransportException without status',
        () async {
      final (client, _) = fakeClient([const SocketLike('connection reset')]);
      await expectLater(
        client.user.balance(),
        throwsA(isA<TransportException>()
            .having((e) => e.status, 'status', isNull)
            .having((e) => e.message, 'message',
                'Network error: connection reset')),
      );
    });

    test('times out after the default 30 s and raises TransportException', () {
      fakeAsync((async) {
        final client = OnlineSim(apiKey: 'k', transport: _HangingTransport());
        Object? error;
        client.user.balance().then((_) {}, onError: (Object e) {
          error = e;
        });
        async.elapse(const Duration(milliseconds: 29999));
        expect(error, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(
          error,
          isA<TransportException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.message, 'message',
                  'Request timed out after 30000 ms'),
        );
      });
    });

    test('returns bodies without `response` as they are', () async {
      final (client, _) = fakeClient([json(<Object?>[])]);
      expect(await client.numbers.state(), isEmpty);
    });

    test('exceptions print their code', () {
      expect(
        ApiException('ERROR_WRONG_KEY').toString(),
        'ApiException(ERROR_WRONG_KEY): Wrong or missing API key',
      );
      expect(errorMessages['NO_COMPLETE_TZID'], isNotEmpty);
    });
  });
}

/// A network error as a transport would throw it.
final class SocketLike implements Exception {
  const SocketLike(this.message);

  final String message;

  @override
  String toString() => message;
}
