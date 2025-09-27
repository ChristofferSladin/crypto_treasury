import 'package:crypto_treasury/data/models/crypto_wallet.dart';
import 'package:crypto_treasury/data/models/tracked_token.dart';
import 'package:crypto_treasury/data/services/metamask_service.dart';

class WalletRepository {
  WalletRepository({
    MetamaskService? metamaskService,
    List<TrackedToken>? trackedTokens,
  }) : _metamaskService = metamaskService ?? MetamaskService(),
       _trackedTokens = trackedTokens ?? _defaultTrackedTokens;

  final MetamaskService _metamaskService;
  final List<TrackedToken> _trackedTokens;

  static const List<TrackedToken> _defaultTrackedTokens = [
    TrackedToken(
      chainId: 1,
      address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      coingeckoId: 'usd-coin',
      logoUrl:
          'https://assets.coingecko.com/coins/images/6319/small/USD_Coin_icon.png',
    ),
    TrackedToken(
      chainId: 1,
      address: '0x6b175474e89094c44da98b954eedeac495271d0f',
      symbol: 'DAI',
      name: 'Dai Stablecoin',
      decimals: 18,
      coingeckoId: 'dai',
      logoUrl: 'https://assets.coingecko.com/coins/images/9956/small/4943.png',
    ),
    TrackedToken(
      chainId: 137,
      address: '0x2791bca1f2de4661ed88a30c99a7a9449aa84174',
      symbol: 'USDC.e',
      name: 'USD Coin (Bridged)',
      decimals: 6,
      coingeckoId: 'usd-coin',
    ),
    TrackedToken(
      chainId: 137,
      address: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
      symbol: 'WETH',
      name: 'Wrapped Ether',
      decimals: 18,
      coingeckoId: 'weth',
    ),
  ];

  bool get isSupported => _metamaskService.isSupported;

  bool get isConnected => _metamaskService.isConnected;

  String? get currentAccount => _metamaskService.currentAccount;

  int? get currentChainId => _metamaskService.currentChainId;

  Stream<List<String>> get accountStream => _metamaskService.accountStream;

  Stream<int> get chainStream => _metamaskService.chainStream;

  Future<CryptoWallet?> connectWallet() {
    return _metamaskService.connectAndLoadWallet(trackedTokens: _trackedTokens);
  }

  Future<CryptoWallet?> refreshWallet() {
    final address = currentAccount;
    final chainId = currentChainId;
    if (address == null || chainId == null) {
      return Future.value(null);
    }
    return _metamaskService.loadWallet(
      address: address,
      chainId: chainId,
      trackedTokens: _trackedTokens,
    );
  }

  Future<CryptoWallet?> loadWallet({
    required String address,
    required int chainId,
  }) {
    return _metamaskService.loadWallet(
      address: address,
      chainId: chainId,
      trackedTokens: _trackedTokens,
    );
  }

  void dispose() {
    _metamaskService.dispose();
  }
}
