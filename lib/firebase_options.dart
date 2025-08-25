import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_nNre56sb-GusDfE0dby8WbemlcdoBro',
    appId: '1:1066645245892:android:47bb217ca82ac28fe81e91',
    messagingSenderId: '1066645245892',
    projectId: 'roomie-cfc03',
    storageBucket: 'roomie-cfc03.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAEOn8GNnri6oEpSQ6YSdZ2UIiN6AQOix4',
    appId: '1:1066645245892:ios:88bb9882215359dde81e91',
    messagingSenderId: '1066645245892',
    projectId: 'roomie-cfc03',
    storageBucket: 'roomie-cfc03.firebasestorage.app',
    androidClientId: '1066645245892-uj54e0j951ah54a8msqr05h34seoetkc.apps.googleusercontent.com',
    iosClientId: '1066645245892-ifm2s1tj55tigfdndb1n4tr2ua2qj6eo.apps.googleusercontent.com',
    iosBundleId: 'com.example.roomie',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBf5tjhFo70CafU4hvtHAHhS9HIIFkUEW8',
    appId: '1:1066645245892:web:7782da71e8896be4e81e91',
    messagingSenderId: '1066645245892',
    projectId: 'roomie-cfc03',
    authDomain: 'roomie-cfc03.firebaseapp.com',
    storageBucket: 'roomie-cfc03.firebasestorage.app',
    measurementId: 'G-CLXKM3E66E',
  );

}