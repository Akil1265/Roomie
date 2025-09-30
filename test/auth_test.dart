import 'package:flutter_test/flutter_test.dart';
import 'package:roomie/data/datasources/auth_service.dart';

void main() {
  group('GoogleSignInResult', () {
    test('success status reports isSuccess true', () {
      const result = GoogleSignInResult(GoogleSignInStatus.success);
      expect(result.isSuccess, isTrue);
    });

    test('non-success status reports isSuccess false', () {
      const result = GoogleSignInResult(GoogleSignInStatus.error);
      expect(result.isSuccess, isFalse);
    });
  });
}
