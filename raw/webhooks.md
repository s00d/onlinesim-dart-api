# Webhooks

> Receive SMS as HTTP callbacks and parse them with parseWebhook.

Set a URL with [`client.user.setWebhookUrl`](/user#setwebhookurl). For each SMS the server POSTs a JSON body to it: `webhook_type` `receiving_sms` for numbers, `rent_sms` for rents. Delivery attempts are listed by [`client.user.webhookLogs`](/user#webhooklogs).

## parseWebhook

Parse an inbound webhook body from a JSON string or an already decoded map.

```dart
WebhookPayload parseWebhook(Object payload)
```

Lenient: numeric fields may arrive as strings, missing or malformed fields become `null`, unknown fields are dropped. It throws `WebhookFormatException` only when the input is not a JSON object.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:onlinesim/onlinesim.dart';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  await for (final request in server) {
    final hook = parseWebhook(await utf8.decoder.bind(request).join());
    if (hook.webhookType == WebhookType.receivingSms) {
      print('${hook.operationId} ${hook.code}');
    }
    request.response.write('ok');
    await request.response.close();
  }
}
```

## Payload fields

<table>
<thead>
  <tr>
    <th>
      Field
    </th>
    
    <th>
      Wire name
    </th>
    
    <th>
      Type
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
        webhookType
      </code>
    </td>
    
    <td>
      <code>
        webhook_type
      </code>
    </td>
    
    <td>
      <code>
        WebhookType?
      </code>
    </td>
    
    <td>
      <code>
        receivingSms
      </code>
      
       or <code>
        rentSms
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        operationId
      </code>
    </td>
    
    <td>
      <code>
        operation_id
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      <code>
        tzid
      </code>
      
       of the operation or rent.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        userId
      </code>
    </td>
    
    <td>
      <code>
        user_id
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      Account id.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        countryCode
      </code>
    </td>
    
    <td>
      <code>
        country_code
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      Country code of the number.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        number
      </code>
    </td>
    
    <td>
      <code>
        number
      </code>
    </td>
    
    <td>
      <code>
        String?
      </code>
    </td>
    
    <td>
      Numbers: <code>
        +
      </code>
      
       and the full number (<code>
        +79001234567
      </code>
      
      ), or <code>
        hidden
      </code>
      
      . Rent: the full number in digits without <code>
        +
      </code>
      
       (<code>
        79001234567
      </code>
      
      ).
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        sender
      </code>
    </td>
    
    <td>
      <code>
        sender
      </code>
    </td>
    
    <td>
      <code>
        String?
      </code>
    </td>
    
    <td>
      Sender of the SMS, e.g. <code>
        VK
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        message
      </code>
    </td>
    
    <td>
      <code>
        message
      </code>
    </td>
    
    <td>
      <code>
        String?
      </code>
    </td>
    
    <td>
      Full SMS text.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        code
      </code>
    </td>
    
    <td>
      <code>
        code
      </code>
    </td>
    
    <td>
      <code>
        String?
      </code>
    </td>
    
    <td>
      Code extracted from the SMS; <code>
        ''
      </code>
      
       when none was found.
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        timeStart
      </code>
    </td>
    
    <td>
      <code>
        time_start
      </code>
    </td>
    
    <td>
      <code>
        String?
      </code>
    </td>
    
    <td>
      Numbers: when the operation was ordered. Rent: when the SMS arrived. <code>
        YYYY-MM-DD HH:MM:SS
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        timeLeft
      </code>
    </td>
    
    <td>
      <code>
        time_left
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      Time left: seconds for numbers, minutes for rent.
    </td>
  </tr>
</tbody>
</table>
