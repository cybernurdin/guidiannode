import 'package:flutter_test/flutter_test.dart';
import 'package:guidiannode/features/emergency/models/emergency_models.dart';

void main() {
  test('valid coordinates are ready without a reverse-geocoded address', () {
    const snapshot = PositionSnapshot(latitude: 5.9631, longitude: 10.1591);

    expect(snapshot.displayAddress, 'Location ready');
  });
}
