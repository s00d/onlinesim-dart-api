---
title: Free numbers
description: Public numbers and their SMS — client.free. No API key needed.
navigation:
  order: 4
---

## list

Countries, the numbers of the selected country and the SMS of the selected number, in one call.

```dart
Future<FreeList> list({int? country, String? number, int? page, int? count})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `country` | `int?` | `44` (server) | Country code; an unknown one falls back to the first available. |
| `number` | `String?` | first number | Number **without** the country code, as the keys of `numbers`. |
| `page` | `int?` | `1` | Page of `messages`. |
| `count` | `int?` | server default | SMS per page, 10–500. |

`FreeList`:

- `countries`: `List<FreeCountry>` — `country`, `countryText`, `countryOriginal`
- `numbers`: `Map<String, FreeNumber>` keyed by the short number — `country`, `countryOriginal`, `fullNumber`, `dataHumans`, `isArchive`
- `messages`: `FreeMessages`, a paginator of `FreeMessage` (`id`, `text`, `inNumber`, `myNumber`, `code`, `createdAt`, `dataHumans`) plus `number` and `country`; `code` is `-` when no code was found

```dart
final list = await client.free.list(country: 44);
final short = list.numbers.keys.firstOrNull;
if (short != null) {
  final page = await client.free.list(country: 44, number: short, count: 20);
  for (final sms in page.messages.data) {
    print('${sms.inNumber} ${sms.code} ${sms.text}');
  }
}
```
