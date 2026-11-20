---
title: Webhooks
description: Receive SMS as HTTP callbacks and parse them with parseWebhook.
navigation:
  order: 5
---

Set a URL with [`client.user.setWebhookUrl`](/user#setwebhookurl). For each SMS the server POSTs a JSON body to it: `webhook_type` `receiving_sms` for numbers, `rent_sms` for rents. Delivery attempts are listed by [`client.user.webhookLogs`](/user#webhooklogs).

## parseWebhook

Parse an inbound webhook body from a JSON string or an already decoded map.

```dart
WebhookPayload parseWebhook(Object payload)
```

Lenient: numeric fields may arrive as strings, missing or malformed fields become `null`, unknown fields are dropped. It throws `WebhookFormatException` only when the input is not a JSON object.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:onlinesim/onlinesim.dart';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  await for (final request in server) {
    final hook = parseWebhook(await utf8.decoder.bind(request).join());
    if (hook.webhookType == WebhookType.receivingSms) {
      print('${hook.operationId} ${hook.code}');
    }
    request.response.write('ok');
    await request.response.close();
  }
}
```

## Payload fields

| Field | Wire name | Type | Description |
|---|---|---|---|
| `webhookType` | `webhook_type` | `WebhookType?` | `receivingSms` or `rentSms`. |
| `operationId` | `operation_id` | `int?` | `tzid` of the operation or rent. |
| `userId` | `user_id` | `int?` | Account id. |
| `countryCode` | `country_code` | `int?` | Country code of the number. |
| `number` | `number` | `String?` | Numbers: `+` and the full number (`+79001234567`), or `hidden`. Rent: the full number in digits without `+` (`79001234567`). |
| `sender` | `sender` | `String?` | Sender of the SMS, e.g. `VK`. |
| `message` | `message` | `String?` | Full SMS text. |
| `code` | `code` | `String?` | Code extracted from the SMS; `''` when none was found. |
| `timeStart` | `time_start` | `String?` | Numbers: when the operation was ordered. Rent: when the SMS arrived. `YYYY-MM-DD HH:MM:SS`. |
| `timeLeft` | `time_left` | `int?` | Time left: seconds for numbers, minutes for rent. |
