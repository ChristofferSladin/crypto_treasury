using System;

namespace Wallet
{
    [Serializable]
    public class WalletMessage
    {
        public string type = string.Empty;
        public Balance[] balances = Array.Empty<Balance>();

        [Serializable]
        public class Balance
        {
            public string symbol = string.Empty;
            public double amount;
        }
    }
}
