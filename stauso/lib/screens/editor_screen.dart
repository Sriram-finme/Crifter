import 'package:flutter/material.dart';

class EditorScreen extends StatelessWidget {
  final String quoteId;

  const EditorScreen({super.key, required this.quoteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: Center(child: Text('Editing quote: $quoteId')),
    );
  }
}
