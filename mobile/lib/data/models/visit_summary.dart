import 'package:flutter/foundation.dart';

/// Domain model for `public.visit_summaries`.
///
/// NOTE: `visit_summaries.id` is a `bigint` (serial) primary key, NOT a
/// uuid — only `consumer_id` is a uuid (foreign key into `consumers`).
/// Confirmed against `backend/db/structure.sql`.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class VisitSummary {
  const VisitSummary({
    required this.id,
    required this.consumerId,
    required this.merchantId,
    required this.count,
    this.currentTier,
    this.lastVisitAt,
  });

  final int id;
  final String consumerId;
  final int merchantId;
  final int count;
  final String? currentTier;
  final DateTime? lastVisitAt;

  factory VisitSummary.fromJson(Map<String, dynamic> json) {
    return VisitSummary(
      id: json['id'] as int,
      consumerId: json['consumer_id'] as String,
      merchantId: json['merchant_id'] as int,
      count: json['count'] as int,
      currentTier: json['current_tier'] as String?,
      lastVisitAt: json['last_visit_at'] == null
          ? null
          : DateTime.parse(json['last_visit_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consumer_id': consumerId,
      'merchant_id': merchantId,
      'count': count,
      'current_tier': currentTier,
      'last_visit_at': lastVisitAt?.toIso8601String(),
    };
  }
}
