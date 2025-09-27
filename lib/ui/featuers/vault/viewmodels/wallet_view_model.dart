import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_treasury/data/models/crypto_wallet.dart';
import 'package:crypto_treasury/data/repositories/wallet_repository.dart';

class WalletUiState {
  const WalletUiState({
    this.wallet,
    required this.isSupported,
    required this.isConnecting,
    required this.isRefreshing,
    this.errorMessage,
  });

  factory WalletUiState.initial({required bool isSupported}) {
    return WalletUiState(
      wallet: null,
      isSupported: isSupported,
      isConnecting: false,
      isRefreshing: false,
      errorMessage: null,
    );
  }

  final CryptoWallet? wallet;
  final bool isSupported;
  final bool isConnecting;
  final bool isRefreshing;
  final String? errorMessage;

  bool get isConnected => wallet != null;

  WalletUiState copyWith({
    CryptoWallet? wallet,
    bool? isSupported,
    bool? isConnecting,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    bool clearWallet = false,
  }) {
    return WalletUiState(
      wallet: clearWallet ? null : (wallet ?? this.wallet),
      isSupported: isSupported ?? this.isSupported,
      isConnecting: isConnecting ?? this.isConnecting,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class WalletViewModel extends StateNotifier<WalletUiState> {
  WalletViewModel(this._repository)
    : super(WalletUiState.initial(isSupported: _repository.isSupported)) {
    _init();
  }

  final WalletRepository _repository;

  StreamSubscription<List<String>>? _accountSubscription;
  StreamSubscription<int>? _chainSubscription;

  void _init() {
    if (_repository.isConnected) {
      _refreshWallet(silent: true);
    }

    _accountSubscription = _repository.accountStream.listen(
      _handleAccountChange,
    );
    _chainSubscription = _repository.chainStream.listen(_handleChainChange);
  }

  Future<void> connectWallet() async {
    if (!state.isSupported || state.isConnecting) {
      return;
    }

    state = state.copyWith(isConnecting: true, clearError: true);
    try {
      final wallet = await _repository.connectWallet();
      state = state.copyWith(
        wallet: wallet,
        isConnecting: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refreshWallet() => _refreshWallet();

  Future<void> _refreshWallet({bool silent = false}) async {
    if (!state.isSupported) {
      return;
    }

    if (!silent) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    }

    try {
      final wallet = await _repository.refreshWallet();
      state = state.copyWith(
        wallet: wallet,
        isRefreshing: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  void _handleAccountChange(List<String> accounts) {
    if (accounts.isEmpty) {
      state = state.copyWith(clearWallet: true);
      return;
    }

    final primary = accounts.first;
    final chainId = _repository.currentChainId;
    if (chainId == null) {
      state = state.copyWith(clearWallet: true);
      return;
    }

    _loadWallet(address: primary, chainId: chainId);
  }

  void _handleChainChange(int chainId) {
    final address = _repository.currentAccount;
    if (address == null) {
      state = state.copyWith(clearWallet: true);
      return;
    }

    _loadWallet(address: address, chainId: chainId);
  }

  Future<void> _loadWallet({
    required String address,
    required int chainId,
  }) async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final wallet = await _repository.loadWallet(
        address: address,
        chainId: chainId,
      );
      state = state.copyWith(
        wallet: wallet,
        isRefreshing: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _chainSubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
