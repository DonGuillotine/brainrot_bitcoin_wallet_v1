import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom refresh indicator with chaos
class ChaosRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const ChaosRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.limeGreen,
      backgroundColor: AppTheme.darkGrey,
      displacement: 80,
      strokeWidth: 3,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      child: child,
    );
  }
}
