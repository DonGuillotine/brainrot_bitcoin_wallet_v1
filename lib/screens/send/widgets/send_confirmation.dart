import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/chaos_theme.dart';
import '../../../widgets/animated/chaos_button.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../providers/theme_provider.dart';

/// Transaction confirmation screen
class SendConfirmation extends StatefulWidget {
  final String address;
  final int amountSats;
  final int feeRate;
  final String? label;
  final bool isLightning;
  final VoidCallback onConfirm;
  final bool isLoading;

  const SendConfirmation({
    super.key,
    required this.address,
    required this.amountSats,
    required this.feeRate,
    this.label,
    required this.isLightning,
    required this.onConfirm,
    required this.isLoading,
  });

  @override
  State<SendConfirmation> createState() => _SendConfirmationState();
}

class _SendConfirmationState extends State<SendConfirmation> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chaosLevel = themeProvider.chaosLevel;

    final btcAmount = widget.amountSats / 100000000;
    final estimatedFee = widget.isLightning ? 1 : (250 * widget.feeRate);
    final total = widget.amountSats + estimatedFee;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeText(
            'Confirm Transaction',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),

          const SizedBox(height: 8),

          MemeText(
            'Last chance to back out! 😅',
            fontSize: 16,
            color: Colors.white70,
          ),

          const SizedBox(height: 32),

          // Transaction details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ChaosTheme.getChaosDecoration(
              chaosLevel: 0, // No chaos for important info
              baseColor: AppTheme.lightGrey,
            ),
            child: Column(
              children: [
                // Recipient
                _buildDetailRow(
                  'To',
                  _formatAddress(widget.address),
                  icon: widget.isLightning ? Icons.bolt : Icons.person,
                ),

                if (widget.label != null && widget.label!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Label',
                    widget.label!,
                    icon: Icons.label,
                  ),
                ],

                const Divider(height: 32),

                // Amount
                _buildDetailRow(
                  'Amount',
                  '${widget.amountSats} sats',
                  subtitle: '${btcAmount.toStringAsFixed(8)} BTC',
                  icon: Icons.attach_money,
                  valueColor: AppTheme.hotPink,
                ),

                const SizedBox(height: 16),

                // Fee
                _buildDetailRow(
                  'Network Fee',
                  '~$estimatedFee sats',
                  subtitle: widget.isLightning ? 'Lightning fee' : '${widget.feeRate} sat/vB',
                  icon: Icons.local_gas_station,
                ),

                const Divider(height: 32),

                // Total
                _buildDetailRow(
                  'Total',
                  '$total sats',
                  subtitle: '${(total / 100000000).toStringAsFixed(8)} BTC',
                  icon: Icons.calculate,
                  valueColor: AppTheme.limeGreen,
                  isTotal: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppTheme.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: MemeText(
                    'This transaction cannot be reversed!',
                    fontSize: 14,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          )
              .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
              .scale(
            begin: const Offset(0.98, 0.98),
            end: const Offset(1.02, 1.02),
            duration: const Duration(seconds: 2),
          ),

          const SizedBox(height: 24),

          // Confirmation checkbox
          CheckboxListTile(
            value: _understood,
            onChanged: (value) => setState(() => _understood = value ?? false),
            activeColor: AppTheme.limeGreen,
            title: MemeText(
              'I understand this is irreversible',
              fontSize: 14,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),

          const SizedBox(height: 32),

          // Confirm button
          ChaosButton(
            text: widget.isLoading ? 'Sending...' : 'Send It! 🚀',
            onPressed: _understood && !widget.isLoading ? widget.onConfirm : null,
            icon: widget.isLoading ? null : Icons.send,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      String label,
      String value, {
        String? subtitle,
        IconData? icon,
        Color? valueColor,
        bool isTotal = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: valueColor ?? Colors.white54,
          ),
          const SizedBox(width: 12),
        ],

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemeText(
                label,
                fontSize: 14,
                color: Colors.white54,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                MemeText(
                  subtitle,
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ],
            ],
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MemeText(
              value,
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.white,
            ),
          ],
        ),
      ],
    );
  }

  String _formatAddress(String address) {
    if (address.length > 20) {
      return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
    }
    return address;
  }
}
