# Numbers

> Order a number, read its SMS, close it — client.numbers.

An operation (`tzid`) is one ordered number. Order it with `get`/`getWithNumber`, read the SMS with `stateOne` or `waitCode`, finish it with `close` (or `ban`). Countries are phone codes (`7`, `44`, …), services are slugs (`google`, `vkcom`, …) as returned by `tariffs`.

## price

Price of one number, USD; `null` when the country has no price for the service.

```dart
Future<double?> price(String service, {int country = 7})
```

<table>
<thead>
  <tr>
    <th>
      Param
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        service
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
    </td>
    
    <td>
      —
    </td>
    
    <td>
      Service slug.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        country
      </code>
    </td>
    
    <td>
      <code>
        int
      </code>
    </td>
    
    <td>
      <code>
        7
      </code>
    </td>
    
    <td>
      Country code.
    </td>
  </tr>
</tbody>
</table>

```dart
final usd = await client.numbers.price('google', country: 44);
```

Errors: `ApiException` `ERROR_NO_SERVICE`, `UNDEFINED_COUNTRY`.

## get

Order a number; returns the operation id. Freezes the price on the balance.

```dart
Future<int> get(String service, {int country = 7, Iterable<Object>? reject})
```

<table>
<thead>
  <tr>
    <th>
      Param
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        service
      </code>
    </td>
    
    <td>
      <code>
        String
      </code>
    </td>
    
    <td>
      —
    </td>
    
    <td>
      Service slug.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        country
      </code>
    </td>
    
    <td>
      <code>
        int
      </code>
    </td>
    
    <td>
      <code>
        7
      </code>
    </td>
    
    <td>
      Country code.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        reject
      </code>
    </td>
    
    <td>
      <code>
        Iterable<Object>?
      </code>
    </td>
    
    <td>
      profile list
    </td>
    
    <td>
      Number prefixes to skip, e.g. <code>
        ['4470']
      </code>
      
      .
    </td>
  </tr>
</tbody>
</table>

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

<table>
<thead>
  <tr>
    <th>
      Option
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        messageToCode
      </code>
    </td>
    
    <td>
      <code>
        bool
      </code>
    </td>
    
    <td>
      <code>
        true
      </code>
    </td>
    
    <td>
      <code>
        msg
      </code>
      
       is the code only; <code>
        false
      </code>
      
       — the full SMS text.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        orderBy
      </code>
    </td>
    
    <td>
      <code>
        SortOrder
      </code>
    </td>
    
    <td>
      <code>
        SortOrder.asc
      </code>
    </td>
    
    <td>
      Order of operations.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        msgList
      </code>
    </td>
    
    <td>
      <code>
        bool
      </code>
    </td>
    
    <td>
      <code>
        false
      </code>
    </td>
    
    <td>
      Fill <code>
        msgList
      </code>
      
       with every SMS (<code>
        List<OperationSms>
      </code>
      
      ).
    </td>
  </tr>
</tbody>
</table>

`Operation`: `tzid`, `response` (empty when the server sends none: no number issued yet), `number?`, `service?`, `country?`, `sum?`, `time?`, `msg?`, `msgList?`, `guardIntervalRemainingSeconds?`, …
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

<table>
<thead>
  <tr>
    <th>
      Option
    </th>
    
    <th>
      Type
    </th>
    
    <th>
      Default
    </th>
    
    <th>
      Description
    </th>
  </tr>
</thead>

<tbody>
  <tr>
    <td>
      <code>
        interval
      </code>
    </td>
    
    <td>
      <code>
        Duration
      </code>
    </td>
    
    <td>
      5 s
    </td>
    
    <td>
      Poll interval.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        timeout
      </code>
    </td>
    
    <td>
      <code>
        Duration
      </code>
    </td>
    
    <td>
      10 min
    </td>
    
    <td>
      Give up after.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        keepOpen
      </code>
    </td>
    
    <td>
      <code>
        bool
      </code>
    </td>
    
    <td>
      <code>
        false
      </code>
    </td>
    
    <td>
      Call <code>
        next(tzid)
      </code>
      
       instead of <code>
        close(tzid)
      </code>
      
      , to wait for another SMS.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        fullMessage
      </code>
    </td>
    
    <td>
      <code>
        bool
      </code>
    </td>
    
    <td>
      <code>
        false
      </code>
    </td>
    
    <td>
      Return the full SMS text instead of the code.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        since
      </code>
    </td>
    
    <td>
      <code>
        String?
      </code>
    </td>
    
    <td>
      <code>
        null
      </code>
    </td>
    
    <td>
      Ignore this value (the previous code).
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        sleep
      </code>
      
      , <code>
        now
      </code>
    </td>
    
    <td>
      functions
    </td>
    
    <td>
      <code>
        Future.delayed
      </code>
      
      , <code>
        DateTime.now
      </code>
    </td>
    
    <td>
      Injectable for tests.
    </td>
  </tr>
</tbody>
</table>

Transient errors are retried until the timeout: `TransportException`, and `ApiException` `TRY_AGAIN_LATER` (the HTTP 429 rate limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR`. Any other `ApiException` is thrown at once.

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

Errors: `ApiException` `ERROR_WRONG_TZID` (not an operation of your account), `ERROR_NO_TZID`.

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

Errors: as `close`; `ApiException` with code `"0"` when the operation already has an SMS — nothing is changed then.

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
