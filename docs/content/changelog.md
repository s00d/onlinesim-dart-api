---
title: Changelog
description: Release notes of the onlinesim Dart package.
navigation:
  order: 7
---

The full history is in [CHANGELOG.md](https://github.com/s00d/onlinesim-dart-api/blob/main/CHANGELOG.md).

## 1.0.0

First release.

- One client, `OnlineSim(apiKey: ...)`, with the sections as properties: `client.numbers`, `client.rent`, `client.user`, `client.free`.
- Pure Dart on `package:http`: Flutter, CLI, server and web; injectable `OnlineSimTransport`.
- The key is sent as a Bearer header, never in the URL.
- Typed results and sealed exceptions: `ApiException`, `NoNumberException`, `TransportException`, `WaitTimeoutException`.
- `numbers.waitCode` with `Duration` interval and timeout, `keepOpen`, `since`; retries network errors.
- `user.setWebhookUrl` / `clearWebhookUrl` / `webhookLogs`, `parseWebhook`.
- `MockOnlineSim`, an offline fake of the API for your tests — see [Testing](/testing).
