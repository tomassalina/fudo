import 'package:flutter/foundation.dart';

/// Domain model for `public.search_history`.
///
/// NOTE: `search_history.id` is a `bigint` (serial) primary key, NOT a
/// uuid — only `consumer_id` is a uuid (foreign key into `consumers`).
/// Confirmed against `backend/db/structure.sql`.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class SearchHistory {
  const SearchHistory({
    required this.id,
    required this.consumerId,
    required this.queryText,
    this.structuredOutput,
  });

  final int id;
  final String consumerId;
  final String queryText;

  /// Maps `structured_output`, a nullable `jsonb` column with no fixed
  /// schema (e.g. parsed search intent/filters).
  final Map<String, dynamic>? structuredOutput;

  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      id: json['id'] as int,
      consumerId: json['consumer_id'] as String,
      queryText: json['query_text'] as String,
      structuredOutput: json['structured_output'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consumer_id': consumerId,
      'query_text': queryText,
      'structured_output': structuredOutput,
    };
  }
}
