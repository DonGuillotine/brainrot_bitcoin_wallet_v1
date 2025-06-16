import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../providers/theme_provider.dart';

/// Amount input widget with unit selection
class AmountInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String, String) onAmountChanged;
  final String selectedUnit;

  const AmountInput({
    super.key,
    required this.controller,
    required this.onAmountChanged,
    required this.selectedUnit,
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  final List<String> _units = ['sats', 'bits', 'mBTC', 'BTC'];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount input field
        TextField(
          controller: widget.controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              color: Colors.white.withAlpha((0.3 * 255).round()),
              fontSize: 32,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onChanged: (value) {
            widget.onAmountChanged(value, widget.selectedUnit);
          },
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
        ),

        const SizedBox(height: 16),

        // Unit selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _units.map((unit) {
            final isSelected = widget.selectedUnit == unit;

            return GestureDetector(
              onTap: () {
                widget.onAmountChanged(widget.controller.text, unit);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.limeGreen
                      : AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MemeText(
                  unit,
                  fontSize: 14,
                  color: isSelected
                      ? AppTheme.darkGrey
                      : Colors.white,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
