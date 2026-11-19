import '../json.dart';

/// A Laravel paginator page.
base class Paginator<T> {
  /// Creates a page.
  const Paginator({
    required this.currentPage,
    required this.data,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.from,
    this.to,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  /// Parses a paginator; each `data` item with [item].
  factory Paginator.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?> json) item,
  ) =>
      Paginator(
        currentPage: asInt(json['current_page']) ?? 1,
        data: objects(json['data'], item),
        from: asInt(json['from']),
        to: asInt(json['to']),
        lastPage: asInt(json['last_page']) ?? 1,
        perPage: asInt(json['per_page']) ?? 0,
        total: asInt(json['total']) ?? 0,
        nextPageUrl: asString(json['next_page_url']),
        prevPageUrl: asString(json['prev_page_url']),
      );

  /// This page, from 1.
  final int currentPage;

  /// Items of this page.
  final List<T> data;

  /// Index of the first item, from 1; `null` on an empty page.
  final int? from;

  /// Index of the last item; `null` on an empty page.
  final int? to;

  /// Last page.
  final int lastPage;

  /// Items per page.
  final int perPage;

  /// Items on all pages.
  final int total;

  /// URL of the next page, if any.
  final String? nextPageUrl;

  /// URL of the previous page, if any.
  final String? prevPageUrl;
}
