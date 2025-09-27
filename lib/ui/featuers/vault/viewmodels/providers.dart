import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_treasury/data/repositories/wallet_repository.dart';

import 'wallet_view_model.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final repository = WalletRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final walletViewModelProvider =
    StateNotifierProvider<WalletViewModel, WalletUiState>((ref) {
      final repository = ref.watch(walletRepositoryProvider);
      return WalletViewModel(repository);
    });
