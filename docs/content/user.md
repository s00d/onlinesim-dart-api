---
title: User
description: Balance, profile, payments and the webhook URL — client.user.
navigation:
  order: 3
---

## balance

Balance in USD.

```dart
Future<Balance> balance()
```

`Balance`: `balance`, `zbalance`, `income?`, and the getter `available`. `balance` includes the sum frozen by numbers in progress (`zbalance`): `available` = `balance − zbalance`. `income` is the partner income. The server caches the answer for 60 s.

```dart
final balance = await client.user.balance();
print('${balance.available} of ${balance.balance} USD available');
```

Errors: `ApiException` `ERROR_WRONG_KEY`, `ACCOUNT_BLOCKED`, `API_ACCESS_DISABLED`, `API_ACCESS_IP`.

## profile

The account profile.

```dart
Future<Profile> profile()
```

`Profile`: `id`, `name?`, `username?`, `email?`, `locale?`, `currency?`, `numberCountry?`, `numberReject`, `webhookUrl?`, `apiAccess?`, …

```dart
final profile = await client.user.profile();
print('${profile.email} ${profile.webhookUrl}');
```

## paymentHistory

Top-up orders (paginated, newest first) and the available payment methods.

```dart
Future<PaymentHistory> paymentHistory({int page = 1})
```

`PaymentHistory`: `orders` (`Paginator<PaymentOrder>`), `paylist`, `domains`, `currency`. `PaymentOrder.sum` stays a decimal string (`"89.00"`); `PaymentOrder.raw` holds every field as sent.

```dart
final orders = (await client.user.paymentHistory()).orders;
print('${orders.total} orders, page ${orders.currentPage}/${orders.lastPage}');
```

## setWebhookUrl

Set the URL that receives SMS webhooks (see [Webhooks](/webhooks)).

```dart
Future<void> setWebhookUrl(String url)
```

```dart
await client.user.setWebhookUrl('https://example.com/onlinesim-hook');
```

Errors: `ApiException` `VALIDATION_ERROR` for an invalid URL; `message` holds the server's field messages.

## clearWebhookUrl

Remove the webhook URL, also from operations in progress.

```dart
Future<void> clearWebhookUrl()
```

```dart
await client.user.clearWebhookUrl();
```

## webhookLogs

Webhook delivery log, newest first, 10 per page.

```dart
Future<Paginator<WebhookLog>> webhookLogs({int page = 1})
```

`WebhookLog`: `id`, `userId`, `webhookUrl`, `type`, `params`, `status`, `error?`, `createdAt`, `updatedAt` — `type` is `WebhookType.receivingSms` or `WebhookType.rentSms`, `status` is `success`, `fail` or `pending`, `params` the payload that was sent (a `WebhookPayload`).

```dart
final logs = await client.user.webhookLogs();
for (final log in logs.data) {
  print('${log.createdAt} ${log.status} ${log.error}');
}
```
