import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/lightning_provider.dart';
import '../../../widgets/animated/meme_text.dart';
import '../../../models/wallet_models.dart';
import '../../../models/lightning_models.dart';

/// Transaction list widget for dashboard
class TransactionList extends StatelessWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final lightningProvider = context.watch<LightningProvider>();

    // Combine on-chain and lightning transactions
    final List<dynamic> allTransactions = [
      ...walletProvider.transactions,
      ...lightningProvider.payments,
    ];

    // Sort by timestamp
    allTransactions.sort((a, b) {
      final aTime = a is BrainrotTransaction
          ? (a.timestamp ?? DateTime.now())
          : (a as BrainrotPayment).timestamp;
      final bTime = b is BrainrotTransaction
          ? (b.timestamp ?? DateTime.now())
          : (b as BrainrotPayment).timestamp;
      return bTime.compareTo(aTime);
    });

    if (allTransactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '📭',
                  style: TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),
                MemeText(
                  'No transactions yet',
                  fontSize: 18,
                  color: Colors.white54,
                ),
                const SizedBox(height: 8),
                MemeText(
                  'Time to stack some sats!',
                  fontSize: 14,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final transaction = allTransactions[index];

          if (transaction is BrainrotTransaction) {
            return OnChainTransactionTile(transaction: transaction);
          } else {
            return LightningTransactionTile(
              payment: transaction as BrainrotPayment,
            );
          }
        },
        childCount: math.min(allTransactions.length, 10),
      ),
    );
  }
}

/// On-chain transaction tile
class OnChainTransactionTile extends StatelessWidget {
  final BrainrotTransaction transaction;

  const OnChainTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.isIncoming;
    final amount = transaction.netAmount.abs();
    final btcAmount = amount / BigInt.from(100000000);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Navigate to transaction details
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isIncoming
                        ? AppTheme.success.withAlpha((0.2 * 255).round())
                        : AppTheme.hotPink.withAlpha((0.2 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncoming ? AppTheme.success : AppTheme.hotPink,
                  ),
                ),

                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MemeText(
                            isIncoming ? 'Received' : 'Sent',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(width: 8),
                          ...transaction.memeEmojis.map(
                                  (emoji) => Text(emoji, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      MemeText(
                        transaction.getMemeStatus(
                            context.watch<WalletProvider>().currentBlockHeight ?? 0),
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MemeText(
                      '${isIncoming ? '+' : '-'}${btcAmount.toStringAsFixed(8)}',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isIncoming ? AppTheme.success : AppTheme.hotPink,
                    ),
                    MemeText(
                      'BTC',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightning transaction tile
class LightningTransactionTile extends StatelessWidget {
  final BrainrotPayment payment;

  const LightningTransactionTile({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final isIncoming = payment.isIncoming;
    final satAmount = payment.amountSats;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            // Navigate to payment details
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.limeGreen.withAlpha((0.2 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt,
                    color: AppTheme.limeGreen,
                  ),
                ),

                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MemeText(
                            isIncoming ? 'Lightning Received' : 'Lightning Sent',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(width: 8),
                          ...payment.getEmojis().map(
                                  (emoji) => Text(emoji, style: const TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      MemeText(
                        payment.getMemeStatus(),
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MemeText(
                      '${isIncoming ? '+' : '-'}$satAmount',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isIncoming ? AppTheme.success : AppTheme.hotPink,
                    ),
                    MemeText(
                      'sats',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
