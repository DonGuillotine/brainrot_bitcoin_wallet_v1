import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/lightning_models.dart';
import '../../models/wallet_models.dart';
import '../../theme/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/lightning_provider.dart';
import '../../widgets/animated/meme_text.dart';
import '../home/widgets/transaction_list.dart';

/// Full transaction history screen
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'all'; // all, sent, received

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkGrey,
      appBar: AppBar(
        title: const MemeText(
          'Transaction History',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
          color: AppTheme.limeGreen,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.limeGreen,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'On-chain'),
            Tab(text: 'Lightning'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: MemeText('All', fontSize: 14),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                  selectedColor: AppTheme.deepPurple,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: MemeText('Sent', fontSize: 14),
                  selected: _filter == 'sent',
                  onSelected: (_) => setState(() => _filter = 'sent'),
                  selectedColor: AppTheme.hotPink,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: MemeText('Received', fontSize: 14),
                  selected: _filter == 'received',
                  onSelected: (_) => setState(() => _filter = 'received'),
                  selectedColor: AppTheme.limeGreen,
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All transactions
                _buildTransactionList(includeOnChain: true, includeLightning: true),

                // On-chain only
                _buildTransactionList(includeOnChain: true, includeLightning: false),

                // Lightning only
                _buildTransactionList(includeOnChain: false, includeLightning: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList({
    required bool includeOnChain,
    required bool includeLightning,
  }) {
    final walletProvider = context.watch<WalletProvider>();
    final lightningProvider = context.watch<LightningProvider>();

    final List<dynamic> transactions = [];

    if (includeOnChain) {
      transactions.addAll(walletProvider.transactions);
    }

    if (includeLightning) {
      transactions.addAll(lightningProvider.payments);
    }

    // Apply filter
    final filtered = transactions.where((tx) {
      if (_filter == 'all') return true;

      final isIncoming = tx is BrainrotTransaction
          ? tx.isIncoming
          : (tx as BrainrotPayment).isIncoming;

      return _filter == 'received' ? isIncoming : !isIncoming;
    }).toList();

    // Sort by timestamp
    filtered.sort((a, b) {
      final aTime = a is BrainrotTransaction
          ? (a.timestamp ?? DateTime.now())
          : (a as BrainrotPayment).timestamp;
      final bTime = b is BrainrotTransaction
          ? (b.timestamp ?? DateTime.now())
          : (b as BrainrotPayment).timestamp;
      return bTime.compareTo(aTime);
    });

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🦗',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            MemeText(
              'No transactions found',
              fontSize: 18,
              color: Colors.white54,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final transaction = filtered[index];

        if (transaction is BrainrotTransaction) {
          return OnChainTransactionTile(transaction: transaction);
        } else {
          return LightningTransactionTile(
            payment: transaction as BrainrotPayment,
          );
        }
      },
    );
  }
}
