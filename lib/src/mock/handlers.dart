part of 'mock.dart';

// The mock's routes: endpoint path (relative to `/api/`) → handler. A handler
// gets the state and the request and returns the JSON body the real backend
// would send (HTTP 200). Shapes follow the OpenAPI spec and the live captures:
// `response` as int or string per endpoint, decimal-string money, `[]` for
// empty maps. Auth, queued failures, 456 and 404 are the transport's job.

typedef _Handler = Object? Function(_MockState state, MockRequest req);

/// Endpoints that answer without a key.
const _publicPaths = {
  'getNumbersStats.php',
  'rent/tariffsRent.php',
  'getFreeList',
};

const _countryNames = {
  7: ('russia', 'Russia'),
  44: ('united_kingdom', 'United Kingdom'),
};

Map<String, Object?> _error(String code) => {'response': code};

bool _flag(MockRequest req, String key) {
  final v = req.query[key];
  return v != null && v != '0';
}

int _int(MockRequest req, String key, int fallback) =>
    int.tryParse(req.query[key] ?? '') ?? fallback;

/// USD with [digits] decimals, as the backend sends `balance` and rent `sum`
/// of getRentState.
String _decimal(int mills, [int digits = 3]) =>
    _fromMills(mills).toStringAsFixed(digits);

/// `YYYY-MM-DDTHH:MM:SS.000000Z`, the ISO-8601 form getFreeList sends.
String _iso(int seconds) => '${_stamp(seconds).replaceFirst(' ', 'T')}.000000Z';

(String, String) _countryName(int code) =>
    _countryNames[code] ?? ('country_$code', 'Country $code');

/// Laravel paginator over [items].
Map<String, Object?> _paginate(
  List<Object?> items,
  int page,
  int perPage,
  String path,
) {
  final total = items.length;
  final lastPage = total == 0 ? 1 : (total / perPage).ceil();
  final start = ((page - 1) * perPage).clamp(0, total);
  final data = items.sublist(start, (start + perPage).clamp(0, total));
  String url(int p) => 'https://onlinesim.host/api/$path?page=$p';
  return {
    'current_page': page,
    'data': data,
    'first_page_url': url(1),
    'from': data.isEmpty ? null : start + 1,
    'last_page': lastPage,
    'last_page_url': url(lastPage),
    'links': <Object?>[],
    'next_page_url': page < lastPage ? url(page + 1) : null,
    'path': 'https://onlinesim.host/api/$path',
    'per_page': perPage,
    'prev_page_url': page > 1 ? url(page - 1) : null,
    'to': data.isEmpty ? null : start + data.length,
    'total': total,
  };
}

// ----- numbers -----

String _msgOf(MockSms sms, bool toCode) =>
    toCode ? sms.code ?? sms.text : sms.text;

Map<String, Object?> _operationView(
  _MockState state,
  MockOperation op,
  MockRequest req,
) {
  final toCode = _flag(req, 'message_to_code');
  final open = op._status != OperationStatus.overOk;
  final view = <String, Object?>{
    'country': op.country,
    'sum': op.sum,
    'service': op.service,
    'number': op.number,
    'subscription_package_id': null,
    'webhook_url': state.webhookUrl,
    'response': op._status,
    'tzid': op.tzid,
    'time': open ? _operationTime : 0,
    'form': 'index',
  };
  if (_flag(req, 'msg_list')) {
    if (op._messages.isNotEmpty) {
      view['msg'] = [
        for (final s in op._messages)
          {'service': s.service, 'msg': _msgOf(s, toCode)},
      ];
    }
  } else if (op._cursor < op._messages.length) {
    view['msg'] = _msgOf(op._messages[op._cursor], toCode);
  }
  if (req.query.containsKey('number')) {
    view['guard_interval_remaining_seconds'] =
        open && op._messages.isEmpty ? state.guardInterval : 0;
  }
  return view;
}

Object? _getPrice(_MockState state, MockRequest req) {
  final prices = state.prices[_int(req, 'country', 7)];
  if (prices == null) return _error('UNDEFINED_COUNTRY');
  return {'response': '1', 'price': prices[req.query['service'] ?? '']};
}

Object? _getNum(_MockState state, MockRequest req) {
  final country = _int(req, 'country', 7);
  final service = req.query['service'] ?? '';
  final prices = state.prices[country];
  if (prices == null) return _error('UNDEFINED_COUNTRY');
  final price = prices[service];
  if (price == null) return _error('ERROR_NO_SERVICE');
  final cost = _toMills(price);
  if (state.available < cost) return _error('WARNING_LOW_BALANCE');

  final number = '+$country${_MockState.shortNumber(state.peekId())}';
  final reject = (req.query['reject'] ?? '').split(',').where((p) => p != '');
  if (reject.any((prefix) => number.substring(1).startsWith(prefix))) {
    return _error('NO_NUMBER');
  }

  final tzid = state.nextId();
  state.frozen += cost;
  state.operations[tzid] = MockOperation._(
    tzid: tzid,
    service: service,
    country: country,
    number: number,
    sum: price,
  );
  if (!req.query.containsKey('number')) return {'response': 1, 'tzid': tzid};
  return {
    'response': 1,
    'tzid': tzid,
    'number': number,
    'country': country,
    'time': _operationTime,
    'service': service,
    'title': service,
    'response_text': 'Waiting for SMS',
    'guard_interval_remaining_seconds': state.guardInterval,
  };
}

Object? _getState(_MockState state, MockRequest req) {
  final ops = req.query.containsKey('tzid')
      ? [
          if (state.operations[_int(req, 'tzid', -1)] case final op?) op,
        ]
      : state.operations.values.toList();
  for (final op in ops) {
    state.poll(op.tzid);
  }
  if (ops.isEmpty) return _error('ERROR_NO_OPERATIONS');
  final desc = req.query['orderby'] == 'desc';
  ops.sort((a, b) => desc ? b.tzid - a.tzid : a.tzid - b.tzid);
  return [for (final op in ops) _operationView(state, op, req)];
}

Object? _setOperationRevise(_MockState state, MockRequest req) {
  final tzid = _int(req, 'tzid', 0);
  if (tzid == 0) return _error('ERROR_NO_TZID');
  final op = state.operations[tzid];
  if (op == null) return _error('ERROR_WRONG_TZID');
  if (op._status != OperationStatus.overOk) {
    op._cursor = op._messages.length;
    op._status = OperationStatus.numWait;
  }
  return {'tzid': '$tzid', 'response': '1'};
}

Object? _setOperationOk(_MockState state, MockRequest req) {
  final tzid = _int(req, 'tzid', 0);
  if (tzid == 0) return _error('ERROR_NO_TZID');
  final op = state.operations[tzid];
  if (op == null || op._status == OperationStatus.overOk) {
    return _error('ERROR_WRONG_TZID');
  }
  final received = op._messages.isNotEmpty;
  if (_flag(req, 'ban') && received) return {'response': '0'};
  if (!received && state.guardInterval > 0) return _error('NO_COMPLETE_TZID');
  final cost = _toMills(op.sum);
  state.frozen -= cost;
  if (received) state.balance -= cost;
  op._status = OperationStatus.overOk;
  return {'response': 1, 'tzid': tzid};
}

Map<String, Object?> _countryStat(_MockState state, int code) {
  final (name, locale) = _countryName(code);
  final services = <String, Object?>{};
  var i = 0;
  (state.prices[code] ?? const {}).forEach((slug, price) {
    services['service_$slug'] = {
      'count': 100,
      'popular': false,
      'code': code,
      'price': price,
      'id': ++i,
      'service': slug,
      'slug': slug,
    };
  });
  return {
    'name': name,
    'position': code,
    'code': code,
    'other': false,
    'new': false,
    'enabled': true,
    'services': services.isEmpty ? <Object?>[] : services,
    'locale_name': locale,
  };
}

Object? _getNumbersStats(_MockState state, MockRequest req) {
  if (req.query['country'] == 'all') {
    if (state.prices.isEmpty) return <Object?>[];
    return {
      for (final code in state.prices.keys) '$code': _countryStat(state, code),
    };
  }
  final code = _int(req, 'country', 7);
  return state.prices.containsKey(code)
      ? _countryStat(state, code)
      : _error('NO_COUNTRY');
}

// ----- rent -----

/// A rent as the backend sends it. `sum` is a number in getRentNum /
/// extendRentState and a 2-decimal string in getRentState ([stringSum]). An
/// unconfirmed rent (`status` 0) waits 20 minutes for its first SMS.
Map<String, Object?> _rentItem(
  _MockState state,
  MockRent rent,
  MockRequest req, {
  bool stringSum = false,
}) {
  final tariff = state.rentTariffs[rent.country];
  final extendable = rent.extension && tariff?.extend == 1;
  final confirmed = rent._status == 1;
  final start = rent.tzid;
  final minutes = confirmed ? rent._days * 24 * 60 : _rentFirstSmsMinutes;
  return {
    'status': rent._status,
    'extension': rent.extension ? 1 : 0,
    'messages': [
      for (final m in rent._messages.reversed)
        {
          'id': m.id,
          'service': m.service,
          'text': m.text,
          // A notice about a prohibited sender carries the integer 0, other
          // SMS a string ('' without a code).
          'code': m.service == _notify ? 0 : m.code ?? '',
          'created_at': m.createdAt,
        },
    ],
    'webhook_url': state.webhookUrl,
    'sum': stringSum ? _decimal(_toMills(rent._sum), 2) : rent._sum,
    'country': rent.country,
    'start_time': _stamp(start),
    'stop_time': _stamp(start + minutes * 60),
    'checked_time': _stamp(start),
    'number': rent.number,
    'days_autoextend': rent.initialDays,
    'rent': rent._days,
    'tzid': rent.tzid,
    'time': minutes,
    'days': confirmed ? rent._days : 0,
    'hours': confirmed ? rent._days * 24 : 0,
    'extend': extendable
        ? {for (final e in tariff!.days.entries) '${e.key}': e.value}
        : <Object?>[],
    'checked': confirmed,
    'reload': rent.country == 7 ? 0 : null,
    'day_extend': extendable ? tariff!.days[1] ?? 0 : 0,
    'm_ext': false,
    'freeze': false,
    if (req.query.containsKey('number')) ...{
      'time_seconds': minutes * 60,
      'guard_interval_remaining_seconds':
          !confirmed && rent._messages.isEmpty ? state.guardInterval : 0,
    },
  };
}

Object? _getRentNum(_MockState state, MockRequest req) {
  final country = _int(req, 'country', 7);
  final tariff = state.rentTariffs[country];
  if (tariff == null) return _error('UNDEFINED_COUNTRY');
  final days = _int(req, 'days', 1);
  final price = tariff.days[days];
  if (price == null) return _error('UNDEFINED_DAYS');
  if (state.available < _toMills(price)) return _error('WARNING_LOW_BALANCE');
  final tzid = state.nextId();
  // Reserved, not charged: the first SMS that is not `notify` confirms the
  // rent and charges it.
  state.frozen += _toMills(price);
  final rent = MockRent._(
    tzid: tzid,
    country: country,
    number: _MockState.shortNumber(tzid),
    days: days,
    sum: price,
    // `extension` defaults to 1 on the server; `0` makes the rent
    // non-extendable for good.
    extension: req.query['extension'] != '0',
  );
  state.rents[tzid] = rent;
  return {'response': 1, 'item': _rentItem(state, rent, req)};
}

Object? _getRentState(_MockState state, MockRequest req) {
  final rents = req.query.containsKey('tzid')
      ? [if (state.rents[_int(req, 'tzid', -1)] case final r?) r]
      : state.rents.values.toList();
  for (final rent in rents) {
    state.poll(rent.tzid);
  }
  return {
    'response': 1,
    'list': [for (final r in rents) _rentItem(state, r, req, stringSum: true)],
  };
}

Object? _extendRentState(_MockState state, MockRequest req) {
  // Every refusal is TRY_AGAIN_LATER, like the backend: unknown tzid,
  // unconfirmed rent, not extendable, unknown days.
  final rent = state.rents[_int(req, 'tzid', 0)];
  final tariff = rent == null ? null : state.rentTariffs[rent.country];
  if (rent == null ||
      tariff == null ||
      rent._status != 1 ||
      !rent.extension ||
      tariff.extend != 1) {
    return _error('TRY_AGAIN_LATER');
  }
  final days = _int(req, 'days', 1);
  final price = tariff.days[days];
  if (price == null) return _error('TRY_AGAIN_LATER');
  if (state.available < _toMills(price)) return _error('WARNING_LOW_BALANCE');
  state.balance -= _toMills(price);
  rent._days += days;
  rent._sum = _fromMills(_toMills(rent._sum) + _toMills(price));
  return {'response': 1, 'item': _rentItem(state, rent, req)};
}

Object? _closeRentNum(_MockState state, MockRequest req) {
  final tzid = _int(req, 'tzid', 0);
  final rent = state.rents[tzid];
  if (rent == null) return _error('ERROR_NO_OPERATIONS');
  if (rent._status == 0) {
    // `guardInterval` stands in for the backend's first 120 s, during which a
    // rent without any SMS stays open.
    if (rent._messages.isEmpty && state.guardInterval > 0) {
      return _error('NO_COMPLETE_TZID');
    }
    // Unconfirmed (no SMS or only `notify`): the reservation is released.
    state.frozen -= _toMills(rent._sum);
  }
  // A confirmed rent closes without a refund.
  state.rents.remove(tzid);
  state.scheduled.remove(tzid);
  return {'response': '1'};
}

Object? _tariffsRent(_MockState state, MockRequest req) {
  Object? tariff(int code) {
    final t = state.rentTariffs[code];
    if (t == null) return <Object?>[];
    final (name, _) = _countryName(code);
    final count = {for (final d in t.days.keys) '$d': 100};
    return {
      'code': code,
      'enabled': true,
      'name': name,
      'new': false,
      'position': code,
      'count': count,
      'days': {for (final e in t.days.entries) '${e.key}': e.value},
      'extend': t.extend,
      'confirm': false,
      'ext_counts': count,
    };
  }

  if (req.query.containsKey('country')) return tariff(_int(req, 'country', 0));
  if (state.rentTariffs.isEmpty) return <Object?>[];
  return {for (final code in state.rentTariffs.keys) '$code': tariff(code)};
}

// ----- user -----

Object? _getBalance(_MockState state, MockRequest req) => {
      'response': '1',
      'balance': _decimal(state.balance),
      'zbalance': _fromMills(state.frozen),
      if (req.query.containsKey('income')) ...{
        'income': 0,
        'income_usd': '0.000',
      },
    };

Object? _getProfile(_MockState state, MockRequest req) => {
      'response': '1',
      'profile': {
        'id': _userId,
        'hash_id': 'mock',
        'name': 'mock@example.com',
        'username': 'mock@example.com',
        'email': 'mock@example.com',
        'email_verified_at': _stamp(),
        'active': 'true',
        'apikey': state.apiKey,
        'api_access': true,
        'is_api': true,
        'number': null,
        'country': null,
        'locale': 'en',
        'currency': 'USD',
        'number_region': null,
        'number_country': null,
        'number_reject': <Object?>[],
        'ugroup': 1,
        'verify': 0,
        'block': 0,
        'resetCount': null,
        'created_at': _stamp(),
        'notification_at': null,
        'first_login': false,
        'sub': 0,
        'disable': false,
        'webhook_url': state.webhookUrl,
        'is_project_subscription': false,
      },
    };

/// The backend accepts any `scheme://…` URL.
final _url = RegExp(r'^[a-z][a-z0-9+.-]*://\S+$', caseSensitive: false);

Object? _profile(_MockState state, MockRequest req) {
  final body = req.body;
  final profile = body is Map ? body['profile'] : null;
  if (req.method != 'POST' || profile is! Map) return _error('ERROR_PARAMS');
  final url = profile['webhook_url'];
  if (url != null && (url is! String || !_url.hasMatch(url))) {
    return {
      'response': {
        'webhook_url': ['The webhook url must be a valid URL.'],
      },
    };
  }
  if (profile.containsKey('webhook_url')) state.webhookUrl = url as String?;
  return {
    'response': '1',
    'user': {'id': _userId, 'webhook_url': state.webhookUrl},
  };
}

Object? _webhookLogs(_MockState state, MockRequest req) => {
      'response': '1',
      'data': _paginate(
        state.webhookLogs.reversed.toList(),
        _int(req, 'page', 1),
        10,
        'webhook-logs',
      ),
    };

Object? _getPaymentHistory(_MockState state, MockRequest req) => {
      'response': '1',
      'orders': _paginate(
        const [],
        _int(req, 'page', 1),
        10,
        'getPaymentHistory.php',
      ),
      'paylist': <Object?>[],
      'domains': ['onlinesim.io'],
      'forms': {'1': 'Card'},
      'currency': {'USD': 1},
      'buttons': {
        'USD': [5, 10, 20],
      },
    };

// ----- free -----

/// `ignore` of getFreeList: a note about prohibited services and their ids.
const _freeIgnore =
    '<p>Messages from these services are not shown:</p><p>1,2,3</p>';

// Country 44 first, like the backend's list.
const _free = {
  44: (
    name: 'united_kingdom',
    text: 'United Kingdom',
    numbers: {
      '7459608320': [
        ('Amazon', 'Amazon: Use 195895 to reset your password.'),
        ('Microsoft', 'Microsoft access code: 2991'),
      ],
    },
  ),
  7: (
    name: 'russia',
    text: 'Russia',
    numbers: {
      '9001234567': [('Telegram', 'Telegram code: 51423')],
    },
  ),
};

Object? _getFreeList(_MockState state, MockRequest req) {
  final codes = _free.keys.toList(); // 44 first, as the backend lists them
  final wanted = _int(req, 'country', 44);
  final country = _free.containsKey(wanted) ? wanted : codes.first;
  final count = _int(req, 'count', 10).clamp(10, 500);
  final page = _int(req, 'page', 1).clamp(1, 1 << 31);
  final data = _free[country]!;
  final numbers = {
    for (final n in data.numbers.keys)
      n: {
        'country': country,
        'country_original': data.name,
        'data_humans': '1 day ago',
        'full_number': '$country$n',
        'is_archive': false,
      },
  };
  final asked = req.query['number'];
  final number = asked != null && data.numbers.containsKey(asked)
      ? asked
      : data.numbers.keys.first;
  final sms = data.numbers[number]!;
  final messages = [
    for (var i = 0; i < sms.length; i++)
      {
        'id': i + 1,
        'text': sms[i].$2,
        'in_number': sms[i].$1,
        'my_number': number,
        'created_at': _iso(i),
        'data_humans': '1 day ago',
        'code': _extractCode(sms[i].$2) ?? '-',
      },
  ];
  return {
    'response': 1,
    'countries': [
      for (final c in codes)
        {
          'country': c,
          'country_text': _free[c]!.text,
          'country_original': _free[c]!.name,
        },
    ],
    'numbers': numbers,
    'messages': {
      ..._paginate(messages, page, count, 'getFreeList'),
      'number': number,
      'country': country,
    },
    'ignore': _freeIgnore,
    'content': null,
  };
}

const Map<String, _Handler> _routes = {
  'getPrice.php': _getPrice,
  'getNum.php': _getNum,
  'getState.php': _getState,
  'setOperationRevise.php': _setOperationRevise,
  'setOperationOk.php': _setOperationOk,
  'getNumbersStats.php': _getNumbersStats,
  'rent/getRentNum.php': _getRentNum,
  'rent/getRentState.php': _getRentState,
  'rent/extendRentState.php': _extendRentState,
  'rent/closeRentNum.php': _closeRentNum,
  'rent/tariffsRent.php': _tariffsRent,
  'getBalance.php': _getBalance,
  'getProfile.php': _getProfile,
  'profile.php': _profile,
  'webhook-logs': _webhookLogs,
  'getPaymentHistory.php': _getPaymentHistory,
  'getFreeList': _getFreeList,
};
