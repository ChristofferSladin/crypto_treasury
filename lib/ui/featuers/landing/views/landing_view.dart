import 'package:crypto_treasury/ui/featuers/vault/viewmodels/providers.dart';
import 'package:crypto_treasury/ui/featuers/vault/viewmodels/wallet_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LandingView extends ConsumerWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletViewModelProvider);

    ref.listen<WalletUiState>(walletViewModelProvider, (previous, next) {
      final wasConnected = previous?.wallet != null;
      final isConnected = next.wallet != null;
      if (!wasConnected && isConnected) {
        context.go('/vault');
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090A0F), Color(0xFF101927)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crypto Treasury',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connect your MetaMask wallet and visualise your digital assets inside a secure, vault-inspired interface.',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  if (!walletState.isSupported)
                    _UnsupportedBrowserCard(
                      onLearnMore: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('MetaMask not available'),
                              content: const Text(
                                'This experience currently requires a browser with the MetaMask extension installed. '
                                'Try opening the application from a desktop browser with MetaMask or use MetaMask Mobile in browser mode.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  if (walletState.isSupported)
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        ElevatedButton.icon(
                          onPressed: walletState.isConnecting
                              ? null
                              : () => ref
                                    .read(walletViewModelProvider.notifier)
                                    .connectWallet(),
                          icon: walletState.isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                          label: Text(
                            walletState.isConnecting
                                ? 'Connecting...'
                                : 'Connect MetaMask',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 24,
                            ),
                          ),
                        ),
                        if (walletState.errorMessage != null)
                          Material(
                            color: Colors.transparent,
                            child: Text(
                              walletState.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedBrowserCard extends StatelessWidget {
  const _UnsupportedBrowserCard({required this.onLearnMore});

  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MetaMask Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We could not detect the MetaMask extension. Please open this site from a MetaMask-enabled browser or use the MetaMask mobile browser.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onLearnMore, child: const Text('Learn more')),
        ],
      ),
    );
  }
}
