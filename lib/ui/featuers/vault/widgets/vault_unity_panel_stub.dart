import 'package:flutter/material.dart';

class VaultCoinSelection {
  const VaultCoinSelection({required this.symbol, required this.countPerCoin});

  final String symbol;
  final int countPerCoin;
}

class VaultUnityPanel extends StatelessWidget {
  const VaultUnityPanel({
    super.key,
    required this.walletBalances,
    required this.onCoinSelected,
    required this.showLoader,
    required this.onUnityReady,
  });

  final List<Map<String, dynamic>> walletBalances;
  final ValueChanged<VaultCoinSelection>? onCoinSelected;
  final bool showLoader;
  final ValueChanged<bool>? onUnityReady;

  @override
  Widget build(BuildContext context) {
    onUnityReady?.call(false);
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '3D vault preview is only available in web builds.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
