// Regression coverage for `BusinessHour.fromJson`'s time normalization —
// found while wiring the "Abierto ahora" search filter against the real
// backend: `GET /business_hours` (confirmed live against localhost:3000)
// serializes `opens_at`/`closes_at` as full ISO 8601 datetimes anchored to a
// dummy date (Rails' default `Time#as_json` for a `time without time zone`
// column), not the bare "HH:MM:SS" the local JSON fixtures use. Without
// normalizing at the parsing boundary, every open/closed check downstream
// (`restaurant_detail_screen.dart`'s `_computeOpenStatus`,
// `search_utils.dart`'s `isOpenNow`) would silently fail to parse the hour
// and treat every merchant as having no usable hours at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/models/business_hour.dart';

Map<String, dynamic> _json({String? opensAt, String? closesAt}) => {
  'id': 1,
  'merchant_id': 1,
  'day_of_week': 'monday',
  'opens_at': opensAt,
  'closes_at': closesAt,
  'closed': false,
};

void main() {
  group('BusinessHour.fromJson', () {
    test('keeps a bare "HH:MM:SS" string as-is (local fixtures shape)', () {
      final hour = BusinessHour.fromJson(
        _json(opensAt: '12:00:00', closesAt: '15:30:00'),
      );

      expect(hour.opensAt, '12:00:00');
      expect(hour.closesAt, '15:30:00');
    });

    test(
      'strips the dummy date/timezone from a full ISO 8601 datetime (real '
      'backend shape, confirmed live)',
      () {
        final hour = BusinessHour.fromJson(
          _json(
            opensAt: '2000-01-01T18:00:00.000Z',
            closesAt: '2000-01-01T02:00:00.000Z',
          ),
        );

        expect(hour.opensAt, '18:00:00');
        expect(hour.closesAt, '02:00:00');
      },
    );

    test('null stays null either way', () {
      final hour = BusinessHour.fromJson(_json());

      expect(hour.opensAt, isNull);
      expect(hour.closesAt, isNull);
    });
  });
}
