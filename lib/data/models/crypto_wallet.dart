import 'crypto_asset.dart';

// Immutable representation of a connected wallet instance.
class CryptoWallet {
  const CryptoWallet({
    required this.address,
    required this.chainId,
    required this.assets,
  });

  final String address;
  final int chainId;
  final List<CryptoAsset> assets;

  double get totalUsdValue =>
      assets.fold(0.0, (acc, asset) => acc + asset.usdValue);

  CryptoWallet copyWith({
    String? address,
    int? chainId,
    List<CryptoAsset>? assets,
  }) {
    return CryptoWallet(
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      assets: assets ?? this.assets,
    );
  }
}
