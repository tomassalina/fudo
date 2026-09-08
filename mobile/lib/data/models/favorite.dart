import 'package:flutter/foundation.dart';

/// Domain model for `public.favorites`.
///
/// NOTE: `favorites.id` is a `bigint` (serial) primary key, NOT a uuid —
/// only `consumer_id` is a uuid (foreign key into `consumers`). Confirmed
/// against `backend/db/structure.sql`.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class Favorite {
  const Favorite({
    required this.id,
    required this.consumerId,
    required this.merchantId,
  });

  final int id;
  final String consumerId;
  final int merchantId;

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as int,
      consumerId: json['consumer_id'] as String,
      merchantId: json['merchant_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'consumer_id': consumerId, 'merchant_id': merchantId};
  }
}
