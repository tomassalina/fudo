import 'package:flutter/foundation.dart';

/// Mirrors `public.currency_enum` in `backend/db/structure.sql`.
enum Currency { usd, ars }

/// JSON (de)serialization for [Currency] against `currency_enum`.
extension CurrencyJson on Currency {
  static Currency fromJson(String value) => switch (value) {
    'usd' => Currency.usd,
    'ars' => Currency.ars,
    _ => throw ArgumentError('Unknown currency_enum value: $value'),
  };

  String toJson() => switch (this) {
    Currency.usd => 'usd',
    Currency.ars => 'ars',
  };
}

/// Domain model for `public.menu_items`.
///
/// Rails audit/soft-delete columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.merchantId,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.section,
    this.imageUrl,
    required this.active,
  });

  final int id;
  final int merchantId;
  final String name;
  final String? description;
  final double price;
  final Currency currency;
  final String? section;
  final String? imageUrl;
  final bool active;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int,
      merchantId: json['merchant_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: _parsePrice(json['price']),
      currency: CurrencyJson.fromJson(json['currency'] as String),
      section: json['section'] as String?,
      imageUrl: json['image_url'] as String?,
      active: json['active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency.toJson(),
      'section': section,
      'image_url': imageUrl,
      'active': active,
    };
  }
}

/// Parses `price`, which arrives as a [num] from local JSON fixtures but as
/// a [String] from the real backend API (Postgres `numeric` columns are
/// serialized as strings to avoid floating-point precision loss — confirmed
/// against `GET /api/v1/menu_items`, e.g. `"price": "24700.0"`).
double _parsePrice(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.parse(s),
  _ => throw ArgumentError('Expected num or String for price, got: $value'),
};
