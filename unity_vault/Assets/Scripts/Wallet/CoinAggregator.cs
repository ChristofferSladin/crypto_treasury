using System;
using System.Collections.Generic;

namespace Wallet
{
    public static class CoinAggregator
    {
        public struct CoinBatch
        {
            public string symbol;
            public int coinCount;
            public int divisor;
            public List<int> countsPerCoin;
        }

        public static CoinBatch Compute(string symbol, double amount)
        {
            var safeSymbol = string.IsNullOrWhiteSpace(symbol) ? "UNKNOWN" : symbol.ToUpperInvariant();
            var safeAmount = double.IsNaN(amount) || amount < 0d ? 0d : amount;
            var divisor = ComputeDivisor(safeAmount);

            if (divisor <= 0)
            {
                divisor = 1;
            }

            var coinCount = (int)Math.Ceiling(safeAmount / divisor);
            if (coinCount <= 0)
            {
                return new CoinBatch
                {
                    symbol = safeSymbol,
                    coinCount = 0,
                    divisor = divisor,
                    countsPerCoin = new List<int>(),
                };
            }

            var counts = new List<int>(coinCount);
            var decAmount = (decimal)safeAmount;
            var decDivisor = (decimal)divisor;
            var fullCoins = coinCount - 1;

            for (int i = 0; i < fullCoins; i++)
            {
                counts.Add(divisor);
            }

            var remainder = decAmount - (fullCoins * decDivisor);
            var remainderValue = (int)Math.Round((double)remainder);
            if (remainderValue <= 0)
            {
                remainderValue = divisor;
            }

            counts.Add(remainderValue);

            return new CoinBatch
            {
                symbol = safeSymbol,
                coinCount = coinCount,
                divisor = divisor,
                countsPerCoin = counts,
            };
        }

        public static int ComputeDivisor(double amount)
        {
            if (amount < 100d)
            {
                return 1;
            }

            var safeAmount = Math.Max(1d, amount);
            var digits = (int)Math.Floor(Math.Log10(safeAmount)) + 1;
            var exponent = Math.Max(0, digits - 2);
            var divisorDouble = Math.Pow(10d, exponent);
            if (divisorDouble > int.MaxValue)
            {
                divisorDouble = int.MaxValue;
            }

            return (int)Math.Max(1d, divisorDouble);
        }
    }
}
