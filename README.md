# onlinesim

[![pub package](https://img.shields.io/pub/v/onlinesim.svg)](https://pub.dev/packages/onlinesim)
[![CI](https://github.com/s00d/onlinesim-dart-api/actions/workflows/ci.yml/badge.svg)](https://github.com/s00d/onlinesim-dart-api/actions/workflows/ci.yml)

Typed Dart client for the [OnlineSim](https://onlinesim.io) API: SMS numbers, rent, account and free numbers.
Pure Dart on `package:http`: Flutter, CLI, server and web.

```bash
dart pub add onlinesim
```

```dart
import 'package:onlinesim/onlinesim.dart';

Future<void> main() async {
  final client = OnlineSim(apiKey: 'your-api-key');

  final balance = await client.user.balance();
  print('available: ${balance.available} USD');

  final order = await client.numbers.getWithNumber('google', country: 44);
  print('enter ${order.number} in the app');
  print('code: ${await client.numbers.waitCode(order.tzid)}');
  client.close();
}
```

## Testing

`MockOnlineSim` is a built-in offline fake of the API: test your integration without network, key or money.
More in the [testing guide](https://s00d.github.io/onlinesim-dart-api/testing).

```dart
import 'package:onlinesim/onlinesim.dart';

Future<void> main() async {
  final mock = MockOnlineSim(balance: 10);
  final client = mock.client();

  final tzid = await client.numbers.get('google', country: 44);
  mock.addSmsAfter(tzid, 'Your code: 123-456', 2); // arrives on the third poll
  final code = await client.numbers.waitCode(tzid, interval: Duration.zero);

  if (code != '123456' || mock.balance() != 9.8) throw StateError('unexpected');
  print('ok: $code');
}
```

Documentation: **https://s00d.github.io/onlinesim-dart-api/** · Changes: [CHANGELOG.md](CHANGELOG.md) · License: Apache-2.0
