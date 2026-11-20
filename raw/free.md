# Free numbers

> Public numbers and their SMS — client.free. No API key needed.

## list

Countries, the numbers of the selected country and the SMS of the selected number, in one call.

```dart
Future<FreeList> list({int? country, String? number, int? page, int? count})
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
        country
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      <code>
        44
      </code>
      
       (server)
    </td>
    
    <td>
      Country code; an unknown one falls back to the first available.
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
        String?
      </code>
    </td>
    
    <td>
      first number
    </td>
    
    <td>
      Number <strong>
        without
      </strong>
      
       the country code, as the keys of <code>
        numbers
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        page
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      <code>
        1
      </code>
    </td>
    
    <td>
      Page of <code>
        messages
      </code>
      
      .
    </td>
  </tr>
  
  <tr>
    <td>
      <code>
        count
      </code>
    </td>
    
    <td>
      <code>
        int?
      </code>
    </td>
    
    <td>
      server default
    </td>
    
    <td>
      SMS per page, 10–500.
    </td>
  </tr>
</tbody>
</table>

`FreeList`:

- `countries`: `List<FreeCountry>` — `country`, `countryText?`, `countryOriginal?` (`null` when the server has no name)
- `numbers`: `Map<String, FreeNumber>` keyed by the short number — `country`, `countryOriginal?`, `fullNumber`, `dataHumans`, `isArchive`
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
