import 'client.dart';
import 'errors.dart';
import 'json.dart';
import 'models/rent.dart';

// Always sent: a flat `messages` list and `time_seconds`.
const _detail = {'pagination': 0, 'number': 1};

/// Rented numbers: `client.rent`.
final class RentApi {
  /// Internal: the client builds its sections.
  RentApi(this._request);

  final RequestFn _request;

  /// Rents a number for [days] days. The price is reserved (it shows in
  /// `zbalance`) and the rent starts with `status` 0; the first SMS that is
  /// not `notify` confirms it and charges the price. `extension: false` makes
  /// the rent non-extendable for good.
  Future<RentItem> get({
    int country = 7,
    int days = 1,
    bool extension = true,
  }) async {
    final res = asMap(await _request('rent/getRentNum.php', query: {
      'country': country,
      'days': days,
      'extension': extension,
      ..._detail,
    }));
    return RentItem.fromJson(asMap(res['item']));
  }

  /// All rents of the account.
  Future<List<RentItem>> state() async {
    final res = asMap(await _request('rent/getRentState.php', query: _detail));
    return objects(res['list'], RentItem.fromJson);
  }

  /// One rent. Throws `ApiException('ERROR_NO_OPERATIONS')` when it does not
  /// exist.
  Future<RentItem> stateOne(int tzid) async {
    final res = asMap(await _request(
      'rent/getRentState.php',
      query: {'tzid': tzid, ..._detail},
    ));
    final list = objects(res['list'], RentItem.fromJson);
    if (list.isEmpty) throw ApiException('ERROR_NO_OPERATIONS');
    return list.first;
  }

  /// Extends a rent by [days] days and charges at once. Only confirmed rents
  /// created with `extension: true`; every refusal is
  /// `ApiException('TRY_AGAIN_LATER')`.
  Future<RentItem> extend(int tzid, {int days = 1}) async {
    final res = asMap(await _request(
      'rent/extendRentState.php',
      query: {'tzid': tzid, 'days': days, ..._detail},
    ));
    return RentItem.fromJson(asMap(res['item']));
  }

  /// Rent prices of every country, keyed by country code. No key needed.
  Future<Map<int, RentTariff>> tariffs() async {
    final res = await _request('rent/tariffsRent.php');
    return intKeyed(
      res,
      (v) => v is Map ? RentTariff.fromJson(asMap(v)) : null,
    );
  }

  /// Rent prices of one country. Throws `ApiException('NO_COUNTRY')` for a
  /// country without rent. No key needed.
  Future<RentTariff> tariffsOne({int country = 7}) async {
    final res =
        await _request('rent/tariffsRent.php', query: {'country': country});
    // An unknown country answers `[]`.
    if (res is! Map || !res.containsKey('code')) {
      throw ApiException('NO_COUNTRY');
    }
    return RentTariff.fromJson(asMap(res));
  }

  /// Returns the number before the rent period ends. An unconfirmed rent
  /// (`status` 0, no SMS or only `notify`) releases its reservation; a
  /// confirmed one closes without a refund. Throws
  /// `ApiException('ERROR_NO_OPERATIONS')` for an unknown tzid.
  Future<void> close(int tzid) async {
    await _request('rent/closeRentNum.php', query: {'tzid': tzid});
  }
}
