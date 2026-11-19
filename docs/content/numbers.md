---
title: Numbers
description: Order a number, read its SMS, close it — client.numbers.
navigation:
  order: 1
---

An operation (`tzid`) is one ordered number. Order it with `get`/`getWithNumber`, read the SMS with `stateOne` or `waitCode`, finish it with `close` (or `ban`). Countries are phone codes (`7`, `44`, …), services are slugs (`google`, `vkcom`, …) as returned by `tariffs`.

## price

Price of one number, USD; `null` when the country has no price for the service.

```dart
Future<double?> price(String service, {int country = 7})
```

| Param | Type | Default | Description |
|---|---|---|---|
| `service` | `String` | — | Service slug. |
| `country` | `int` | `7` | Country code. |

```dart
final usd = await client.numbers.price('google', country: 44);
```

Errors: `ApiException` `ERROR_NO_SERVICE`, `UNDEFINED_COUNTRY`.

## get

Order a number; returns the operation id. Freezes the price on the balance.

```dart
Future<int> get(String service, {int country = 7, Iterable<Object>? reject})
```

| Param | Type | Default | Description |
|---|---|---|---|
| `service` | `String` | — | Service slug. |
| `country` | `int` | `7` | Country code. |
| `reject` | `Iterable<Object>?` | profile list | Number prefixes to skip, e.g. `['4470']`. |

```dart
final tzid = await client.numbers.get('google', country: 44, reject: ['4470']);
```

Errors: `NoNumberException`; `ApiException` `WARNING_LOW_BALANCE`, `ERROR_NO_SERVICE`, `UNDEFINED_COUNTRY`, `EXCEEDED_CONCURRENT_OPERATIONS`, `INTERVAL_CONCURRENT_REQUESTS_ERROR`, `TRY_AGAIN_LATER`.

## getWithNumber

Same as `get`, but returns the number right away.

```dart
Future<NumberOrder> getWithNumber(String service, {int country = 7, Iterable<Object>? reject})
```

Returns `NumberOrder`: `tzid`, `number` (with `+`), `country`, `time` (seconds left), `service`, `title?`, `guardIntervalRemainingSeconds?`.

```dart
final order = await client.numbers.getWithNumber('google', country: 44);
print('${order.tzid} ${order.number}');
```

Errors: as `get`.

## state

All operations of the account; `[]` when there are none.

```dart
Future<List<Operation>> state({bool messageToCode = true, SortOrder orderBy = SortOrder.asc, bool msgList = false})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `messageToCode` | `bool` | `true` | `msg` is the code only; `false` — the full SMS text. |
| `orderBy` | `SortOrder` | `SortOrder.asc` | Order of operations. |
| `msgList` | `bool` | `false` | Fill `msgList` with every SMS (`List<OperationSms>`). |

`Operation`: `tzid`, `response`, `number?`, `service?`, `country?`, `sum?`, `time?`, `msg?`, `msgList?`, `guardIntervalRemainingSeconds?`, …
`response` is the state (constants in `OperationStatus`): `TZ_INPOOL` (number being assigned), `TZ_NUM_WAIT` (waiting for SMS), `TZ_NUM_ANSWER` (SMS arrived), `TZ_OVER_OK` (finished), `ERROR_NO_ITEMS` (failed). `msg` is `null` until the first SMS. The server caches answers for a few seconds.

```dart
for (final op in await client.numbers.state(orderBy: SortOrder.desc)) {
  print('${op.tzid} ${op.response} ${op.msg}');
}
```

## stateOne

One operation.

```dart
Future<Operation> stateOne(int tzid, {bool messageToCode = true, bool msgList = false})
```

```dart
final op = await client.numbers.stateOne(tzid);
if (op.response == OperationStatus.numAnswer) print(op.msg);
```

Errors: `ApiException` `ERROR_NO_OPERATIONS` when the operation does not exist (any more).

## waitCode

Poll the operation until a code arrives, then close it and return the code.

```dart
Future<String> waitCode(int tzid, {Duration interval = const Duration(seconds: 5), Duration timeout = const Duration(minutes: 10), bool keepOpen = false, bool fullMessage = false, String? since, Future<void> Function(Duration)? sleep, DateTime Function()? now})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `interval` | `Duration` | 5 s | Poll interval. |
| `timeout` | `Duration` | 10 min | Give up after. |
| `keepOpen` | `bool` | `false` | Call `next(tzid)` instead of `close(tzid)`, to wait for another SMS. |
| `fullMessage` | `bool` | `false` | Return the full SMS text instead of the code. |
| `since` | `String?` | `null` | Ignore this value (the previous code). |
| `sleep`, `now` | functions | `Future.delayed`, `DateTime.now` | Injectable for tests. |

A transient `TransportException` is retried until the timeout; any `ApiException` is thrown at once.

```dart
final first = await client.numbers.waitCode(tzid, keepOpen: true);
final second = await client.numbers.waitCode(tzid, since: first);
```

Errors: `WaitTimeoutException`; `ApiException` with code `TZ_OVER_OK` or `ERROR_NO_ITEMS` when the operation ended without a new code; any other `ApiException` from `stateOne`/`close`/`next`.

## next

Switch the operation to its next SMS and keep it open (for services that send several SMS).

```dart
Future<void> next(int tzid)
```

```dart
await client.numbers.next(tzid);
```

## close

Finish the operation. An operation without SMS can be closed only after its guard interval (`guardIntervalRemainingSeconds`); every attempt locks the tzid for 5 s.

```dart
Future<void> close(int tzid)
```

```dart
await client.numbers.close(tzid);
```

Errors: `ApiException` `NO_COMPLETE_TZID`, `INTERVAL_CONCURRENT_REQUESTS_ERROR`, `ERROR_WRONG_TZID`.

## ban

Finish the operation and report the number as bad. Only before any SMS arrived.

```dart
Future<void> ban(int tzid)
```

```dart
await client.numbers.ban(tzid);
```

Errors: as `close`.

## tariffs

Services, prices and stock of every country, keyed by country code. No API key needed. The answer is large (a few MB); prefer `tariffsOne`.

```dart
Future<Map<int, CountryStat>> tariffs()
```

`CountryStat`: `name`, `localeName?`, `position`, `code`, `other?`, `isNew`, `enabled`, `services`; `services` maps `service_<slug>` to `ServiceStat` (`count?`, `popular`, `code`, `price`, `id`, `service`, `slug`). `count` is `null` when the server reports the stock as unknown.

```dart
final all = await client.numbers.tariffs();
print('${all.length} countries');
```

## tariffsOne

Services, prices and stock of one country.

```dart
Future<CountryStat> tariffsOne({int country = 7})
```

```dart
final uk = await client.numbers.tariffsOne(country: 44);
for (final s in uk.services.values) {
  print('${s.slug} ${s.price} ${s.count}');
}
```

Errors: `ApiException` `NO_COUNTRY`.
