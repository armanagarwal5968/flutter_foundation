import 'package:alramwarnaga_foundation/src/auth/google_authentication_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldUseGoogleRedirect', () {
    test('uses redirect on iOS web', () {
      expect(
        shouldUseGoogleRedirect(isWeb: true, platform: TargetPlatform.iOS),
        isTrue,
      );
    });

    test('uses redirect on Android web', () {
      expect(
        shouldUseGoogleRedirect(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
    });

    test('keeps popup on desktop web', () {
      expect(
        shouldUseGoogleRedirect(isWeb: true, platform: TargetPlatform.macOS),
        isFalse,
      );
    });

    test('keeps native flow on iOS apps', () {
      expect(
        shouldUseGoogleRedirect(isWeb: false, platform: TargetPlatform.iOS),
        isFalse,
      );
    });
  });
}
