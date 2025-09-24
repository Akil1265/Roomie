import 'package:flutter/material.dart';
import 'package:roomie/screens/chat_screen.dart';

class TestChatScreen extends StatelessWidget {
  const TestChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Chat Navigation'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Chat Types',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Group Chat Test
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(
                      chatData: {
                        'id': 'test_group_123',
                        'name': 'Test Group',
                        'members': ['user1', 'user2', 'user3'],
                        'memberCount': 3,
                        'imageUrl': null,
                        'description': 'This is a test group for development',
                        'createdAt': 1640995200000, // Jan 1, 2022
                      },
                      chatType: 'group',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Test Group Chat',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Individual Chat Test
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(
                      chatData: {
                        'userId': 'test_user_456',
                        'name': 'John Doe',
                        'email': 'john.doe@example.com',
                        'phone': '+1234567890',
                        'profileImageUrl': null,
                        'createdAt': 1640995200000, // Jan 1, 2022
                      },
                      chatType: 'individual',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Test Individual Chat',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            const Text(
              'Features:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            
            const Text(
              '• Unified chat interface for both groups and individuals\n'
              '• Group chat shows sender names\n'
              '• Individual chat focuses on the conversation\n'
              '• Tap info button to see group/person details\n'
              '• Real-time messaging with Firebase Realtime Database\n'
              '• Auto-scroll to latest messages\n'
              '• Message timestamps',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF677583),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}