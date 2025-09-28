#nullable enable

using System;
using System.Collections.Generic;
using Interaction;
using TMPro;
using UnityEngine;

namespace Vault
{
    /// <summary>
    /// Responsible for instantiating coin prefabs, applying token materials, and adding physics impulse.
    /// </summary>
    public class CoinSpawner : MonoBehaviour
    {
        [Serializable]
        private struct TokenTexture
        {
            public string symbol;
            public Texture2D texture;
        }

        [SerializeField] private GameObject coinPrefab = default!;
        [SerializeField] private BoxCollider? spawnVolume = default;
        [SerializeField] private Material? coinMaterialTemplate = default;
        [SerializeField] private Material? fallbackMaterial = default;
        [SerializeField] private Color fallbackTextColor = Color.white;
        [SerializeField] private float spawnSpread = 0.5f;
        [SerializeField] private float spawnImpulse = 1.5f;
        [SerializeField] private float torqueImpulse = 0.75f;
        [SerializeField] private List<TokenTexture> tokenTextures = new();

        private readonly Dictionary<string, Material> _materialCache = new(StringComparer.OrdinalIgnoreCase);
        private readonly List<GameObject> _spawnedCoins = new();

        private static readonly int BaseMapId = Shader.PropertyToID("_BaseMap");
        private static readonly int MainTexId = Shader.PropertyToID("_MainTex");

        private void Awake()
        {
            BuildMaterialCache();
        }

        private void OnValidate()
        {
            if (Application.isPlaying)
            {
                return;
            }

            _materialCache.Clear();
            BuildMaterialCache();
        }

        private void OnDestroy()
        {
            foreach (var material in _materialCache.Values)
            {
                if (material != null)
                {
                    Destroy(material);
                }
            }
            _materialCache.Clear();
        }

        /// <summary>
        /// Clears all spawned coins from the scene.
        /// </summary>
        public void ClearCoins()
        {
            for (var i = 0; i < _spawnedCoins.Count; i++)
            {
                var coin = _spawnedCoins[i];
                if (coin != null)
                {
                    Destroy(coin);
                }
            }

            _spawnedCoins.Clear();
        }

        /// <summary>
        /// Spawns a stack of coins for the provided token symbol.
        /// </summary>
        /// <param name="symbol">Token symbol.</param>
        /// <param name="countsPerCoin">Per-coin aggregated counts.</param>
        public void Spawn(string symbol, IReadOnlyList<int> countsPerCoin)
        {
            if (coinPrefab == null)
            {
                Debug.LogError("[CoinSpawner] coinPrefab is not assigned.");
                return;
            }

            if (countsPerCoin == null || countsPerCoin.Count == 0)
            {
                return;
            }

            for (int i = 0; i < countsPerCoin.Count; i++)
            {
                var count = countsPerCoin[i];
                var position = GetSpawnPosition();
                var rotation = GetSpawnRotation();

                var coin = Instantiate(coinPrefab, position, rotation, transform);
                _spawnedCoins.Add(coin);

                ConfigureCoin(coin, symbol, count);
                ApplyImpulse(coin);
            }
        }

        private void ConfigureCoin(GameObject coin, string symbol, int count)
        {
            var uppercase = string.IsNullOrWhiteSpace(symbol) ? "UNKNOWN" : symbol.ToUpperInvariant();
            var material = ResolveMaterial(uppercase);
            var renderer = coin.GetComponentInChildren<MeshRenderer>();
            if (renderer != null)
            {
                if (material != null)
                {
                    renderer.sharedMaterial = material;
                }
                else if (fallbackMaterial != null)
                {
                    renderer.sharedMaterial = fallbackMaterial;
                }
            }

            ApplyFallbackLabel(coin, uppercase, material == null);

            var selectable = coin.GetComponent<CoinSelectable>();
            if (selectable == null)
            {
                selectable = coin.AddComponent<CoinSelectable>();
            }

            selectable.Configure(uppercase, Mathf.Max(0, count));
        }

        private void ApplyImpulse(GameObject coin)
        {
            var body = coin.GetComponent<Rigidbody>();
            if (body == null)
            {
                return;
            }

            var force = new Vector3(
                UnityEngine.Random.Range(-1f, 1f),
                UnityEngine.Random.Range(0.2f, 0.8f),
                UnityEngine.Random.Range(-1f, 1f));
            if (force.sqrMagnitude > 0.0001f)
            {
                force = force.normalized;
            }

            body.AddForce(force * spawnImpulse, ForceMode.Impulse);
            body.AddTorque(UnityEngine.Random.insideUnitSphere * torqueImpulse, ForceMode.Impulse);
        }

        private Vector3 GetSpawnPosition()
        {
            if (spawnVolume != null)
            {
                var bounds = spawnVolume.bounds;
                var x = UnityEngine.Random.Range(bounds.min.x, bounds.max.x);
                var y = UnityEngine.Random.Range(bounds.min.y, bounds.max.y);
                var z = UnityEngine.Random.Range(bounds.min.z, bounds.max.z);
                return new Vector3(x, y, z);
            }

            var origin = transform.position;
            return origin + new Vector3(
                UnityEngine.Random.Range(-spawnSpread, spawnSpread),
                UnityEngine.Random.Range(0.1f, 0.3f),
                UnityEngine.Random.Range(-spawnSpread, spawnSpread));
        }

        private Quaternion GetSpawnRotation()
        {
            return Quaternion.Euler(
                UnityEngine.Random.Range(-10f, 10f),
                UnityEngine.Random.Range(0f, 360f),
                UnityEngine.Random.Range(-10f, 10f));
        }

        private void BuildMaterialCache()
        {
            for (int i = 0; i < tokenTextures.Count; i++)
            {
                var entry = tokenTextures[i];
                if (entry.texture == null)
                {
                    continue;
                }

                var key = (entry.symbol ?? string.Empty).ToUpperInvariant();
                if (string.IsNullOrEmpty(key))
                {
                    continue;
                }

                _materialCache[key] = CreateMaterialInstance(entry.texture, key);
            }
        }

        private Material? ResolveMaterial(string symbol)
        {
            if (_materialCache.TryGetValue(symbol, out var cached) && cached != null)
            {
                return cached;
            }

            return null;
        }

        private Material CreateMaterialInstance(Texture2D texture, string symbol)
        {
            var template = coinMaterialTemplate != null
                ? new Material(coinMaterialTemplate)
                : new Material(Shader.Find("Standard"));

            template.name = $"M_{symbol}";
            if (texture != null)
            {
                if (template.HasProperty(BaseMapId))
                {
                    template.SetTexture(BaseMapId, texture);
                }

                if (template.HasProperty(MainTexId))
                {
                    template.SetTexture(MainTexId, texture);
                }
            }

            return template;
        }

        private void ApplyFallbackLabel(GameObject coin, string symbol, bool showLabel)
        {
            TextMeshPro? text = coin.GetComponentInChildren<TextMeshPro>(true);
            if (!showLabel)
            {
                if (text != null)
                {
                    text.gameObject.SetActive(false);
                }
                return;
            }

            if (fallbackMaterial != null)
            {
                var renderer = coin.GetComponentInChildren<MeshRenderer>();
                if (renderer != null)
                {
                    renderer.sharedMaterial = fallbackMaterial;
                }
            }

            if (text == null)
            {
                var textObject = new GameObject("CoinLabel");
                textObject.transform.SetParent(coin.transform, false);
                textObject.transform.localPosition = new Vector3(0f, 0.06f, 0f);
                textObject.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);

                text = textObject.AddComponent<TextMeshPro>();
                text.alignment = TextAlignmentOptions.Center;
                text.fontSize = 0.2f;
                text.enableWordWrapping = false;
            }

            text.text = symbol;
            text.color = fallbackTextColor;
            text.gameObject.SetActive(true);
        }
    }
}
