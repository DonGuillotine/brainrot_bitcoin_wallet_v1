import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../providers/theme_provider.dart';

/// Amount request widget for invoices
class AmountRequest extends StatefulWidget {
  final TextEditingController controller;
  final TextEditingController descriptionController;
  final Function(int?) onAmountChanged;
  final bool isLightning;
  final bool required;

  const AmountRequest({
    super.key,
    required this.controller,
    required this.descriptionController,
    required this.onAmountChanged,
    this.isLightning = false,
    this.required = true,
  });

  @override
  State<AmountRequest> createState() => _AmountRequestState();
}

class _AmountRequestState extends State<AmountRequest> {
  String _selectedUnit = 'sats';

  void _handleAmountChange(String value) {
    if (value.isEmpty) {
      widget.onAmountChanged(null);
      return;
    }

    try {
      final amount = double.parse(value);
      int sats = 0;

      switch (_selectedUnit) {
        case 'BTC':
          sats = (amount * 100000000).round();
          break;
        case 'mBTC':
          sats = (amount * 100000).round();
          break;
        case 'bits':
          sats = (amount * 100).round();
          break;
        case 'sats':
          sats = amount.round();
          break;
      }

      widget.onAmountChanged(sats);
    } catch (e) {
      widget.onAmountChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isLightning
              ? AppTheme.limeGreen.withAlpha((0.3 * 255).round())
              : AppTheme.deepPurple.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount input
          MemeText(
            widget.required ? 'Amount *' : 'Amount (optional)',
            fontSize: 14,
            color: Colors.white70,
          ),

          const SizedBox(height: 8),

          TextField(
            controller: widget.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                color: Colors.white.withAlpha((0.3 * 255).round()),
              ),
              border: InputBorder.none,
              suffixIcon: _buildUnitSelector(),
            ),
            onChanged: _handleAmountChange,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),

          const Divider(color: Colors.white24),

          // Description input
          MemeText(
            'Description (optional)',
            fontSize: 14,
            color: Colors.white70,
          ),

          const SizedBox(height: 8),

          TextField(
            controller: widget.descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: widget.isLightning
                  ? 'Coffee money ☕'
                  : 'What\'s this payment for?',
              hintStyle: TextStyle(
                color: Colors.white.withAlpha((0.3 * 255).round()),
              ),
              border: InputBorder.none,
            ),
          ),

          // Quick amount buttons
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAmountButton('1k', 1000),
              _buildQuickAmountButton('5k', 5000),
              _buildQuickAmountButton('10k', 10000),
              _buildQuickAmountButton('21k', 21000),
              _buildQuickAmountButton('100k', 100000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    return PopupMenuButton<String>(
      initialValue: _selectedUnit,
      onSelected: (unit) {
        setState(() => _selectedUnit = unit);
        _handleAmountChange(widget.controller.text);
      },
      itemBuilder: (context) => [
        'sats',
        'bits',
        'mBTC',
        'BTC',
      ].map((unit) => PopupMenuItem(
        value: unit,
        child: MemeText(unit),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemeText(
              _selectedUnit,
              fontSize: 16,
              color: AppTheme.limeGreen,
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.limeGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, int sats) {
    return OutlinedButton(
      onPressed: () {
        widget.controller.text = sats.toString();
        _handleAmountChange(sats.toString());
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: widget.isLightning
              ? AppTheme.limeGreen
              : AppTheme.deepPurple,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: MemeText(label, fontSize: 14),
    );
  }
}
