import 'package:crypto_treasury/ui/featuers/vault/viewmodels/providers.dart';
import 'package:crypto_treasury/ui/featuers/vault/viewmodels/wallet_view_model.dart';
import 'package:crypto_treasury/ui/featuers/vault/widgets/vault_asset_card.dart';
import 'package:crypto_treasury/ui/featuers/vault/widgets/vault_unity_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class VaultView extends ConsumerStatefulWidget {
  const VaultView({super.key});

  @override
  ConsumerState<VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends ConsumerState<VaultView> {
  bool _unityReady = false;
  VaultCoinSelection? _selection;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Overview'),
        actions: [
          if (walletState.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh balances',
            onPressed: walletState.isRefreshing
                ? null
                : () => ref
                    .read(walletViewModelProvider.notifier)
                    .refreshWallet(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: !walletState.isSupported
            ? const _UnsupportedNotice(key: ValueKey('unsupported'))
            : walletState.wallet == null
                ? const _EmptyVaultState(key: ValueKey('empty'))
                : _VaultContent(
                    key: const ValueKey('content'),
                    walletState: walletState,
                    unityReady: _unityReady,
                    onUnityReady: _handleUnityReady,
                    onCoinSelected: _handleCoinSelected,
                    selection: _selection,
                  ),
      ),
    );
  }

  void _handleUnityReady(bool ready) {
    if (_unityReady == ready) {
      return;
    }
    setState(() {
      _unityReady = ready;
    });
  }

  void _handleCoinSelected(VaultCoinSelection selection) {
    setState(() {
      _selection = selection;
    });
  }
}

class _VaultContent extends StatelessWidget {
  const _VaultContent({
    super.key,
    required this.walletState,
    required this.unityReady,
    required this.onUnityReady,
    required this.onCoinSelected,
    required this.selection,
  });

  final WalletUiState walletState;
  final bool unityReady;
  final ValueChanged<bool> onUnityReady;
  final ValueChanged<VaultCoinSelection> onCoinSelected;
  final VaultCoinSelection? selection;

  @override
  Widget build(BuildContext context) {
    final wallet = walletState.wallet!;
    final theme = Theme.of(context);
    final balancesForUnity = walletState.toUnityBalances();

    return LayoutBuilder(
      builder: (context, constraints) {
        final estimatedCrossAxis = (constraints.maxWidth / 240).floor();
        final crossAxisCount = estimatedCrossAxis.clamp(1, 4).toInt();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: VaultUnityPanel(
                      walletBalances: balancesForUnity,
                      showLoader: walletState.isRefreshing || !unityReady,
                      onUnityReady: onUnityReady,
                      onCoinSelected: onCoinSelected,
                    ),
                  ),
                ),
              ),
              if (selection != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _SelectionBanner(selection: selection!),
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Balance', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text(
                      NumberFormat.simpleCurrency().format(
                        wallet.totalUsdValue,
                      ),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.link),
                          label: Text(_abbrAddress(wallet.address)),
                        ),
                        Chip(
                          avatar: const Icon(Icons.language),
                          label: Text('Chain ID: ${wallet.chainId}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Vault Assets',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: wallet.assets.length,
                itemBuilder: (context, index) {
                  final asset = wallet.assets[index];
                  return VaultAssetCard(asset: asset);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static String _abbrAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({required this.selection});

  final VaultCoinSelection selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.token, size: 24),
            const SizedBox(width: 12),
            Text(
              selection.symbol,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text('x${selection.countPerCoin}'),
          ],
        ),
      ),
    );
  }
}

class _EmptyVaultState extends StatelessWidget {
  const _EmptyVaultState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Vault Locked',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your MetaMask wallet from the landing page to unlock your asset vault.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to landing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedNotice extends StatelessWidget {
  const _UnsupportedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.warning_amber_rounded, size: 56),
            SizedBox(height: 16),
            Text(
              'MetaMask is not available in this environment.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Please reopen the application from a MetaMask-enabled browser to access the vault.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
