import 'package:flutter/material.dart';
import 'package:roomie/presentation/widgets/roomie_loading_widget.dart';

class TestLoadingScreen extends StatelessWidget {
  const TestLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Loading'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Roomie Loading Widget Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            RoomieLoadingWidget(size: 120, showText: true, text: 'Loading...'),
          ],
        ),
      ),
    );
  }
}
