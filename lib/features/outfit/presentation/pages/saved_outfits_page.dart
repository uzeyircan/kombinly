import 'package:flutter/material.dart';

class SavedOutfitsPage extends StatelessWidget {
  const SavedOutfitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Outfits'), centerTitle: true),
      body: const Center(
        child: Text(
          'Saved outfits will appear here.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
