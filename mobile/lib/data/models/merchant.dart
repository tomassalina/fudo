import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Mirrors `public.merchant_type_enum` in `backend/db/structure.sql`.
///
/// Postgres values are snake_case (`dark_kitchen`, `food_truck`); see
/// [MerchantTypeJson] for the mapping used by [Merchant.fromJson]/[toJson].
enum MerchantType {
  restaurant,
  cafe,
  bar,
  darkKitchen,
  pizzeria,
  brewery,
  foodTruck,
  other,
}

/// JSON (de)serialization for [MerchantType] against `merchant_type_enum`.
extension MerchantTypeJson on MerchantType {
  static MerchantType fromJson(String value) => switch (value) {
    'restaurant' => MerchantType.restaurant,
    'cafe' => MerchantType.cafe,
    'bar' => MerchantType.bar,
    'dark_kitchen' => MerchantType.darkKitchen,
    'pizzeria' => MerchantType.pizzeria,
    'brewery' => MerchantType.brewery,
    'food_truck' => MerchantType.foodTruck,
    'other' => MerchantType.other,
    _ => throw ArgumentError('Unknown merchant_type_enum value: $value'),
  };

  String toJson() => switch (this) {
    MerchantType.restaurant => 'restaurant',
    MerchantType.cafe => 'cafe',
    MerchantType.bar => 'bar',
    MerchantType.darkKitchen => 'dark_kitchen',
    MerchantType.pizzeria => 'pizzeria',
    MerchantType.brewery => 'brewery',
    MerchantType.foodTruck => 'food_truck',
    MerchantType.other => 'other',
  };
}

/// Presentation data for [MerchantType] (map pins, badges), taken from the
/// design brief §1 "Colores por tipo de local" — not part of the schema.
extension MerchantTypePresentation on MerchantType {
  /// Material Symbols Outlined icon for this merchant type.
  IconData get icon => switch (this) {
    MerchantType.restaurant => Symbols.restaurant,
    MerchantType.pizzeria => Symbols.local_pizza,
    MerchantType.foodTruck => Symbols.local_shipping,
    MerchantType.cafe => Symbols.local_cafe,
    MerchantType.darkKitchen => Symbols.takeout_dining,
    MerchantType.bar => Symbols.local_bar,
    MerchantType.brewery => Symbols.sports_bar,
    // `other` has no icon/color in the design (TYPES map only covers 7
    // types) — default chosen here: a generic storefront icon.
    MerchantType.other => Symbols.storefront,
  };

  /// Accent color for this merchant type.
  Color get color => switch (this) {
    MerchantType.restaurant ||
    MerchantType.pizzeria ||
    MerchantType.foodTruck => const Color(0xFFFF5023),
    MerchantType.cafe || MerchantType.darkKitchen => const Color(0xFF8FD46A),
    MerchantType.bar || MerchantType.brewery => const Color(0xFF7B7BE0),
    // `other` default: neutral gray, distinct from the three design
    // palette accents (not specified by the design brief).
    MerchantType.other => const Color(0xFF9AA0A6),
  };
}

/// Domain model for `public.merchants`.
///
/// Only "columnas clave" per the design brief §1.5 are modeled here — Rails
/// audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out of the mobile domain layer.
@immutable
class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.country,
    required this.state,
    required this.city,
    this.neighborhood,
    this.zipCode,
    required this.latitude,
    required this.longitude,
    this.coverImageUrl,
    this.whatsappNumber,
    this.deliveryUrl,
    this.pricePerPersonMin,
    this.pricePerPersonMax,
  });

  final int id;
  final String name;
  final MerchantType type;
  final String address;
  final String country;
  final String state;
  final String city;
  final String? neighborhood;
  final String? zipCode;
  final double latitude;
  final double longitude;
  final String? coverImageUrl;
  final String? whatsappNumber;
  final String? deliveryUrl;
  final double? pricePerPersonMin;
  final double? pricePerPersonMax;

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] as int,
      name: json['name'] as String,
      type: MerchantTypeJson.fromJson(json['type'] as String),
      address: json['address'] as String,
      country: json['country'] as String,
      state: json['state'] as String,
      city: json['city'] as String,
      neighborhood: json['neighborhood'] as String?,
      zipCode: json['zip_code'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      coverImageUrl: json['cover_image_url'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      deliveryUrl: json['delivery_url'] as String?,
      pricePerPersonMin: (json['price_per_person_min'] as num?)?.toDouble(),
      pricePerPersonMax: (json['price_per_person_max'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toJson(),
      'address': address,
      'country': country,
      'state': state,
      'city': city,
      'neighborhood': neighborhood,
      'zip_code': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'cover_image_url': coverImageUrl,
      'whatsapp_number': whatsappNumber,
      'delivery_url': deliveryUrl,
      'price_per_person_min': pricePerPersonMin,
      'price_per_person_max': pricePerPersonMax,
    };
  }
}
