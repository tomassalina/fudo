import 'package:flutter/foundation.dart';

/// Mirrors `public.day_of_week_enum` in `backend/db/structure.sql`.
enum DayOfWeek { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

/// JSON (de)serialization for [DayOfWeek] against `day_of_week_enum`.
extension DayOfWeekJson on DayOfWeek {
  static DayOfWeek fromJson(String value) => switch (value) {
    'monday' => DayOfWeek.monday,
    'tuesday' => DayOfWeek.tuesday,
    'wednesday' => DayOfWeek.wednesday,
    'thursday' => DayOfWeek.thursday,
    'friday' => DayOfWeek.friday,
    'saturday' => DayOfWeek.saturday,
    'sunday' => DayOfWeek.sunday,
    _ => throw ArgumentError('Unknown day_of_week_enum value: $value'),
  };

  String toJson() => switch (this) {
    DayOfWeek.monday => 'monday',
    DayOfWeek.tuesday => 'tuesday',
    DayOfWeek.wednesday => 'wednesday',
    DayOfWeek.thursday => 'thursday',
    DayOfWeek.friday => 'friday',
    DayOfWeek.saturday => 'saturday',
    DayOfWeek.sunday => 'sunday',
  };
}

/// Domain model for `public.business_hours`.
///
/// IMPORTANT: `(merchant_id, day_of_week)` has NO unique constraint in the
/// schema — a merchant can have more than one row for the same day (e.g. a
/// lunch shift and a dinner shift, "doble turno"). Never assume at most one
/// [BusinessHour] per day when grouping/rendering a list for a merchant.
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
///
/// `opens_at`/`closes_at` are Postgres `time without time zone` columns,
/// kept here as raw `"HH:MM:SS"` strings (no wall-clock date component to
/// anchor a `DateTime`, and no `TimeOfDay` dependency in the data layer).
@immutable
class BusinessHour {
  const BusinessHour({
    required this.id,
    required this.merchantId,
    required this.dayOfWeek,
    this.opensAt,
    this.closesAt,
    required this.closed,
  });

  final int id;
  final int merchantId;
  final DayOfWeek dayOfWeek;
  final String? opensAt;
  final String? closesAt;
  final bool closed;

  factory BusinessHour.fromJson(Map<String, dynamic> json) {
    return BusinessHour(
      id: json['id'] as int,
      merchantId: json['merchant_id'] as int,
      dayOfWeek: DayOfWeekJson.fromJson(json['day_of_week'] as String),
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      closed: json['closed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'day_of_week': dayOfWeek.toJson(),
      'opens_at': opensAt,
      'closes_at': closesAt,
      'closed': closed,
    };
  }
}
