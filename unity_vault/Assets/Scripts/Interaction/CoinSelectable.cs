#nullable enable

using Messaging;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Interaction
{
    /// <summary>
    /// Adds hover highlighting and click selection behaviour to spawned coins.
    /// </summary>
    [RequireComponent(typeof(Collider))]
    public class CoinSelectable : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler, IPointerClickHandler
    {
        [SerializeField] private Renderer? targetRenderer = default;
        [SerializeField] private Color highlightColor = new(0.2f, 0.8f, 1f, 1f);
        [SerializeField] private float highlightIntensity = 1.2f;
        [SerializeField] private float highlightLerpSpeed = 6f;

        private MaterialPropertyBlock? _propertyBlock;
        private bool _hovering;
        private float _currentWeight;

        private static readonly int EmissionColorId = Shader.PropertyToID("_EmissionColor");

        public string Symbol { get; private set; } = string.Empty;
        public int CountPerCoin { get; private set; }

        private void Awake()
        {
            if (targetRenderer == null)
            {
                targetRenderer = GetComponentInChildren<Renderer>();
            }

            _propertyBlock = new MaterialPropertyBlock();
            EnsureEmissionKeyword();
        }

        private void Update()
        {
            var target = _hovering ? 1f : 0f;
            _currentWeight = Mathf.MoveTowards(_currentWeight, target, Time.deltaTime * highlightLerpSpeed);
            ApplyHighlight(_currentWeight);
        }

        /// <summary>
        /// Assigns runtime data for the coin instance.
        /// </summary>
        public void Configure(string symbol, int countPerCoin)
        {
            Symbol = symbol;
            CountPerCoin = countPerCoin;
        }

        public void OnPointerEnter(PointerEventData eventData) => SetHover(true);
        public void OnPointerExit(PointerEventData eventData) => SetHover(false);

        public void OnPointerClick(PointerEventData eventData)
        {
            Bridge.PostCoinSelection(Symbol, CountPerCoin);
        }

        private void OnMouseEnter() => SetHover(true);
        private void OnMouseExit() => SetHover(false);
        private void OnMouseDown() => Bridge.PostCoinSelection(Symbol, CountPerCoin);

        public void SetHover(bool hover)
        {
            _hovering = hover;
        }

        private void ApplyHighlight(float weight)
        {
            if (targetRenderer == null || _propertyBlock == null)
            {
                return;
            }

            targetRenderer.GetPropertyBlock(_propertyBlock);

            var baseColor = Color.black;
            if (targetRenderer.sharedMaterial != null && targetRenderer.sharedMaterial.HasProperty(EmissionColorId))
            {
                baseColor = targetRenderer.sharedMaterial.GetColor(EmissionColorId);
            }

            var targetColor = highlightColor * highlightIntensity;
            var emission = Color.Lerp(baseColor, targetColor, weight);
            _propertyBlock.SetColor(EmissionColorId, emission);
            targetRenderer.SetPropertyBlock(_propertyBlock);
        }

        private void EnsureEmissionKeyword()
        {
            if (targetRenderer?.sharedMaterial == null)
            {
                return;
            }

            targetRenderer.sharedMaterial.EnableKeyword("_EMISSION");
        }
    }
}
