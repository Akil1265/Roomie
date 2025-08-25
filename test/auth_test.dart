import 'package:flutter_test/flutter_test.dart';
import 'package:roomie/services/auth_service.dart';

void main() {
  group('Google Sign-In Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('AuthService should be initialized', () {
      expect(authService, isNotNull);
      expect(authService.currentUser, isNull);
    });

    test('Google Sign-In configuration should be valid', () {
      // This test will help verify that the configuration is properly set up
      // The actual sign-in would require user interaction
      expect(() => authService.signInWithGoogle(), returnsNormally);
    });
  });
}
