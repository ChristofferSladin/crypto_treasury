import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_web3/flutter_web3.dart';
import 'package:http/http.dart' as http;

import 'package:crypto_treasury/data/models/crypto_asset.dart';
import 'package:crypto_treasury/data/models/crypto_wallet.dart';
import 'package:crypto_treasury/data/models/tracked_token.dart';

class MetamaskService {
  MetamaskService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

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

  Ethereum? get _ethereum => ethereum;

  bool get isSupported => kIsWeb && _ethereum != null;

  bool get isMetaMask => isSupported && (_ethereum?.runtimeType.toString().toLowerCase().contains('metamask') == true);

  bool get isConnected => isMetaMask && _ethereum!.selectedAddress != null;

  int? get currentChainId => _ethereum?.chainId != null ? int.tryParse(_ethereum!.chainId!) : null;

  String? get currentAccount => _ethereum?.selectedAddress;

  Stream<List<String>> get accountStream =>
      (_ethereum?.onAccountsChanged as Stream<List<String>>?) ?? const Stream.empty();

  Stream<int> get chainStream =>
      (_ethereum?.onChainChanged as Stream<int>?) ?? const Stream.empty();

  Future<String?> connect() async {
    if (!isMetaMask) {
      return null;
    }

    final accounts = await _ethereum!.requestAccount();
    return accounts.isNotEmpty ? accounts.first : null;
  }

  Future<CryptoWallet?> connectAndLoadWallet({
    required List<TrackedToken> trackedTokens,
  }) async {
    final address = await connect();
    if (address == null) {
      return null;
    }

    final chainId = currentChainId;
    if (chainId == null) {
      return null;
    }

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
      return null;
    }

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
        final usdValue =
            normalized * (usdPrices[token.address.toLowerCase()] ?? 0);

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
  }
}
