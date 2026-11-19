part of 'mock.dart';

/// Number prices: country code → service slug → USD.
typedef MockPrices = Map<int, Map<String, double>>;

/// Rent tariff of one country: rent days → USD, and whether rents can be
/// extended (`1`) or not (`0`).
final class MockRentTariff {
  /// Creates a tariff.
  const MockRentTariff({required this.days, this.extend = 1});

  /// Rent days → price, USD.
  final Map<int, double> days;

  /// `1`: rents of this country can be extended; `0`: they cannot.
  final int extend;
}

/// One SMS received by an operation or a rent.
final class MockSms {
  const MockSms._({
    required this.service,
    required this.text,
    required this.code,
    this.id,
    this.createdAt,
  });

  /// Service of the SMS.
  final String service;

  /// Full text.
  final String text;

  /// Code extracted from [text] (first run of 4–8 digits), `null` when none.
  final String? code;

  /// Message id (rent SMS only).
  final int? id;

  /// Arrival time (rent SMS only).
  final String? createdAt;
}

/// A number operation as the mock stores it (a snapshot).
final class MockOperation {
  MockOperation._({
    required this.tzid,
    required this.service,
    required this.country,
    required this.number,
    required this.sum,
  });

  /// Operation id.
  final int tzid;

  /// Service slug.
  final String service;

  /// Country code.
  final int country;

  /// Full number with `+`.
  final String number;

  /// Price, USD. Frozen while open; spent on close after an SMS, refunded on
  /// close without one.
  final double sum;

  String _status = OperationStatus.numWait;
  final List<MockSms> _messages = [];
  int _cursor = 0;

  /// `TZ_NUM_WAIT`, `TZ_NUM_ANSWER` or `TZ_OVER_OK`.
  String get status => _status;

  /// SMS received, oldest first.
  List<MockSms> get messages => List.unmodifiable(_messages);

  /// Index of the SMS shown in `msg`; `next` moves it past the last one.
  int get cursor => _cursor;

  MockOperation _copy() => MockOperation._(
        tzid: tzid,
        service: service,
        country: country,
        number: number,
        sum: sum,
      )
        .._status = _status
        .._messages.addAll(_messages)
        .._cursor = _cursor;
}

/// A rent as the mock stores it (a snapshot). Closed rents are removed.
final class MockRent {
  MockRent._({
    required this.tzid,
    required this.country,
    required this.number,
    required int days,
    required double sum,
    required this.extension,
  })  : _days = days,
        _sum = sum;

  /// Rent id.
  final int tzid;

  /// Country code.
  final int country;

  /// Number without the country code, as the backend sends it for rents.
  final String number;

  /// Created extendable.
  final bool extension;

  int _days;
  double _sum;
  final List<MockSms> _messages = [];

  /// Rent period, days (grows with `extend`).
  int get days => _days;

  /// Total paid, USD.
  double get sum => _sum;

  /// SMS received, oldest first.
  List<MockSms> get messages => List.unmodifiable(_messages);

  MockRent _copy() => MockRent._(
        tzid: tzid,
        country: country,
        number: number,
        days: _days,
        sum: _sum,
        extension: extension,
      ).._messages.addAll(_messages);
}

/// One request the mock received.
final class MockRequest {
  /// Creates a log entry.
  const MockRequest({
    required this.method,
    required this.path,
    required this.query,
    this.body,
  });

  /// `GET` or `POST`.
  final String method;

  /// Path relative to `/api/`, e.g. `getNum.php`, `rent/getRentNum.php`,
  /// `getFreeList`.
  final String path;

  /// Query parameters.
  final Map<String, String> query;

  /// Decoded JSON body of a `POST`, `null` for `GET`.
  final Object? body;

  @override
  String toString() =>
      'MockRequest($method $path $query${body == null ? '' : ' $body'})';
}

/// A queued failure: the next matching request answers `{"response": code}`,
/// or a non-JSON HTTP [status].
final class _Failure {
  const _Failure({this.endpoint, this.code, this.status});

  final String? endpoint;
  final String? code;
  final int? status;
}

final class _Scheduled {
  _Scheduled(this.text, this.service, this.polls);

  final String text;
  final String? service;

  /// State polls of this tzid still to pass before the SMS arrives.
  int polls;
}

/// Default number prices of the mock.
const MockPrices defaultMockPrices = {
  7: {'vkcom': 0.5, 'telegram': 1.2, 'google': 0.3},
  44: {'google': 0.2, 'vkcom': 0.36},
};

/// Default rent tariffs of the mock.
const Map<int, MockRentTariff> defaultMockRentTariffs = {
  7: MockRentTariff(days: {1: 1.0, 3: 2.5, 7: 5.0}),
};

const _userId = 1;

/// Seconds an operation stays open, as reported in `time`. The mock has no
/// clock, so it never runs down.
const _operationTime = 1200;

final _epoch = DateTime.utc(2026);

/// `YYYY-MM-DD HH:MM:SS` at [seconds] after the fixed mock epoch.
String _stamp([int seconds = 0]) => _epoch
    .add(Duration(seconds: seconds))
    .toIso8601String()
    .substring(0, 19)
    .replaceFirst('T', ' ');

final _digitGap = RegExp(r'(\d)[\s-]+(?=\d)');
final _codeRun = RegExp(r'(?<!\d)\d{4,8}(?!\d)');

/// The code rule shared by every SDK mock: dashes/spaces between digits are
/// removed, then the first run of 4–8 digits (not part of a longer run) is
/// the code; `null` when there is none.
String? _extractCode(String text) => _codeRun
    .firstMatch(text.replaceAllMapped(_digitGap, (m) => m[1]!))
    ?.group(0);

int _toMills(double usd) => (usd * 1000).round();
double _fromMills(int mills) => mills / 1000;

/// The single owner of everything the fake API remembers: balance,
/// operations, rents, the webhook URL and its delivery log, scheduled SMS,
/// the failure queue and the request log. Handlers change it only through
/// this object. Money is kept in integer thousandths of a USD ("mills").
final class _MockState {
  _MockState({
    required this.apiKey,
    required this.guardInterval,
    required this.prices,
    required this.rentTariffs,
    required int balanceMills,
  }) : _startBalance = balanceMills {
    reset();
  }

  final String apiKey;
  final int guardInterval;
  final MockPrices prices;
  final Map<int, MockRentTariff> rentTariffs;
  final int _startBalance;

  /// Total balance incl. the frozen part, mills.
  int balance = 0;

  /// Frozen by open operations, mills.
  int frozen = 0;
  final Map<int, MockOperation> operations = {};
  final Map<int, MockRent> rents = {};
  String? webhookUrl;
  final List<Map<String, Object?>> webhookLogs = [];
  final List<MockRequest> requests = [];
  final List<_Failure> failures = [];
  final Map<int, List<_Scheduled>> scheduled = {};

  /// Source of tzids, numbers, message ids and timestamps.
  int seq = 0;

  void reset() {
    balance = _startBalance;
    frozen = 0;
    operations.clear();
    rents.clear();
    webhookUrl = null;
    webhookLogs.clear();
    requests.clear();
    failures.clear();
    scheduled.clear();
    seq = 0;
  }

  /// Available balance (total minus frozen), mills.
  int get available => balance - frozen;

  /// The id the next operation/rent will get.
  int peekId() => seq + 1;

  int nextId() => ++seq;

  /// Short (country-less) number for an id: deterministic, 9 digits.
  static String shortNumber(int id) => '${900000000 + id}';

  /// Removes and returns the first queued failure that applies to [path].
  _Failure? takeFailure(String path) {
    final i =
        failures.indexWhere((f) => f.endpoint == null || f.endpoint == path);
    return i < 0 ? null : failures.removeAt(i);
  }

  /// An SMS arrives at operation or rent [tzid] now. `false` when there is no
  /// open one.
  bool deliver(int tzid, String text, String? service) {
    final code = _extractCode(text);
    final op = operations[tzid];
    if (op != null && op._status != OperationStatus.overOk) {
      final sms =
          MockSms._(service: service ?? op.service, text: text, code: code);
      op._messages.add(sms);
      op._status = OperationStatus.numAnswer;
      _webhook('receiving_sms', tzid, op.country, op.number, sms);
      return true;
    }
    final rent = rents[tzid];
    if (rent != null) {
      final id = nextId();
      final sms = MockSms._(
        service: service ?? 'other',
        text: text,
        code: code,
        id: id,
        createdAt: _stamp(id),
      );
      rent._messages.add(sms);
      _webhook('rent_sms', tzid, rent.country, rent.number, sms);
      return true;
    }
    return false;
  }

  void schedule(int tzid, String text, int polls, String? service) {
    scheduled.putIfAbsent(tzid, () => []).add(_Scheduled(text, service, polls));
  }

  /// One state poll of [tzid]: delivers the scheduled SMS whose polls ran
  /// out, counts down the rest.
  void poll(int tzid) {
    final list = scheduled[tzid];
    if (list == null) return;
    final due = list.where((s) => s.polls <= 0).toList();
    final rest = list.where((s) => s.polls > 0).toList();
    for (final s in rest) {
      s.polls--;
    }
    if (rest.isEmpty) {
      scheduled.remove(tzid);
    } else {
      scheduled[tzid] = rest;
    }
    // Dropped silently when the operation was closed meanwhile: a real SMS
    // would not arrive either.
    for (final s in due) {
      deliver(tzid, s.text, s.service);
    }
  }

  /// No HTTP call: the mock only records what the backend would have sent.
  void _webhook(
      String type, int tzid, int country, String number, MockSms sms) {
    final url = webhookUrl;
    if (url == null) return;
    final time = _stamp(seq);
    webhookLogs.add({
      'id': webhookLogs.length + 1,
      'user_id': _userId,
      'webhook_url': url,
      'type': type,
      'params': {
        'webhook_type': type,
        'operation_id': tzid,
        'user_id': _userId,
        'country_code': country,
        'number': number,
        'sender': sms.service,
        'message': sms.text,
        'code': sms.code,
        'time_start': time,
        'time_left': _operationTime,
      },
      'status': 'success',
      'error': null,
      'created_at': time,
      'updated_at': time,
    });
  }
}
