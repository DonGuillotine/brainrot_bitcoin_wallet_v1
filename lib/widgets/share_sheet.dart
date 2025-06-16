import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/animated/meme_text.dart';

/// Custom share sheet with meme options
class ShareSheet extends StatelessWidget {
  final String data;
  final String type; // 'address' or 'invoice'

  const ShareSheet({
    super.key,
    required this.data,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final shareOptions = [
      ShareOption(
        icon: Icons.copy,
        label: 'Copy',
        onTap: () {
          Clipboard.setData(ClipboardData(text: data));
          Navigator.pop(context);
          _showSuccess(context, 'Copied to clipboard!');
        },
      ),
      ShareOption(
        icon: Icons.share,
        label: 'Share',
        onTap: () {
          Share.share(data);
          Navigator.pop(context);
        },
      ),
      ShareOption(
        icon: Icons.qr_code,
        label: 'Show QR',
        onTap: () {
          Navigator.pop(context);
          _showQRDialog(context);
        },
      ),
      if (type == 'address')
        ShareOption(
          icon: Icons.email,
          label: 'Email',
          onTap: () {
            final uri = Uri(
              scheme: 'mailto',
              queryParameters: {
                'subject': 'My Bitcoin Address',
                'body': 'Here\'s my Bitcoin address:\n\n$data',
              },
            );
            // Launch email
            Navigator.pop(context);
          },
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          MemeText(
            'Share ${type == 'invoice' ? 'Invoice' : 'Address'}',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 24),

          // Options grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: shareOptions.map((option) => _buildOption(option)).toList(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption(ShareOption option) {
    return GestureDetector(
      onTap: option.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.lightGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              color: AppTheme.limeGreen,
              size: 32,
            ),
            const SizedBox(height: 8),
            MemeText(
              option.label,
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: MemeText(message, color: Colors.white),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQRDialog(BuildContext context) {
    // Show QR code in dialog
  }
}

class ShareOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
