import 'package:flutter/material.dart';

/// Mirrors `public.gift_type_enum` in `backend/db/structure.sql`.
///
/// The design's "custom" tier (free amount) maps to the schema's
/// `platinum` value — see design brief §1.5.
enum GiftType { classic, gold, black, platinum }

/// JSON (de)serialization for [GiftType] against `gift_type_enum`.
extension GiftTypeJson on GiftType {
  static GiftType fromJson(String value) => switch (value) {
    'classic' => GiftType.classic,
    'gold' => GiftType.gold,
    'black' => GiftType.black,
    'platinum' => GiftType.platinum,
    _ => throw ArgumentError('Unknown gift_type_enum value: $value'),
  };

  String toJson() => switch (this) {
    GiftType.classic => 'classic',
    GiftType.gold => 'gold',
    GiftType.black => 'black',
    GiftType.platinum => 'platinum',
  };
}

/// Presentation data for [GiftType] (card gradient, default amount, perk
/// copy), taken from the design brief §1 "Gradientes de gift card por
/// nivel" and the prototype's `TIERS` data (`docs/design-reference/Fudo
/// App.dc.html`). NOT part of the `gifts` schema — purely visual/product
/// copy for the gifting carousel.
extension GiftTypePresentation on GiftType {
  /// Card background gradient, matching the design token table.
  Gradient get gradient => switch (this) {
    GiftType.classic => const LinearGradient(
      begin: Alignment(-0.5, -1),
      end: Alignment(0.5, 1),
      colors: [Color(0xFFFF6337), Color(0xFFE8431A), Color(0xFFB93412)],
      stops: [0, 0.6, 1],
    ),
    GiftType.gold => const LinearGradient(
      begin: Alignment(-0.5, -1),
      end: Alignment(0.5, 1),
      colors: [Color(0xFF3B2A14), Color(0xFF7A5A1F), Color(0xFFE0B95C)],
      stops: [0, 0.45, 1],
    ),
    GiftType.black => const LinearGradient(
      begin: Alignment(-0.5, -1),
      end: Alignment(0.5, 1),
      colors: [Color(0xFF14151F), Color(0xFF23253A), Color(0xFF40435E)],
      stops: [0, 0.55, 1],
    ),
    GiftType.platinum => const LinearGradient(
      begin: Alignment(-0.5, -1),
      end: Alignment(0.5, 1),
      colors: [Color(0xFF1B1533), Color(0xFF3A2A78), Color(0xFF6E5AC8)],
      stops: [0, 0.48, 1],
    ),
  };

  /// Text color used over [gradient].
  Color get textColor => switch (this) {
    GiftType.classic => const Color(0xCCFFFFFF), // rgba(255,255,255,0.8)
    GiftType.gold => const Color(0xFFFFE9AE),
    GiftType.black => const Color(0xFFC9CCE0),
    GiftType.platinum => const Color(0xFFD6CBFF),
  };

  /// Default amount in the merchant's local currency. `platinum` has no
  /// fixed default — the design lets the user pick a custom amount between
  /// 121.000 and 1.000.000, so this is `null` for that tier.
  double? get defaultAmount => switch (this) {
    GiftType.classic => 12000,
    GiftType.gold => 40000,
    GiftType.black => 120000,
    GiftType.platinum => null,
  };

  /// Custom-amount range for `platinum` gifts; `null` for fixed-amount tiers.
  (double min, double max)? get customAmountRange => switch (this) {
    GiftType.platinum => (121000, 1000000),
    _ => null,
  };

  /// Marketing copy shown per tier in the gifting carousel.
  String get perk => switch (this) {
    GiftType.classic => 'Válida en toda la red Fudo',
    GiftType.gold => 'Sumás 2x visitas · postre de bienvenida',
    GiftType.black => 'Reservas prioritarias · premio a la 1ra visita',
    GiftType.platinum => 'Elegís el monto · concierge y mesa reservada',
  };
}

/// Mirrors `public.gift_status_enum` in `backend/db/structure.sql`.
enum GiftStatus { pending, redeemed, expired, cancelled }

/// JSON (de)serialization for [GiftStatus] against `gift_status_enum`.
extension GiftStatusJson on GiftStatus {
  static GiftStatus fromJson(String value) => switch (value) {
    'pending' => GiftStatus.pending,
    'redeemed' => GiftStatus.redeemed,
    'expired' => GiftStatus.expired,
    'cancelled' => GiftStatus.cancelled,
    _ => throw ArgumentError('Unknown gift_status_enum value: $value'),
  };

  String toJson() => switch (this) {
    GiftStatus.pending => 'pending',
    GiftStatus.redeemed => 'redeemed',
    GiftStatus.expired => 'expired',
    GiftStatus.cancelled => 'cancelled',
  };
}

/// Domain model for `public.gifts`.
///
/// NOTE: `gifts.id` is a `bigint` (serial) primary key, NOT a uuid — only
/// `sender_consumer_id`/`recipient_consumer_id` are uuids (foreign keys
/// into `consumers`). Confirmed against `backend/db/structure.sql`.
///
/// ⚠️ `GET /api/v1/gifts` (list) confirmed live to omit `recipient_phone`
/// entirely from each row — only `POST /api/v1/gifts`'s 201 response
/// includes it. Found by review: without the `?? ''` fallback below,
/// `Gift.fromJson` would throw a null-cast error the instant
/// `RemoteDataSource.getGifts()` is called (nothing in the UI reads a
/// list-sourced gift's `recipientPhone` today, so `''` is a safe
/// placeholder rather than a real data loss — same "default the missing
/// field, document it" pattern already used on `Merchant`'s
/// address/country/state for the same reason: the list endpoint returning
/// a slimmer shape than the show/create endpoints).
@immutable
class Gift {
  const Gift({
    required this.id,
    required this.senderConsumerId,
    this.recipientConsumerId,
    required this.type,
    required this.amount,
    required this.recipientPhone,
    this.message,
    required this.expiresAt,
    required this.status,
    this.statusUpdatedAt,
  });

  final int id;
  final String senderConsumerId;
  final String? recipientConsumerId;
  final GiftType type;
  final double amount;
  final String recipientPhone;
  final String? message;
  final DateTime expiresAt;
  final GiftStatus status;

  /// When [status] last changed (e.g. redeemed-at). Business data, not a
  /// Rails audit column — nullable because a just-created gift has no status
  /// transition yet.
  final DateTime? statusUpdatedAt;

  factory Gift.fromJson(Map<String, dynamic> json) {
    return Gift(
      id: json['id'] as int,
      senderConsumerId: json['sender_consumer_id'] as String,
      recipientConsumerId: json['recipient_consumer_id'] as String?,
      type: GiftTypeJson.fromJson(json['type'] as String),
      amount: _parseAmount(json['amount']),
      recipientPhone: json['recipient_phone'] as String? ?? '',
      message: json['message'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      status: GiftStatusJson.fromJson(json['status'] as String),
      statusUpdatedAt: json['status_updated_at'] == null
          ? null
          : DateTime.parse(json['status_updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_consumer_id': senderConsumerId,
      'recipient_consumer_id': recipientConsumerId,
      'type': type.toJson(),
      'amount': amount,
      'recipient_phone': recipientPhone,
      'message': message,
      'expires_at': expiresAt.toIso8601String(),
      'status': status.toJson(),
      'status_updated_at': statusUpdatedAt?.toIso8601String(),
    };
  }
}

/// Parses `amount`, which arrives as a [num] from local JSON fixtures but as
/// a [String] from the real backend API (a Postgres `numeric` column,
/// serialized as a string to avoid floating-point precision loss — confirmed
/// live against `POST /api/v1/gifts`, e.g. `"amount": "12000.0"`; same quirk
/// as `price`/`price_per_person_min/max` documented on
/// `MenuItem`/`Merchant`).
double _parseAmount(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.parse(s),
  _ => throw ArgumentError('Expected num or String for amount, got: $value'),
};
