import 'package:flutter/material.dart';
import 'package:roomie/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:roomie/screens/login_s.dart';
import 'package:roomie/screens/home_s.dart';
import 'package:roomie/screens/user_profile_s.dart';
import 'package:roomie/widgets/auth_wrapper.dart';
import 'package:roomie/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized, continue
    print('Firebase initialization: $e');
  }

  // Initialize notifications
  try {
    await NotificationService().initialize();
  } catch (e) {
    print('Error initializing notifications: $e');
  }

  print('🚀 Starting Roomie App (Firestore + Cloudinary mode)...');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roomie',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const PhoneLoginScreen(),
        '/profile': (context) => const UserProfileScreen(),
      },
      theme: ThemeData(
        primaryColor: const Color(0xFF121417),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Plus Jakarta Sans',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF121417),
          elevation: 0,
        ),
      ),
    );
  }
}
