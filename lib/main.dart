import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:roomie/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:roomie/presentation/screens/auth/login_s.dart';
import 'package:roomie/presentation/screens/home/home_s.dart';
import 'package:roomie/presentation/screens/profile/user_profile_s.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/presentation/widgets/auth_wrapper.dart';
import 'package:roomie/data/datasources/notification_service.dart';
import 'package:roomie/core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('📱 App starting...');

  // Load environment variables with fallback
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded');
  } catch (e) {
    print('❌ Environment variables failed: $e');
    print('🔧 Using hardcoded Firebase config for mobile');
  }

  // Initialize Firebase with error handling and duplicate-app guard
  try {
    if (Firebase.apps.isEmpty) {
      print('ℹ️ No Firebase apps found. Initializing default app...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');
    } else {
      // Reuse existing app (common after hot restart)
      print('ℹ️ Firebase already initialized. Apps count: ${Firebase.apps.length}');
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // Safe to ignore and continue using the existing default app
      print('⚠️ Firebase default app already exists; reusing existing instance.');
    } else {
      print('❌ Firebase initialization failed: [${e.code}] ${e.message}');
      print('🔧 App will continue to boot, but Firebase features may be unavailable.');
    }
  } catch (e) {
    print('❌ Firebase initialization failed (unexpected): $e');
    print('🔧 App will continue to boot, but Firebase features may be unavailable.');
  }

  // Initialize notifications
  try {
    await NotificationService().initialize();
    print('✅ Notifications initialized');
  } catch (e) {
    print('❌ Notifications failed: $e');
  }

  print('🚀 Starting Roomie App (Firestore + Cloudinary mode)...');

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        // Add other services here
      ],
      child: const MyApp(),
    ),
  );
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
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: ThemeMode.system,
    );
  }
}
