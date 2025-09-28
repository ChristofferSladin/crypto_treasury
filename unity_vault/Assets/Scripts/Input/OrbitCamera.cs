using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace CameraRig
{
    /// <summary>
    /// Simple orbit camera suitable for WebGL builds.
    /// </summary>
    public class OrbitCamera : MonoBehaviour
    {
        [SerializeField] private Transform pivot = default!;
        [SerializeField] private float distance = 6f;
        [SerializeField] private float minDistance = 3f;
        [SerializeField] private float maxDistance = 12f;
        [SerializeField] private Vector2 pitchLimits = new(10f, 70f);
        [SerializeField] private float yawSensitivity = 0.2f;
        [SerializeField] private float pitchSensitivity = 0.2f;
        [SerializeField] private float zoomSensitivity = 2f;
        [SerializeField] private float smoothing = 0.15f;

        private Vector2 _targetAngles;
        private Vector2 _currentAngles;
        private float _targetDistance;
        private float _currentDistance;
        private Vector2 _angleVelocity;
        private float _zoomVelocity;

        private void Start()
        {
            var euler = transform.eulerAngles;
            _currentAngles = _targetAngles = new Vector2(NormalizeAngle(euler.x), NormalizeAngle(euler.y));
            _currentDistance = _targetDistance = Mathf.Clamp(distance, minDistance, maxDistance);
        }

        private void LateUpdate()
        {
            if (pivot == null)
            {
                return;
            }

            HandleInput();

            _currentAngles = Vector2.SmoothDamp(_currentAngles, _targetAngles, ref _angleVelocity, smoothing);
            _currentDistance = Mathf.SmoothDamp(_currentDistance, _targetDistance, ref _zoomVelocity, smoothing);

            var rotation = Quaternion.Euler(_currentAngles.x, _currentAngles.y, 0f);
            var offset = rotation * new Vector3(0f, 0f, -_currentDistance);
            transform.position = pivot.position + offset;
            transform.rotation = rotation;
        }

        private void HandleInput()
        {
#if ENABLE_INPUT_SYSTEM
            var mouse = Mouse.current;
            if (mouse != null)
            {
                if (mouse.leftButton.isPressed)
                {
                    var delta = mouse.delta.ReadValue();
                    _targetAngles.y += delta.x * yawSensitivity;
                    _targetAngles.x -= delta.y * pitchSensitivity;
                }

                var scroll = mouse.scroll.ReadValue().y;
                if (Mathf.Abs(scroll) > Mathf.Epsilon)
                {
                    _targetDistance -= scroll * zoomSensitivity * 0.01f;
                }
            }

            var touchscreen = Touchscreen.current;
            if (touchscreen != null && touchscreen.touches.Count > 0)
            {
                var primary = touchscreen.touches[0];
                if (primary.isInProgress)
                {
                    var delta = primary.delta.ReadValue();
                    _targetAngles.y += delta.x * yawSensitivity * Time.deltaTime;
                    _targetAngles.x -= delta.y * pitchSensitivity * Time.deltaTime;
                }

                if (touchscreen.touches.Count >= 2)
                {
                    var touch0 = touchscreen.touches[0];
                    var touch1 = touchscreen.touches[1];
                    if (touch0.isInProgress && touch1.isInProgress)
                    {
                        var prev0 = touch0.position.ReadValue() - touch0.delta.ReadValue();
                        var prev1 = touch1.position.ReadValue() - touch1.delta.ReadValue();
                        var prevMagnitude = (prev0 - prev1).magnitude;
                        var currentMagnitude = (touch0.position.ReadValue() - touch1.position.ReadValue()).magnitude;
                        var deltaMagnitude = currentMagnitude - prevMagnitude;
                        _targetDistance -= deltaMagnitude * zoomSensitivity * 0.001f;
                    }
                }
            }
#else
            if (Input.GetMouseButton(0))
            {
                var delta = new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y"));
                _targetAngles.y += delta.x * yawSensitivity * 100f * Time.deltaTime;
                _targetAngles.x -= delta.y * pitchSensitivity * 100f * Time.deltaTime;
            }

            var scroll = Input.mouseScrollDelta.y;
            if (Mathf.Abs(scroll) > Mathf.Epsilon)
            {
                _targetDistance -= scroll * zoomSensitivity * Time.deltaTime;
            }
#endif

            _targetAngles.x = Mathf.Clamp(_targetAngles.x, pitchLimits.x, pitchLimits.y);
            _targetDistance = Mathf.Clamp(_targetDistance, minDistance, maxDistance);
        }

        private static float NormalizeAngle(float angle)
        {
            while (angle > 180f) angle -= 360f;
            while (angle < -180f) angle += 360f;
            return angle;
        }
    }
}
