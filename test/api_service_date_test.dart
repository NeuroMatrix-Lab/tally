import 'package:flutter_test/flutter_test.dart';
import 'package:tally/services/api_service.dart';

void main() {
  group('ApiService date serialization', () {
    test('serializes backend dates as UTC RFC3339', () {
      final date = DateTime.utc(2026, 7, 4, 13, 45, 10);
      expect(ApiService.serializeDateForBackend(date), '2026-07-04T13:45:10.000Z');
    });
  });
}
