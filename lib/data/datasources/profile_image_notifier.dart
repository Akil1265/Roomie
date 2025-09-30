import 'package:flutter/foundation.dart';

class ProfileImageNotifier extends ChangeNotifier {
  String? _currentImageId;
  static final ProfileImageNotifier _instance =
      ProfileImageNotifier._internal();

  factory ProfileImageNotifier() => _instance;
  ProfileImageNotifier._internal();

  String? get currentImageId => _currentImageId;

  void updateProfileImage(String? newImageId) {
    if (_currentImageId != newImageId) {
      _currentImageId = newImageId;
      print('ProfileImageNotifier: Image updated to: $newImageId');
      notifyListeners();
    }
  }

  void clearProfileImage() {
    _currentImageId = null;
    notifyListeners();
  }
}
