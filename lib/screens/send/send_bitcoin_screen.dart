import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated/meme_text.dart';

class SendBitcoinScreen extends StatelessWidget {
  const SendBitcoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      appBar: AppBar(
        title: const MemeText(
          'Send Bitcoin',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
          color: AppTheme.limeGreen,
        ),
      ),
      body: const Center(
        child: MemeText(
          'SEND - TO BE IMPLEMENTED',
          fontSize: 18,
        ),
      ),
    );
  }
}
