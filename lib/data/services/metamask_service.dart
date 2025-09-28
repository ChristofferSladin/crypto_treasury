import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web3/flutter_web3.dart';
import 'package:js/js_util.dart' as js_util;
import 'package:http/http.dart' as http;

import 'package:crypto_treasury/data/models/crypto_asset.dart';
import 'package:crypto_treasury/data/models/crypto_wallet.dart';
import 'package:crypto_treasury/data/models/tracked_token.dart';

class MetamaskService {
  MetamaskService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null {
    _warmUpCachedState();
  }

  final http.Client _httpClient;
  final bool _ownsClient;

  static const _erc20Abi = [
    'function balanceOf(address owner) view returns (uint256)',
  ];

  static const Map<int, String> _chainNames = {
    1: 'Ethereum',
    5: 'Goerli',
    11155111: 'Sepolia',
    137: 'Polygon',
    56: 'BNB Smart Chain',
  };

  static const Map<int, String> _nativeSymbols = {
    1: 'ETH',
    5: 'ETH',
    11155111: 'ETH',
    137: 'MATIC',
    56: 'BNB',
  };

  static const Map<int, String> _nativeCoingeckoIds = {
    1: 'ethereum',
    5: 'ethereum',
    11155111: 'ethereum',
    137: 'matic-network',
    56: 'binancecoin',
  };

  static const Map<int, String> _coingeckoPlatforms = {
    1: 'ethereum',
    137: 'polygon-pos',
    56: 'binance-smart-chain',
  };

  static const Set<String> _stableCoinSymbols = {
    'USDC',
    'USDC.E',
    'USDCe',
    'USDT',
    'DAI',
    'BUSD',
    'USDP',
    'TUSD',
  };

  Ethereum? get _ethereum => ethereum;

  bool get isSupported => kIsWeb && _ethereum != null;

  bool get isMetaMask {
    if (!isSupported) {
      return false;
    }

    final eth = _ethereum;
    if (eth == null) {
      return false;
    }

    try {
      final dynamic flag = js_util.getProperty(eth, 'isMetaMask');
      if (flag is bool) {
        return flag;
      }
    } catch (_) {
      // Ignore and fall back to assuming MetaMask-like provider.
    }

    return true;
  }

  bool get isConnected => isMetaMask && _cachedAccount != null;

  int? get currentChainId => _cachedChainId;

  String? get currentAccount => _cachedAccount;

  String? _cachedAccount;
  int? _cachedChainId;
  StreamController<List<String>>? _accountChangesController;
  StreamController<int>? _chainChangesController;
  bool _accountListenerAttached = false;
  bool _chainListenerAttached = false;
  List<String>? _pendingAccountSnapshot;
  int? _pendingChainSnapshot;

  void _dispatchAccountSnapshot(List<String> accounts) {
    final snapshot = List<String>.from(accounts);
    final controller = _accountChangesController;

    if (controller == null) {
      _pendingAccountSnapshot = snapshot;
      return;
    }

    if (controller.isClosed) {
      _accountListenerAttached = false;
      _pendingAccountSnapshot = snapshot;
      return;
    }

    _pendingAccountSnapshot = null;
    controller.add(snapshot);
  }

  void _dispatchChainSnapshot(int chainId) {
    final controller = _chainChangesController;
    if (controller == null) {
      _pendingChainSnapshot = chainId;
      return;
    }

    if (controller.isClosed) {
      _chainListenerAttached = false;
      _pendingChainSnapshot = chainId;
      return;
    }

    _pendingChainSnapshot = null;
    controller.add(chainId);
  }

  void _warmUpCachedState() {
    final eth = _ethereum;
    if (eth == null) {
      return;
    }

    debugPrint('[MetaMask] Warm-up accounts request issued');
    unawaited(eth.getAccounts().then((accounts) {
      final normalized = accounts.map((value) => value.toString()).toList();
      _cachedAccount = normalized.isNotEmpty ? normalized.first : null;
      debugPrint('[MetaMask] Warm-up accounts response: ' + normalized.toString());
      _dispatchAccountSnapshot(normalized);
    }).catchError((error, stack) {
      debugPrint('[MetaMask] Warm-up accounts failed: ' + error.toString());
    }));

    debugPrint('[MetaMask] Warm-up chainId request issued');
    unawaited(eth.getChainId().then((chainId) {
      _cachedChainId = chainId;
      debugPrint('[MetaMask] Warm-up chainId response: ' + chainId.toString());
      _dispatchChainSnapshot(chainId);
    }).catchError((error, stack) {
      debugPrint('[MetaMask] Warm-up chainId failed: ' + error.toString());
    }));
  }

  Stream<List<String>> get accountStream {
    final eth = _ethereum;
    if (eth == null) {
      debugPrint('[MetaMask] accountStream requested but MetaMask unavailable');
      return const Stream.empty();
    }

    final controller = _accountChangesController ??= StreamController<List<String>>.broadcast();
    if (!_accountListenerAttached) {
      debugPrint('[MetaMask] accountStream attaching onAccountsChanged listener');
      eth.onAccountsChanged(_handleAccountsChanged);
      _accountListenerAttached = true;
    }

    final pending = _pendingAccountSnapshot;
    if (pending != null && !controller.isClosed) {
      controller.add(List<String>.from(pending));
      _pendingAccountSnapshot = null;
    }

    return controller.stream;
  }

  Stream<int> get chainStream {
    final eth = _ethereum;
    if (eth == null) {
      debugPrint('[MetaMask] chainStream requested but MetaMask unavailable');
      return const Stream.empty();
    }

    final controller = _chainChangesController ??= StreamController<int>.broadcast();
    if (!_chainListenerAttached) {
      debugPrint('[MetaMask] chainStream attaching onChainChanged listener');
      eth.onChainChanged(_handleChainChanged);
      _chainListenerAttached = true;
    }

    final pending = _pendingChainSnapshot;
    if (pending != null && !controller.isClosed) {
      controller.add(pending);
      _pendingChainSnapshot = null;
    }

    return controller.stream;
  }

  void _handleAccountsChanged(List<String> accounts) {
    final normalized = accounts.map((value) => value.toString()).toList();
    _cachedAccount = normalized.isNotEmpty ? normalized.first : null;
    if (normalized.isEmpty) {
      _cachedChainId = null;
    }

    debugPrint('[MetaMask] onAccountsChanged: ' + normalized.toString());
    _dispatchAccountSnapshot(normalized);
  }

  void _handleChainChanged(int chainId) {
    _cachedChainId = chainId;
    debugPrint('[MetaMask] onChainChanged: ' + chainId.toString());
    _dispatchChainSnapshot(chainId);
  }

  Future<int?> _resolveChainId() async {
    final eth = _ethereum;
    if (eth == null) {
      return null;
    }

    try {
      final chainId = await eth.getChainId();
      _cachedChainId = chainId;
      debugPrint('[MetaMask] Resolved chainId via provider API: ' + chainId.toString());
      _dispatchChainSnapshot(chainId);
      return chainId;
    } catch (error, stack) {
      debugPrint('[MetaMask] getChainId() failed: ' + error.toString());
      final provider = _provider;
      if (provider != null) {
        try {
          final network = await provider.getNetwork();
          final resolved = network.chainId;
          _cachedChainId = resolved;
          debugPrint('[MetaMask] Fallback network.chainId resolved: ' + resolved.toString());
          _dispatchChainSnapshot(resolved);
          return resolved;
        } catch (fallbackError, stackFallback) {
          debugPrint('[MetaMask] provider.getNetwork() failed: ' + fallbackError.toString());
        }
      }
      debugPrint('[MetaMask] Falling back to cached chainId: ' + (_cachedChainId?.toString() ?? 'null'));
      return _cachedChainId;
    }
  }

  Future<String?> connect() async {
    debugPrint('[MetaMask] connect() invoked. isMetaMask=' + isMetaMask.toString());
    if (!isMetaMask) {
      debugPrint('[MetaMask] connect() aborted: MetaMask not detected');
      return null;
    }

    final accounts = await _ethereum!.requestAccount();
    if (accounts.isEmpty) {
      debugPrint('[MetaMask] connect() returned no accounts');
      _cachedAccount = null;
      return null;
    }

    final normalized = accounts.map((value) => value.toString()).toList();
    debugPrint('[MetaMask] connect() accounts: ' + normalized.toString());
    final primary = normalized.first;
    _cachedAccount = primary;
    _dispatchAccountSnapshot(normalized);
    return primary;
  }

  Future<CryptoWallet?> connectAndLoadWallet({
    required List<TrackedToken> trackedTokens,
  }) async {
    final address = await connect();
    if (address == null) {
      debugPrint('[MetaMask] connectAndLoadWallet() no account returned');
      return null;
    }

    final chainId = await _resolveChainId();
    if (chainId == null) {
      debugPrint('[MetaMask] connectAndLoadWallet() failed to resolve chainId');
      return null;
    }

    debugPrint('[MetaMask] connectAndLoadWallet() chainId=' + chainId.toString());
    final assets = await _buildAssets(
      address: address,
      chainId: chainId,
      trackedTokens: trackedTokens,
    );

    return CryptoWallet(address: address, chainId: chainId, assets: assets);
  }

  Future<CryptoWallet?> loadWallet({
    required String address,
    required int chainId,
    required List<TrackedToken> trackedTokens,
  }) async {
    if (!isMetaMask) {
      debugPrint('[MetaMask] loadWallet() aborted: MetaMask unavailable');
      return null;
    }

    debugPrint('[MetaMask] loadWallet() using cached address=' + address + ', chainId=' + chainId.toString());
    _cachedAccount = address;
    _cachedChainId = chainId;
    final assets = await _buildAssets(
      address: address,
      chainId: chainId,
      trackedTokens: trackedTokens,
    );

    return CryptoWallet(address: address, chainId: chainId, assets: assets);
  }

  Future<List<CryptoAsset>> _buildAssets({
    required String address,
    required int chainId,
    required List<TrackedToken> trackedTokens,
  }) async {
    final provider = _provider;
    if (provider == null) {
      return const <CryptoAsset>[];
    }

    final assets = <CryptoAsset>[];

    final nativeSymbol = _nativeSymbols[chainId] ?? 'NATIVE';
    final nativeName = '${_chainNames[chainId] ?? 'Unknown'} Native';
    final nativeBalance = await provider.getBalance(address);
    final nativePrice = await _fetchNativeUsdPrice(chainId) ?? 0;
    final nativeUsdValue = _normalize(nativeBalance, 18) * nativePrice;

    assets.add(
      CryptoAsset(
        symbol: nativeSymbol,
        name: nativeName,
        balance: nativeBalance,
        decimals: 18,
        logoUrl: null,
        usdValue: nativeUsdValue,
      ),
    );

    final filteredTokens =
        trackedTokens.where((token) => token.chainId == chainId).toList();
    if (filteredTokens.isEmpty) {
      return assets;
    }

    final usdPrices = await _fetchTokenUsdPrices(chainId, filteredTokens);

    for (final token in filteredTokens) {
      try {
        final balance = await _readTokenBalance(token, address);
        final normalized = _normalize(balance, token.decimals);
        final price = _resolveUsdPrice(token, usdPrices);
        final usdValue = normalized * price;

        assets.add(
          CryptoAsset(
            symbol: token.symbol,
            name: token.name,
            balance: balance,
            decimals: token.decimals,
            logoUrl: token.logoUrl,
            usdValue: usdValue,
          ),
        );
      } catch (_) {
        // Skip tokens we fail to read to keep UX resilient.
      }
    }

    return assets;
  }

  Web3Provider? get _provider {
    if (!isMetaMask) {
      return null;
    }
    return Web3Provider(_ethereum!);
  }

  Future<BigInt> _readTokenBalance(TrackedToken token, String address) async {
    final provider = _provider;
    if (provider == null) {
      return BigInt.zero;
    }

    final contract = Contract(token.address, _erc20Abi, provider);
    final value = await contract.call<BigInt>('balanceOf', [address]);
    return value;
  }

  double _normalize(BigInt value, int decimals) {
    if (decimals <= 0) {
      return value.toDouble();
    }

    final divisor = BigInt.from(10).pow(decimals);
    if (divisor == BigInt.zero) {
      return 0;
    }

    return value.toDouble() / divisor.toDouble();
  }

  double _resolveUsdPrice(TrackedToken token, Map<String, double> usdPrices) {
    final addressKey = token.address.toLowerCase();
    final marketPrice = usdPrices[addressKey];
    if (marketPrice != null && marketPrice > 0) {
      return marketPrice;
    }

    final symbol = token.symbol.toUpperCase();
    if (_stableCoinSymbols.contains(symbol)) {
      return 1;
    }

    return 0;
  }

  Future<double?> _fetchNativeUsdPrice(int chainId) async {
    final id = _nativeCoingeckoIds[chainId];
    if (id == null) {
      return null;
    }

    try {
      final uri = Uri.https('api.coingecko.com', '/api/v3/simple/price', {
        'ids': id,
        'vs_currencies': 'usd',
      });
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        return null;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = payload[id] as Map<String, dynamic>?;
      final price = data?['usd'];
      if (price is num) {
        return price.toDouble();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, double>> _fetchTokenUsdPrices(
    int chainId,
    List<TrackedToken> tokens,
  ) async {
    final platform = _coingeckoPlatforms[chainId];
    if (platform == null) {
      return <String, double>{};
    }

    final contractAddresses = tokens
        .where((token) => token.coingeckoId != null)
        .map((token) => token.address.toLowerCase())
        .toList();

    if (contractAddresses.isEmpty) {
      return <String, double>{};
    }

    try {
      final uri = Uri.https(
        'api.coingecko.com',
        '/api/v3/simple/token_price/$platform',
        {
          'contract_addresses': contractAddresses.join(','),
          'vs_currencies': 'usd',
        },
      );
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        return <String, double>{};
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded.map((key, value) {
        final price = (value as Map<String, dynamic>)['usd'];
        return MapEntry(key.toLowerCase(), price is num ? price.toDouble() : 0);
      });
    } catch (_) {
      return <String, double>{};
    }
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }

    final eth = _ethereum;
    if (eth != null) {
      if (_accountListenerAttached) {
        eth.removeAllListeners('accountsChanged');
        _accountListenerAttached = false;
      }
      if (_chainListenerAttached) {
        eth.removeAllListeners('chainChanged');
        _chainListenerAttached = false;
      }
    }

    _cachedAccount = null;
    _cachedChainId = null;
    _pendingAccountSnapshot = null;
    _pendingChainSnapshot = null;

    _accountChangesController?.close();
    _accountChangesController = null;
    _chainChangesController?.close();
    _chainChangesController = null;
  }
}
