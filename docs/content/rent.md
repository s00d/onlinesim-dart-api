---
title: Rent
description: Rent a number for days and receive every SMS sent to it — client.rent.
navigation:
  order: 2
---

A rent keeps a number for `days` days. Its SMS come in `RentItem.messages`, newest first.

`get` reserves the price (it shows in `zbalance`): the rent starts with `status` `0` and `checked` `false` and waits up to 20 minutes for its first SMS. The first SMS that is not a `notify` notice confirms it (`status` `1`) and charges the price; without one the rent closes and the reservation is released. Some countries (`confirm` in `tariffs`, e.g. US numbers) are confirmed and charged at once.

`RentItem`: `tzid`, `status`, `number`, `country`, `sum`, `days`, `hours`, `time`, `timeSeconds?`, `extension`, `extend`, `messages`, `startTime`, `stopTime`, `dayExtend?`, … —
`sum` is the cost in USD incl. extensions (a `double`; the server sends a number, or a decimal string in `state`), `time` minutes left, `timeSeconds` seconds left,
`extension` `0` not extendable / `1` extendable / `2` auto-extension, `extend` maps days to the extension price (`{}` when not extendable),
`messages` is `List<RentSms>`: `id`, `service`, `text`, `code`, `createdAt` — `code` is `''` when no code was found and `'0'` for a `notify` SMS (a prohibited sender; the server sends the integer `0`).

## get

Rent a number. The price is reserved; the first SMS charges it.

```dart
Future<RentItem> get({int country = 7, int days = 1, bool extension = true})
```

| Param | Type | Default | Description |
|---|---|---|---|
| `country` | `int` | `7` | Country code. |
| `days` | `int` | `1` | One of the tariff's `days` keys. |
| `extension` | `bool` | `true` | `false` makes the rent non-extendable for good. |

```dart
final rent = await client.rent.get(country: 7, days: 7);
print('${rent.tzid} ${rent.number} ${rent.sum}');
```

Errors: `NoNumberException`; `ApiException` `UNDEFINED_DAYS`, `UNDEFINED_COUNTRY`, `WARNING_LOW_BALANCE`, `INTERVAL_CONCURRENT_REQUESTS_ERROR`, `TRY_AGAIN_LATER`.

## state

All rents of the account.

```dart
Future<List<RentItem>> state()
```

```dart
for (final rent in await client.rent.state()) {
  print('${rent.number} ${rent.messages.firstOrNull?.code}');
}
```

## stateOne

One rent.

```dart
Future<RentItem> stateOne(int tzid)
```

```dart
final messages = (await client.rent.stateOne(tzid)).messages;
```

Errors: `ApiException` `ERROR_NO_OPERATIONS` for an unknown tzid.

## extend

Extend a rent by `days` days and charge the balance at once. Only confirmed rents (`status` `1` or `4`) created with `extension: true`.

```dart
Future<RentItem> extend(int tzid, {int days = 1})
```

```dart
final rent = await client.rent.extend(tzid, days: 3);
print(rent.stopTime);
```

Errors: `ApiException` `TRY_AGAIN_LATER` (unknown tzid, not confirmed yet or closed, not extendable, unknown period, a repeat within 10 s), `WARNING_LOW_BALANCE`.

## close

Return the number before the period ends. A rent that is not confirmed yet (`status` `0`) and has no SMS can be closed only after 120 s; then, or with only `notify` SMS, the reservation is released. With a real SMS the rent is confirmed (charged) and closed. A confirmed rent closes without a refund. US numbers cannot be closed early.

```dart
Future<void> close(int tzid)
```

```dart
await client.rent.close(tzid);
```

Errors: `ApiException` `ERROR_NO_OPERATIONS`, `NO_COMPLETE_TZID`, `NO_CLOSE_RENT_US`, `TRY_AGAIN_LATER`.

## tariffs

Rent prices of every country, keyed by country code. No API key needed.

```dart
Future<Map<int, RentTariff>> tariffs()
```

`RentTariff`: `code`, `name`, `enabled`, `isNew`, `position`, `extend`, `confirm?`, `days`, `count`, `extCounts` — `days` maps rent days to the price in USD, `count` to the numbers available.

```dart
final tariffs = await client.rent.tariffs();
```

## tariffsOne

Rent prices of one country.

```dart
Future<RentTariff> tariffsOne({int country = 7})
```

```dart
final tariff = await client.rent.tariffsOne(country: 7);
print(tariff.days[7]); // price of 7 days
```

Errors: `ApiException` `NO_COUNTRY` for a country without rent.
