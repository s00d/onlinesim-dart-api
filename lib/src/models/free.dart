import '../json.dart';
import 'paginator.dart';

/// A country with free numbers.
final class FreeCountry {
  /// Creates a country entry.
  const FreeCountry({
    required this.country,
    required this.countryText,
    required this.countryOriginal,
  });

  /// Parses a `countries` item.
  factory FreeCountry.fromJson(Map<String, Object?> json) => FreeCountry(
        country: asInt(json['country']) ?? 0,
        countryText: asString(json['country_text']) ?? '',
        countryOriginal: asString(json['country_original']) ?? '',
      );

  /// Country code.
  final int country;

  /// Localised name.
  final String countryText;

  /// Name (slug).
  final String countryOriginal;
}

/// A free number.
final class FreeNumber {
  /// Creates a number entry.
  const FreeNumber({
    required this.country,
    required this.countryOriginal,
    required this.fullNumber,
    required this.dataHumans,
    required this.isArchive,
  });

  /// Parses a `numbers` value.
  factory FreeNumber.fromJson(Map<String, Object?> json) => FreeNumber(
        country: asInt(json['country']) ?? 0,
        countryOriginal: asString(json['country_original']) ?? '',
        fullNumber: asString(json['full_number']) ?? '',
        dataHumans: asString(json['data_humans']) ?? '',
        isArchive: asBool(json['is_archive']),
      );

  /// Country code.
  final int country;

  /// Country name (slug).
  final String countryOriginal;

  /// Number with the country code, without `+`.
  final String fullNumber;

  /// Age of the last SMS, human readable.
  final String dataHumans;

  /// Archived number.
  final bool isArchive;
}

/// An SMS of a free number.
final class FreeMessage {
  /// Creates a message.
  const FreeMessage({
    required this.id,
    required this.text,
    required this.inNumber,
    required this.myNumber,
    required this.code,
    required this.createdAt,
    required this.dataHumans,
  });

  /// Parses a `messages.data` item.
  factory FreeMessage.fromJson(Map<String, Object?> json) => FreeMessage(
        id: asInt(json['id']) ?? 0,
        text: asString(json['text']) ?? '',
        inNumber: asString(json['in_number']) ?? '',
        myNumber: asString(json['my_number']) ?? '',
        code: asString(json['code']) ?? '',
        createdAt: asString(json['created_at']) ?? '',
        dataHumans: asString(json['data_humans']) ?? '',
      );

  /// Message id.
  final int id;

  /// Full text.
  final String text;

  /// Sender.
  final String inNumber;

  /// The free number (short form).
  final String myNumber;

  /// Code; `-` when none was found.
  final String code;

  /// Arrival time.
  final String createdAt;

  /// Age, human readable.
  final String dataHumans;
}

/// SMS page of the selected free number.
final class FreeMessages extends Paginator<FreeMessage> {
  /// Creates a page.
  const FreeMessages({
    required super.currentPage,
    required super.data,
    required super.lastPage,
    required super.perPage,
    required super.total,
    required this.country,
    super.from,
    super.to,
    super.nextPageUrl,
    super.prevPageUrl,
    this.number,
  });

  /// Parses `messages`.
  factory FreeMessages.fromJson(Map<String, Object?> json) {
    final page = Paginator.fromJson(json, FreeMessage.fromJson);
    return FreeMessages(
      currentPage: page.currentPage,
      data: page.data,
      from: page.from,
      to: page.to,
      lastPage: page.lastPage,
      perPage: page.perPage,
      total: page.total,
      nextPageUrl: page.nextPageUrl,
      prevPageUrl: page.prevPageUrl,
      number: asString(json['number']),
      country: asInt(json['country']) ?? 0,
    );
  }

  /// The selected number (short form).
  final String? number;

  /// The selected country.
  final int country;
}

/// Result of `free.list`.
final class FreeList {
  /// Creates a list.
  const FreeList({
    required this.countries,
    required this.numbers,
    required this.messages,
  });

  /// Parses `getFreeList`; `numbers` from `[]`.
  factory FreeList.fromJson(Map<String, Object?> json) => FreeList(
        countries: objects(json['countries'], FreeCountry.fromJson),
        numbers: stringKeyed(
          json['numbers'],
          (v) => v is Map ? FreeNumber.fromJson(asMap(v)) : null,
        ),
        messages: FreeMessages.fromJson(asMap(json['messages'])),
      );

  /// Countries with free numbers.
  final List<FreeCountry> countries;

  /// Numbers of the selected country, keyed by the number without the
  /// country code.
  final Map<String, FreeNumber> numbers;

  /// SMS of the selected number.
  final FreeMessages messages;
}
