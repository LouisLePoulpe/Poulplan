import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../calendar/day.dart';

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ñ': 'n',
  'œ': 'oe',
  'æ': 'ae',
  'ß': 'ss',
};

/// Lowercase, accent-free, single-spaced text used for searching.
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A search with optional filters; serializable to save it as a filter.
@immutable
class SearchQuery {
  SearchQuery({
    this.text = '',
    Set<String> categoryIds = const {},
    this.from,
    this.to,
  }) : categoryIds = Set.unmodifiable(categoryIds);

  factory SearchQuery.fromJson(Map<String, dynamic> json) => SearchQuery(
    text: json['text'] as String? ?? '',
    categoryIds: {...(json['categories'] as List? ?? const []).cast<String>()},
    from: json['from'] == null ? null : Day.parse(json['from'] as String),
    to: json['to'] == null ? null : Day.parse(json['to'] as String),
  );

  final String text;
  final Set<String> categoryIds;
  final Day? from;
  final Day? to;

  /// Normalized words that must all appear.
  List<String> get tokens =>
      normalizeForSearch(text).split(' ').where((t) => t.isNotEmpty).toList();

  bool get isEmpty =>
      tokens.isEmpty && categoryIds.isEmpty && from == null && to == null;

  bool matchesText(String haystack) {
    final normalized = normalizeForSearch(haystack);
    return tokens.every(normalized.contains);
  }

  SearchQuery copyWith({
    String? text,
    Set<String>? categoryIds,
    Day? Function()? from,
    Day? Function()? to,
  }) => SearchQuery(
    text: text ?? this.text,
    categoryIds: categoryIds ?? this.categoryIds,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    if (categoryIds.isNotEmpty) 'categories': categoryIds.toList()..sort(),
    if (from != null) 'from': from.toString(),
    if (to != null) 'to': to.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      const SetEquality<String>().equals(other.categoryIds, categoryIds) &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(
    text,
    const SetEquality<String>().hash(categoryIds),
    from,
    to,
  );
}
