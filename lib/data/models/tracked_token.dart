// Configuration for ERC-20 tokens we want to query from a wallet.
class TrackedToken {
  const TrackedToken({
    required this.chainId,
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.coingeckoId,
    this.logoUrl,
  });

  final int chainId;
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final String? coingeckoId;
  final String? logoUrl;
}
