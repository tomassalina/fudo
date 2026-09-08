import 'package:flutter/foundation.dart';

/// Domain model for `public.visits`.
///
/// NOTE: `visits.id` is a `bigint` (serial) primary key, NOT a uuid — only
/// `consumer_id` is a uuid (foreign key into `consumers`, whose own `id` is
/// the uuid primary key). Confirmed against `backend/db/structure.sql`.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class Visit {
  const Visit({
    required this.id,
    required this.consumerId,
    required this.merchantId,
    required this.amount,
    required this.rewardApplied,
    this.rewardDescriptionSnapshot,
    required this.visitedAt,
  });

  final int id;
  final String consumerId;
  final int merchantId;
  final double amount;
  final bool rewardApplied;
  final String? rewardDescriptionSnapshot;
  final DateTime visitedAt;

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as int,
      consumerId: json['consumer_id'] as String,
      merchantId: json['merchant_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      rewardApplied: json['reward_applied'] as bool,
      rewardDescriptionSnapshot: json['reward_description_snapshot'] as String?,
      visitedAt: DateTime.parse(json['visited_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'consumer_id': consumerId,
      'merchant_id': merchantId,
      'amount': amount,
      'reward_applied': rewardApplied,
      'reward_description_snapshot': rewardDescriptionSnapshot,
      'visited_at': visitedAt.toIso8601String(),
    };
  }
}
