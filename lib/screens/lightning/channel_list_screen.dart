import 'package:flutter/material.dart';

class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lightning Channels'),
      ),
      body: const Center(
        child: Text('Lightning Channel List - To be implemented'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to a screen to open a new channel
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Open new channel action')),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Open New Channel',
      ),
    );
  }
}
