import 'package:flutter/foundation.dart';

/// Mirrors `public.reward_type_enum` in `backend/db/structure.sql`.
enum RewardType { discountPercent, freeItem, cashback, other }

/// JSON (de)serialization for [RewardType] against `reward_type_enum`.
extension RewardTypeJson on RewardType {
  static RewardType fromJson(String value) => switch (value) {
    'discount_percent' => RewardType.discountPercent,
    'free_item' => RewardType.freeItem,
    'cashback' => RewardType.cashback,
    'other' => RewardType.other,
    _ => throw ArgumentError('Unknown reward_type_enum value: $value'),
  };

  String toJson() => switch (this) {
    RewardType.discountPercent => 'discount_percent',
    RewardType.freeItem => 'free_item',
    RewardType.cashback => 'cashback',
    RewardType.other => 'other',
  };
}

/// Domain model for `public.loyalty_rules`.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class LoyaltyRule {
  const LoyaltyRule({
    required this.id,
    required this.merchantId,
    required this.visitsRequired,
    required this.rewardType,
    required this.rewardDescription,
    required this.isPermanent,
  });

  final int id;
  final int merchantId;
  final int visitsRequired;
  final RewardType rewardType;
  final String rewardDescription;
  final bool isPermanent;

  factory LoyaltyRule.fromJson(Map<String, dynamic> json) {
    return LoyaltyRule(
      id: json['id'] as int,
      merchantId: json['merchant_id'] as int,
      visitsRequired: json['visits_required'] as int,
      rewardType: RewardTypeJson.fromJson(json['reward_type'] as String),
      rewardDescription: json['reward_description'] as String,
      isPermanent: json['is_permanent'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'visits_required': visitsRequired,
      'reward_type': rewardType.toJson(),
      'reward_description': rewardDescription,
      'is_permanent': isPermanent,
    };
  }
}
