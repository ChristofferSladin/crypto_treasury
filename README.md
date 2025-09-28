# Crypto Treasury Vault Prototype

This repository now contains both the Flutter web shell and the Unity WebGL scene required for the 3D vault experience. The Flutter app hosts the Unity build on `/vault`, relays wallet payloads to the scene, and reacts to coin selection messages emitted from Unity.

## Repository Layout

- `lib/` – Flutter application code (GoRouter, wallet UI, Unity iframe bridge).
- `unity_vault/` – Unity 2022 LTS project scaffold for the vault scene, scripts, prefabs, and textures.
- `web/3d/` – WebGL hosting shell; copy Unity build output here (generated `Build/` folder plus loader).

## Unity Project Notes

- Open `unity_vault` with Unity 2022 LTS.
- Scripts of interest:
  - `Scripts/Messaging/Bridge.cs` and `Messaging/WebGLBridge.jslib`: two-way `postMessage` bridge.
  - `Scripts/Wallet/CoinAggregator.cs`: mirrors the aggregation rule from the product spec.
  - `Scripts/Vault/VaultController.cs` and `CoinSpawner.cs`: drive door animation and coin spawning.
  - `Scripts/Input/OrbitCamera.cs`: mouse/touch orbit camera powered by the new Input System.
  - `Scripts/Interaction/CoinSelectable.cs`: hover highlight + click handling via physics raycasts.
- Prefabs & assets:
  - `Assets/Prefabs/Coin.prefab` (flat cylinder, Rigidbody, MeshCollider).
  - `Assets/Textures/Tokens/*.png` (placeholder token logos; replace with production art).
  - `Assets/Animations/VaultDoor.controller` (stub; hook up animator states/clip in the editor).
- Remember to enable the new Input System in Project Settings and add a `PhysicsRaycaster` to the main camera so `CoinSelectable` receives pointer events.

## Building Unity ? WebGL

1. In Unity, set the target to **WebGL** and ensure compression is set to **gzip** or **brotli**.
2. Add the vault scene (with door, spawner, camera) to the Build Settings.
3. Build into `unity_vault/Build/`. You will get files similar to:
   - `UnityVault.loader.js`
   - `UnityVault.data.gz`
   - `UnityVault.framework.js.gz`
   - `UnityVault.wasm.gz`
4. Copy the entire `Build/` folder into `web/3d/` (replacing the placeholder loader reference) so Flutter can serve the assets. Keep the filenames in sync with the placeholders defined in `web/3d/index.html`.

## Running Flutter Web Shell

```bash
flutter pub get
flutter run -d chrome --web-renderer canvaskit
```

- The `/` route shows the landing view; navigate to `/vault` for the 3D vault page.
- When the wallet state changes, the Flutter side posts the payload to Unity via `postMessage`.
- Unity responds with `coinSelected` messages that surface as a banner inside the Flutter UI.

If you need to reset the coins without reloading, execute `resetVaultCoins()` in the browser console; this calls the JS helper exposed by the bridge.

## Aggregation Rule Test Cases

| Symbol | Amount     | Expected coins | `count_per_coin` pattern             |
| ------ | ---------- | -------------- | ------------------------------------ |
| BTC    | 3          | 3              | 1, 1, 1                              |
| USDC   | 250        | 25             | 10 repeated 25 times                 |
| ABC    | 1,234      | 13             | 100 repeated 12×, final coin 34      |
| PEPE   | 10,000     | 10             | 1,000 repeated 10×                   |
| XYZ    | 105,000    | 11             | 10,000 repeated 10×, final coin 5,000 |

The Unity `CoinAggregator` reproduces this behaviour for all positive numeric amounts.

## Remaining Polish Checklist

- Author the actual vault room, door animation, and timeline inside Unity.
- Assign real token materials in `CoinSpawner` (replace placeholder textures).
- Confirm the WebGL build is exported with gzip/brotli and hosted from `web/3d/`.
- Consider lighting/post effects for the vault room and performance profiling (target 30–60 fps on desktop Chrome).

## Troubleshooting

- If the iframe stays dark, verify the Unity build assets are present in `web/3d/Build/` and the filenames match the `config` block in `web/3d/index.html`.
- For hover/click to work, ensure the camera has `PhysicsRaycaster` and there is an `EventSystem` with `InputSystemUIInputModule` in the scene.
- The Flutter stub (`VaultUnityPanel`) degrades gracefully on non-web builds; the Unity experience is web-only by design for this MVP.
