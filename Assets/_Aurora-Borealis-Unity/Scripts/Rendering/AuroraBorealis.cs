using RoyTheunissen.CurvesAndGradientsToTexture.Gradients;
using UnityEngine;

namespace RoyTheunissen.AuroraBorealisUnity.Rendering
{
    /// <summary>
    /// Passes on material properties required for rendering a raymarched aurora borealis effect.
    /// </summary>
    [ExecuteInEditMode]
    public sealed class AuroraBorealis : RaymarchingMaterialProperties 
    {
        private static readonly int PropertyPerlinTex = Shader.PropertyToID("_PerlinTex");
        private static readonly int PropertyColorFalloff = Shader.PropertyToID("_ColorFalloff");

        [SerializeField] private Texture perlinTexture;
        [SerializeField] private GradientTexture colorGradient;

        protected override void SetPropertyBlockProperties(MaterialPropertyBlock materialPropertyBlock)
        {
            base.SetPropertyBlockProperties(materialPropertyBlock);
            
            materialPropertyBlock.SetTexture(PropertyPerlinTex, perlinTexture);
            materialPropertyBlock.SetTexture(PropertyColorFalloff, colorGradient.Texture);
        }
    }
}
