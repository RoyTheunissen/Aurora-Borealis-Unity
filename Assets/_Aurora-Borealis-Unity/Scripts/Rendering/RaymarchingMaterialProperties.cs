using System;
using UnityEngine;

namespace RoyTheunissen.AuroraBorealisUnity.Rendering
{
    /// <summary>
    /// Passes on material properties required for ray marching.
    /// </summary>
    public class RaymarchingMaterialProperties : MonoBehaviour
    {
        private static readonly int PropertyToLocalWithoutScale = Shader.PropertyToID("_ToLocalWithoutScale");
        private static readonly int PropertyToWorldWithoutScale = Shader.PropertyToID("_ToWorldWithoutScale");
        private static readonly int PropertyBoundsSize = Shader.PropertyToID("_BoundsSize");

        public static readonly Vector4[] DebugColors =
        {
            Color.blue,
            Color.cyan,
            Color.green,
            Color.yellow,
            Color.Lerp(Color.red, Color.yellow, 0.5f),
            Color.red,
            Color.magenta,
            Color.white,
            Color.black,
        };

        [SerializeField] private Renderer[] renderers = new Renderer[0];
        
        [NonSerialized] private MaterialPropertyBlock cachedMaterialPropertyBlock;
        [NonSerialized] private bool didCacheBounds;
        [NonSerialized] private Bounds cachedBounds;

        private MaterialPropertyBlock MaterialPropertyBlock
        {
            get
            {
                if (cachedMaterialPropertyBlock == null)
                    cachedMaterialPropertyBlock = new MaterialPropertyBlock();
                return cachedMaterialPropertyBlock;
            }
        }

        private Transform BoundsTransform => transform;
        private Bounds Bounds
        {
            get
            {
                if (!didCacheBounds || !Application.isPlaying)
                {
                    cachedBounds = new Bounds(BoundsTransform.position, BoundsTransform.lossyScale);
                    didCacheBounds = true;
                }
                return cachedBounds;
            }
        }

        private void OnEnable()
        {
            // I don't think we actually need this, it's the deferred rendering path and there's various depth-based
            // image effects like DOF. Depth Normals are gonna be there already.
            // This seems to throw a null ref for some reason.
            //mainCamera.Reference.Camera.depthTextureMode = DepthTextureMode.DepthNormals;
            
            Camera.onPreRender -= HandleOnPreRenderEvent;
            Camera.onPreRender += HandleOnPreRenderEvent;
        }

        private void OnDisable()
        {
            Camera.onPreRender -= HandleOnPreRenderEvent;
        }

        private void HandleOnPreRenderEvent(Camera camera)
        {
            // Ray reconstruction is dependant on data from the camera, so we need to pass along that data per camera
            // for effects to work correctly in the scene view too.
            ApplyPropertyBlocks();
        }

        private void ApplyPropertyBlocks()
        {
            for (int i = 0; i < renderers.Length; i++)
            {
                if (renderers[i] == null)
                    continue;

                renderers[i].GetPropertyBlock(MaterialPropertyBlock);

                SetPropertyBlockProperties(MaterialPropertyBlock);

                renderers[i].SetPropertyBlock(MaterialPropertyBlock);
            }
        }

        protected virtual void SetPropertyBlockProperties(MaterialPropertyBlock materialPropertyBlock)
        {
            materialPropertyBlock.SetVectorArray("_DebugColors", DebugColors);
            
            // Pass on the bounds.
            Matrix4x4 toWorldWithoutScale = Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one);
            materialPropertyBlock.SetMatrix(PropertyToLocalWithoutScale, toWorldWithoutScale.inverse);
            materialPropertyBlock.SetMatrix(PropertyToWorldWithoutScale, toWorldWithoutScale);
            materialPropertyBlock.SetVector(PropertyBoundsSize, Bounds.size);

            // Viewport info for ray reconstruction
            // We call this in OnPreRender so that this stuff works for every camera including the scene camera.
            Camera camera = Camera.current;
            if (camera != null)
            {
                float farClip = camera.farClipPlane;
                float fovWHalf = camera.fieldOfView * 0.5f;
                float dY = Mathf.Tan(fovWHalf * Mathf.Deg2Rad);
                float dX = dY * camera.aspect;
                Vector3 viewportCorner = camera.transform.forward * farClip;
                Vector3 viewportRight = camera.transform.right * dX * farClip;
                Vector3 viewportUp = camera.transform.up * dY * farClip;
                materialPropertyBlock.SetVector("_ViewportCorner", viewportCorner - viewportRight - viewportUp);
                materialPropertyBlock.SetVector("_ViewportRight", viewportRight * 2.0f);
                materialPropertyBlock.SetVector("_ViewportUp", viewportUp * 2.0f);
            }
        }
    }
}
