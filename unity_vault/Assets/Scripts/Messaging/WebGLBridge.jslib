mergeInto(LibraryManager.library, {
  RegisterBridgeReceiver: function (objectNamePtr, walletMethodPtr, resetMethodPtr) {
    if (typeof window === 'undefined') {
      return;
    }

    var objectName = UTF8ToString(objectNamePtr);
    var walletMethod = UTF8ToString(walletMethodPtr);
    var resetMethod = UTF8ToString(resetMethodPtr);

    if (!objectName || !walletMethod) {
      console.warn('[UnityBridge] Missing object or method name during registration.');
      return;
    }

    var sendMessage = function (method, payload) {
      var target = (typeof unityInstance !== 'undefined' && unityInstance) ? unityInstance : null;
      if (!target && typeof gameInstance !== 'undefined' && gameInstance) {
        target = gameInstance;
      }
      if (!target || typeof target.SendMessage !== 'function') {
        console.warn('[UnityBridge] Unity instance unavailable during SendMessage.');
        return;
      }
      try {
        target.SendMessage(objectName, method, payload || '');
      } catch (err) {
        console.error('[UnityBridge] SendMessage failed', err);
      }
    };

    window.UnityVault = window.UnityVault || {};
    window.UnityVault.setWallet = function (payload) {
      var json = (typeof payload === 'string') ? payload : JSON.stringify(payload || {});
      sendMessage(walletMethod, json);
    };

    window.UnityVault.resetCoins = function () {
      if (resetMethod) {
        sendMessage(resetMethod, '');
      }
    };

    window.SetWalletJSON = window.UnityVault.setWallet;
    window.ResetVaultCoins = window.UnityVault.resetCoins;

    if (typeof window.UnityVaultPendingWallet === 'string' && window.UnityVaultPendingWallet.length > 0) {
      var pending = window.UnityVaultPendingWallet;
      window.UnityVaultPendingWallet = null;
      window.UnityVault.setWallet(pending);
    }
  },

  SendToParent: function (payloadPtr) {
    if (typeof window === 'undefined') {
      return;
    }
    var payload = UTF8ToString(payloadPtr);
    var target = window.parent || window;
    try {
      target.postMessage(payload, '*');
    } catch (err) {
      console.error('[UnityBridge] postMessage failed', err);
    }
  }
});