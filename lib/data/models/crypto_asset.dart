// Defines the read-only data model for assets held within a connected wallet.
class CryptoAsset {
  const CryptoAsset({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.decimals,
    required this.logoUrl,
    required this.usdValue,
  });

  final String symbol;
  final String name;
  final BigInt balance;
  final int decimals;
  final String? logoUrl;
  final double usdValue;

  double get normalizedBalance {
    final divisor = BigInt.from(10).pow(decimals);
    if (divisor == BigInt.zero) {
      return 0;
    }
    return balance.toDouble() / divisor.toDouble();
  }

  CryptoAsset copyWith({
    String? symbol,
    String? name,
    BigInt? balance,
    int? decimals,
    String? logoUrl,
    double? usdValue,
  }) {
    return CryptoAsset(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      decimals: decimals ?? this.decimals,
      logoUrl: logoUrl ?? this.logoUrl,
      usdValue: usdValue ?? this.usdValue,
    );
  }
}
