#nullable enable

using Messaging;
using UnityEngine;
using Wallet;

namespace Vault
{
    /// <summary>
    /// Controls the vault door animation lifecycle and coordinates coin spawning.
    /// </summary>
    public class VaultController : MonoBehaviour
    {
        [SerializeField] private Animator doorAnimator = default!;
        [SerializeField] private CoinSpawner coinSpawner = default!;
        [SerializeField] private string openTriggerName = "Open";
        [SerializeField] private string closedStateName = "Closed";

        private bool _doorOpened;

        private void OnEnable()
        {
            Bridge.OnWalletUpdated += HandleWalletUpdated;
            Bridge.OnResetRequested += HandleResetRequested;

            if (Bridge.LatestWalletMessage != null)
            {
                HandleWalletUpdated(Bridge.LatestWalletMessage);
            }
        }

        private void OnDisable()
        {
            Bridge.OnWalletUpdated -= HandleWalletUpdated;
            Bridge.OnResetRequested -= HandleResetRequested;
        }

        private void HandleWalletUpdated(WalletMessage? message)
        {
            if (message == null || message.balances == null || message.balances.Length == 0)
            {
                coinSpawner?.ClearCoins();
                return;
            }

            if (!_doorOpened)
            {
                TriggerDoorOpen();
            }

            coinSpawner?.ClearCoins();

            foreach (var balance in message.balances)
            {
                var batch = CoinAggregator.Compute(balance.symbol, balance.amount);
                if (batch.coinCount <= 0)
                {
                    continue;
                }

                coinSpawner?.Spawn(batch.symbol, batch.countsPerCoin);
            }
        }

        private void HandleResetRequested()
        {
            coinSpawner?.ClearCoins();
            ResetDoor();
        }

        private void TriggerDoorOpen()
        {
            if (doorAnimator != null && !string.IsNullOrEmpty(openTriggerName))
            {
                doorAnimator.ResetTrigger(openTriggerName);
                doorAnimator.SetTrigger(openTriggerName);
            }

            _doorOpened = true;
        }

        private void ResetDoor()
        {
            if (doorAnimator != null && !string.IsNullOrEmpty(closedStateName))
            {
                doorAnimator.Play(closedStateName, 0, 0f);
            }

            _doorOpened = false;
        }
    }
}
