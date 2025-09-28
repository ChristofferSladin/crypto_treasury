#nullable enable

using System;
using System.Runtime.InteropServices;
using UnityEngine;

namespace Messaging
{
    /// <summary>
    /// Provides a thin bridge layer between the Unity WebGL build and the hosting Flutter app.
    /// </summary>
    public sealed class Bridge : MonoBehaviour
    {
        public static event Action<Wallet.WalletMessage>? OnWalletUpdated;
        public static event Action? OnResetRequested;

        private static Bridge? _instance;
        private static Wallet.WalletMessage? _lastWalletMessage;

        public static Wallet.WalletMessage? LatestWalletMessage => _lastWalletMessage;

#if UNITY_WEBGL && !UNITY_EDITOR
        [DllImport("__Internal")]
        private static extern void RegisterBridgeReceiver(string objectName, string walletMethod, string resetMethod);

        [DllImport("__Internal")]
        private static extern void SendToParent(string payloadJson);
#else
        private static void RegisterBridgeReceiver(string objectName, string walletMethod, string resetMethod) {}
        private static void SendToParent(string payloadJson)
        {
            Debug.Log($"[Bridge] Would post to parent: {payloadJson}");
        }
#endif

        [Serializable]
        private class CoinSelectionMessage
        {
            public string type = "coinSelected";
            public string symbol = string.Empty;
            public int count_per_coin;
        }

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            gameObject.name = "BridgeRuntime";
            DontDestroyOnLoad(gameObject);

            TryRegisterWithJavaScript();
        }

        private void Start()
        {
            if (_lastWalletMessage != null)
            {
                OnWalletUpdated?.Invoke(_lastWalletMessage);
            }
        }

        private void TryRegisterWithJavaScript()
        {
            try
            {
                RegisterBridgeReceiver(gameObject.name, nameof(HandleWalletJSON), nameof(HandleResetRequest));
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"[Bridge] JavaScript registration skipped: {ex.Message}");
            }
        }

        /// <summary>
        /// Called by the WebGL JS layer using SendMessage.
        /// </summary>
        /// <param name="json">Wallet payload JSON.</param>
        public void HandleWalletJSON(string json)
        {
            SetWalletJSON(json);
        }

        /// <summary>
        /// Called by the JS helper to force-clear the scene.
        /// </summary>
        /// <param name="_">Unused payload.</param>
        public void HandleResetRequest(string _) => OnResetRequested?.Invoke();

        /// <summary>
        /// Parses the wallet payload and raises the OnWalletUpdated event.
        /// </summary>
        /// <param name="json">JSON formatted payload from Flutter.</param>
        public static void SetWalletJSON(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
            {
                return;
            }

            try
            {
                var message = JsonUtility.FromJson<Wallet.WalletMessage>(json);
                if (message == null)
                {
                    Debug.LogWarning("[Bridge] Wallet payload deserialized to null.");
                    return;
                }

                if (!string.Equals(message.type, "setWallet", StringComparison.OrdinalIgnoreCase))
                {
                    Debug.LogWarning($"[Bridge] Ignoring unsupported message type: {message.type}");
                    return;
                }

                _lastWalletMessage = message;
                OnWalletUpdated?.Invoke(message);
            }
            catch (Exception ex)
            {
                Debug.LogError($"[Bridge] Failed to parse wallet payload: {ex}");
            }
        }

        /// <summary>
        /// Posts a serialized payload back to the Flutter host window.
        /// </summary>
        /// <param name="payload">Serializable payload.</param>
        public static void PostToParent(object payload)
        {
            if (payload == null)
            {
                return;
            }

            string json;
            try
            {
                json = JsonUtility.ToJson(payload);
            }
            catch (Exception ex)
            {
                Debug.LogError($"[Bridge] Failed to serialize payload: {ex}");
                return;
            }

#if UNITY_WEBGL && !UNITY_EDITOR
            SendToParent(json);
#else
            Debug.Log($"[Bridge] Emitting message to parent: {json}");
#endif
        }

        /// <summary>
        /// Convenience helper for coin selection events.
        /// </summary>
        /// <param name="symbol">Token symbol in uppercase.</param>
        /// <param name="countPerCoin">Aggregated count that the coin represents.</param>
        public static void PostCoinSelection(string symbol, int countPerCoin)
        {
            if (string.IsNullOrWhiteSpace(symbol))
            {
                return;
            }

            var payload = new CoinSelectionMessage
            {
                symbol = symbol,
                count_per_coin = Mathf.Max(0, countPerCoin),
            };

            PostToParent(payload);
        }
    }
}
