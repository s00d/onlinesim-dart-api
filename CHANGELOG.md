# Changelog

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
