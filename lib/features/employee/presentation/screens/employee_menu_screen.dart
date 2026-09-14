import 'package:flutter/material.dart';

class EmployeeMenuScreen extends StatelessWidget {
  const EmployeeMenuScreen({required this.qrToken, super.key});

  final String qrToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canteen Menu')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Employee menu will load using QR token:\n\n$qrToken',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
