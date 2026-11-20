# Changelog

## 1.0.1

Aligned with the regenerated backend API spec.

### Fixed

- Models: `Profile.number` is `int?` and `Profile.country` is `String?` (they were swapped); `FreeCountry.countryText`/`countryOriginal`, `FreeNumber.countryOriginal` and `PaymentOrder.currency` are nullable. `Operation.response` is empty when the server sends none; `RentSms.code` is `'0'` for a `notify` SMS (the server sends the integer `0`); rent `sum` is read from a number or a decimal string.
- `Balance.available` is `balance − max(zbalance, 0)`.
- `user.paymentHistory()` no longer drops `paylist` when the server sends it as a JSON array (ids 0, 1, 2…); it is kept as a map keyed `'0'`, `'1'`, ….
- `numbers.waitCode` retries `ApiException` `TRY_AGAIN_LATER` (HTTP 429 rate limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR` until its timeout instead of throwing at once.
- Error messages: `"0"` (ban not applied, the operation already has an SMS), `ACCOUNT_CLEANED`, `USER_NOT_ACTIVATED`, `ERROR_UNDEFINED`, `FORWARD_NOT_SUPPORTED` added; `ERROR_NO_KEY`, `NO_NUMBER_FOR_FORWARD`, `ACCOUNT_IDENTIFICATION_REQUIRED`, `API_DISABLED` (no longer sent) removed; `NoNumberException` only for `NO_NUMBER`; `ERROR_WRONG_KEY` reads "Wrong or missing API key".
- `MockOnlineSim` follows the backend: `setOperationRevise` answers `{"tzid":"N","response":"1"}` and `ERROR_WRONG_TZID` / `ERROR_NO_TZID`; `setOperationOk` tzid `0` → `ERROR_NO_TZID`; a missing key is HTTP 200 `ERROR_WRONG_KEY` (456 only for a wrong key, also on public endpoints); `getNum` with `number` adds `title`, `response_text`, `guard_interval_remaining_seconds`. Rent: `getRentNum` reserves the price (`status` 0) and the first non-`notify` SMS confirms and charges it, unknown country → `UNDEFINED_COUNTRY`, `sum` a number in getRentNum/extendRentState and a string in getRentState, `guard_interval_remaining_seconds` with `number`; `extendRentState` refusals are all `TRY_AGAIN_LATER`; `closeRentNum` unknown tzid → `ERROR_NO_OPERATIONS`, releases the reservation of an unconfirmed rent. Webhook-log params: `code` `""` without a code, rent `number` in full digits, rent `time_left` in minutes, `time_start` per type. `profile.php` accepts any `scheme://…` URL. `getPaymentHistory` adds `domains`/`forms`/`buttons`; `getFreeList` lists 44 first, clamps `count` to 10..500, sends ISO-8601 `created_at` and `ignore`/`content`. `MockRent` gains `status` and `initialDays`.
- Docs: rent reservation and `sum`, available = balance − max(zbalance, 0), `ban` answer `"0"`, webhook `number`/`timeLeft`/`timeStart`, the `waitCode` retry policy, the mock's behaviour.

## 1.0.0

First release.

### Added

- `OnlineSim` client: `OnlineSim(apiKey:, baseUrl:, lang:, devId:, timeout:, transport:)` with the sections `numbers`, `rent`, `user` and `free`. The key is sent as `Authorization: Bearer <key>`, never in the URL. Pure Dart on `package:http` (Flutter, CLI, server, web); the transport is an injectable `OnlineSimTransport` (`HttpTransport` wraps any `http.Client`).
- `numbers`: `price`, `get`, `getWithNumber`, `state`, `stateOne`, `next`, `close`, `ban`, `tariffs`, `tariffsOne`, `waitCode` (`Duration` interval/timeout, `keepOpen`, `fullMessage`, `since`, injectable `sleep`/`now`, retries transient network errors).
- `rent`: `get` (extendable by default), `state`, `stateOne`, `extend`, `close`, `tariffs`, `tariffsOne`.
- `user`: `balance`, `profile`, `paymentHistory`, `setWebhookUrl`, `clearWebhookUrl`, `webhookLogs`.
- `free.list` for public free numbers.
- `parseWebhook` for inbound `receiving_sms` / `rent_sms` webhooks.
- Typed models with camelCase fields; decimal-string money parsed to `double`, PHP `[]` empty maps returned as `{}`.
- Sealed exceptions: `OnlineSimException` → `ApiException` (`code`, `message`) → `NoNumberException`, `TransportException` (`status`, `body`), `WaitTimeoutException`, `WebhookFormatException`.
- `MockOnlineSim`: an in-process fake of the API for testing integrations offline — no network, key, money or clock. `mock.client()` returns a normal `OnlineSim` wired to it; the mock itself is an `OnlineSimTransport`. Helpers: `addSms`, `addSmsAfter`, `failNext`, `failNextTransport`, `setBalance`, `balance`, `operations`, `rents`, `requests`, `reset`.
- Documentation site: https://s00d.github.io/onlinesim-dart-api/
