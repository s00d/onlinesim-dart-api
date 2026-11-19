import 'dart:convert';

import 'package:onlinesim/onlinesim.dart';
import 'package:test/test.dart';

void main() {
  test('parses a receiving_sms JSON string', () {
    final hook = parseWebhook(jsonEncode({
      'webhook_type': 'receiving_sms',
      'operation_id': 1520,
      'user_id': 2,
      'country_code': 7,
      'number': '+79001234567',
      'sender': 'VK',
      'message': 'VK: 195895 is your code',
      'code': '195895',
      'time_start': '2026-11-19 10:00:00',
      'time_left': 1100,
    }));
    expect(hook.webhookType, WebhookType.receivingSms);
    expect(hook.operationId, 1520);
    expect(hook.userId, 2);
    expect(hook.countryCode, 7);
    expect(hook.number, '+79001234567');
    expect(hook.sender, 'VK');
    expect(hook.message, 'VK: 195895 is your code');
    expect(hook.code, '195895');
    expect(hook.timeStart, '2026-11-19 10:00:00');
    expect(hook.timeLeft, 1100);
  });

  test('is lenient: numeric strings, missing fields, unknown fields, types',
      () {
    final hook = parseWebhook({
      'webhook_type': 'rent_sms',
      'operation_id': '430',
      'code': 2991,
      'time_left': 'soon',
      'extra': true,
    });
    expect(hook.webhookType, WebhookType.rentSms);
    expect(hook.operationId, 430);
    expect(hook.code, '2991');
    expect(hook.timeLeft, isNull);
    for (final v in [
      hook.userId,
      hook.countryCode,
      hook.number,
      hook.sender,
      hook.message,
      hook.timeStart,
    ]) {
      expect(v, isNull);
    }
    expect(parseWebhook({'webhook_type': 'other'}).webhookType, isNull);
  });

  test('throws WebhookFormatException only for a non-object', () {
    for (final input in ['not json', '[1,2]', 'null', 42]) {
      expect(
        () => parseWebhook(input),
        throwsA(isA<WebhookFormatException>()),
        reason: '$input',
      );
    }
    expect(
      () => parseWebhook('[1,2]'),
      throwsA(isA<OnlineSimException>()
          .having((e) => e.message, 'message', contains('not a JSON object'))),
    );
  });
}
