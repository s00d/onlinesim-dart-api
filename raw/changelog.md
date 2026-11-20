# Changelog

> Release notes of the onlinesim Dart package.

The full history is in [CHANGELOG.md](https://github.com/s00d/onlinesim-dart-api/blob/main/CHANGELOG.md).

## 1.0.1

- Fixed models against the current API: `Profile.number`/`country`, `RentSms.code` `'0'` for `notify` SMS, nullable free-list and payment fields; `paymentHistory().paylist` is kept when it arrives as a list; `Balance.available` = balance − max(zbalance, 0).
- `waitCode` retries `TRY_AGAIN_LATER` (rate limit), `ERROR_UNDEFINED` and `INTERVAL_CONCURRENT_REQUESTS_ERROR`.
- `MockOnlineSim` follows the backend more closely: rent reservation and confirmation, `setOperationRevise` and `closeRentNum` answers, missing vs wrong key — see [Testing](/testing).

## 1.0.0

First release.

- One client, `OnlineSim(apiKey: ...)`, with the sections as properties: `client.numbers`, `client.rent`, `client.user`, `client.free`.
- Pure Dart on `package:http`: Flutter, CLI, server and web; injectable `OnlineSimTransport`.
- The key is sent as a Bearer header, never in the URL.
- Typed results and sealed exceptions: `ApiException`, `NoNumberException`, `TransportException`, `WaitTimeoutException`.
- `numbers.waitCode` with `Duration` interval and timeout, `keepOpen`, `since`; retries network errors.
- `user.setWebhookUrl` / `clearWebhookUrl` / `webhookLogs`, `parseWebhook`.
- `MockOnlineSim`, an offline fake of the API for your tests — see [Testing](/testing).
