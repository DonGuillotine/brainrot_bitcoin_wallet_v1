import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../providers/wallet_provider.dart';
import '../../../models/wallet_models.dart';
import 'package:intl/intl.dart';

/// Address list bottom sheet
class AddressList extends StatefulWidget {
  final Function(BrainrotAddress) onAddressSelected;

  const AddressList({
    super.key,
    required this.onAddressSelected,
  });

  @override
  State<AddressList> createState() => _AddressListState();
}

class _AddressListState extends State<AddressList> {
  String _filter = 'all'; // all, used, unused

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final addresses = walletProvider.addresses;

    // Filter addresses
    final filteredAddresses = addresses.where((addr) {
      if (_filter == 'all') return true;
      if (_filter == 'used') return addr.isUsed;
      if (_filter == 'unused') return !addr.isUsed;
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.history,
                  color: AppTheme.limeGreen,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: MemeText(
                    'Address History',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.white54,
                ),
              ],
            ),
          ),

          // Filter chips
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Used', 'used'),
                const SizedBox(width: 8),
                _buildFilterChip('Unused', 'unused'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Address list
          Expanded(
            child: filteredAddresses.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inbox,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  MemeText(
                    'No addresses found',
                    fontSize: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: filteredAddresses.length,
              itemBuilder: (context, index) {
                final address = filteredAddresses[index];
                return _buildAddressTile(address, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;

    return FilterChip(
      label: MemeText(
        label,
        fontSize: 14,
        color: isSelected ? AppTheme.darkGrey : Colors.white,
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.limeGreen,
      backgroundColor: AppTheme.lightGrey,
      checkmarkColor: AppTheme.darkGrey,
    );
  }

  Widget _buildAddressTile(BrainrotAddress address, int index) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => widget.onAddressSelected(address),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Address type emoji
                    Text(
                      address.typeEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),

                    // Index
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MemeText(
                        '#${address.index}',
                        fontSize: 12,
                        color: AppTheme.limeGreen,
                      ),
                    ),

                    const Spacer(),

                    // Used indicator
                    if (address.isUsed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: AppTheme.warning,
                            ),
                            const SizedBox(width: 4),
                            MemeText(
                              'Used',
                              fontSize: 12,
                              color: AppTheme.warning,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Address
                Text(
                  address.address,
                  style: const TextStyle(
                    fontFamily: 'Monaco',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Label and date
                Row(
                  children: [
                    if (address.label != null) ...[
                      Icon(
                        Icons.label,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: MemeText(
                          address.label!,
                          fontSize: 12,
                          color: Colors.white54,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),

                    MemeText(
                      dateFormat.format(address.createdAt),
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn()
        .slideX(begin: 0.1, end: 0);
  }
}
