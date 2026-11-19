---
title: onlinesim
description: Typed Dart client for the OnlineSim API — SMS numbers, rent, account and free numbers. Flutter, CLI, server and web.
---

## Install

Dart 3.0 or newer, or any Flutter 3.10+ app. Pure Dart: the only dependency is `package:http`, so it runs on every platform, the web included.

::code-group
```bash [dart]
dart pub add onlinesim
```

```bash [flutter]
flutter pub add onlinesim
```
::

## Quick start

Check the balance, order a number, wait for the SMS code.

```dart
import 'package:onlinesim/onlinesim.dart';

Future<void> main() async {
  final client = OnlineSim(apiKey: 'your-api-key');

  final balance = await client.user.balance();
  print('available: ${balance.available} USD');

  final order = await client.numbers.getWithNumber('google', country: 44);
  print('enter ${order.number} in the app');

  // Polls every 5 s for up to 10 min, then closes the operation.
  final code = await client.numbers.waitCode(order.tzid);
  print('code: $code');

  client.close();
}
```

## Client options

```dart
import 'package:onlinesim/onlinesim.dart';

final client = OnlineSim(
  apiKey: 'your-api-key',
  lang: 'en',
  timeout: const Duration(seconds: 15),
);
```

| Option | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `String?` | — | Sent as `Authorization: Bearer <apiKey>`, never in the URL. Not needed for tariffs and free numbers. |
| `baseUrl` | `String` | `https://onlinesim.host/api/` | API base; trailing slash optional. |
| `lang` | `String` | `'en'` | Language of server texts (`lang` query parameter). |
| `devId` | `String?` | — | Partner developer id (`dev_id`), sent only when set. |
| `timeout` | `Duration` | 30 s | Per-request timeout. |
| `transport` | `OnlineSimTransport?` | `HttpTransport()` | Transport: an `HttpTransport` over your own `http.Client` (proxy, custom TLS, retries), [`MockOnlineSim`](/testing), or a fake in tests. |

Sections: [`client.numbers`](/numbers), [`client.rent`](/rent), [`client.user`](/user), [`client.free`](/free). Webhook bodies are parsed by the top-level [`parseWebhook`](/webhooks).

`client.close()` closes the default `http.Client`. A transport you pass in stays open: close it yourself.

```dart
import 'package:http/http.dart' as http;
import 'package:onlinesim/onlinesim.dart';

final http.Client httpClient = http.Client();
final client = OnlineSim(apiKey: 'your-api-key', transport: HttpTransport(httpClient));
```

Results are typed classes with camelCase fields (`guard_interval_remaining_seconds` → `guardIntervalRemainingSeconds`). Money the server sends as a decimal string (`balance`, rent `sum`) is a `double`, maps that arrive as an empty PHP array `[]` are `{}`, and maps keyed by country code or rent days have `int` keys.

## Error handling

Every exception extends the sealed `OnlineSimException` (`message`).

| Class | When | Fields |
|---|---|---|
| `ApiException` | The API answered with an error code (also a wrong key, HTTP 456). | `code`, `message` |
| `NoNumberException` | `NO_NUMBER` / `NO_NUMBER_FOR_FORWARD`: no number right now. Subclass of `ApiException`. | `code`, `message` |
| `TransportException` | Network error, request timeout, or a body that is not JSON. | `status` (`null` without a response), `body` (first 500 chars) |
| `WaitTimeoutException` | `waitCode` got no code within its `timeout`. | — |
| `WebhookFormatException` | `parseWebhook` got something that is not a JSON object. | — |

```dart
import 'package:onlinesim/onlinesim.dart';

Future<void> order(OnlineSim client) async {
  try {
    await client.numbers.get('google', country: 44);
  } on NoNumberException {
    // try another country or later
  } on ApiException catch (e) {
    print('${e.code}: ${e.message}'); // e.g. WARNING_LOW_BALANCE
  } on TransportException catch (e) {
    print('network ${e.status} ${e.body}');
  }
}
```

`message` is the server's text when it sends one, otherwise a short English description of the code (`errorMessages`), otherwise the code itself. Profile validation failures become `ApiException` with code `VALIDATION_ERROR`.
