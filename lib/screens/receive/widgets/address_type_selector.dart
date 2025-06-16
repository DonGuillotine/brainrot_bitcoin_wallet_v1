import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../models/wallet_models.dart';

/// Address type selector widget
class AddressTypeSelector extends StatelessWidget {
  final WalletType selectedType;
  final Function(WalletType) onTypeSelected;

  const AddressTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      (WalletType.standard, 'Native SegWit', 'bc1...', '⚡', 'Lowest fees'),
      (WalletType.taproot, 'Taproot', 'bc1p...', '🌳', 'Privacy++'),
      (WalletType.legacy, 'Legacy', '1...', '👴', 'Maximum compatibility'),
      (WalletType.nested, 'Nested SegWit', '3...', '📦', 'Balanced'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemeText(
          'Address Type',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),

        const SizedBox(height: 12),

        ...types.map((type) {
          final isSelected = selectedType == type.$1;

          return GestureDetector(
            onTap: () => onTypeSelected(type.$1),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.deepPurple.withAlpha((0.2 * 255).round())
                    : AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.deepPurple
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Text(type.$3, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MemeText(
                              type.$2,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            const SizedBox(width: 8),
                            MemeText(
                              type.$3,
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                        MemeText(
                          type.$4,
                          fontSize: 12,
                          color: AppTheme.limeGreen,
                        ),
                      ],
                    ),
                  ),
                  Radio<WalletType>(
                    value: type.$1,
                    groupValue: selectedType,
                    onChanged: (value) => onTypeSelected(value!),
                    activeColor: AppTheme.deepPurple,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
