import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/screens/locations/locations_screen.dart';

void main() {
  group('LocationMapGeometry', () {
    test('keeps the top branch control clear of the map focus area', () {
      final geometry = LocationMapGeometry.fromViewport(
        viewportHeight: 956,
        navClearance: 132,
        safeTop: 59,
        headerHeight: 84,
      );

      expect(geometry.headerTop, 71);
      expect(geometry.visibleTop, 171);
      expect(geometry.visibleBottom, 808);
    });

    test('reserves navigation clearance at the bottom of the map', () {
      final geometry = LocationMapGeometry.fromViewport(
        viewportHeight: 812,
        navClearance: 122,
        safeTop: 47,
        headerHeight: 84,
      );

      expect(geometry.headerTop, 59);
      expect(geometry.visibleBottom, 674);
      expect(geometry.visibleBottom, greaterThan(geometry.visibleTop));
    });

    test('maintains a usable focus area on a compact viewport', () {
      final geometry = LocationMapGeometry.fromViewport(
        viewportHeight: 568,
        navClearance: 130,
        safeTop: 0,
        headerHeight: 84,
      );

      expect(geometry.visibleTop, 112);
      expect(geometry.visibleBottom, 422);
      expect(geometry.visibleBottom, greaterThan(geometry.visibleTop));
    });
  });
}
