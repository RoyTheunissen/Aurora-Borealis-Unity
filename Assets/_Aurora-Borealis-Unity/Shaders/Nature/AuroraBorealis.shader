Shader "Custom/Aurora Borealis"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR] _Color ("Color", Color) = (1,1,1,1)
        _StepSize ("Step Size", Range(0.01, 1000)) = 0.1
        _Opacity ("Opacity", Range(0, 1)) = 0.1
        _StartYVariation ("Start Y Variation", Range(0, 1)) = 1.0
        
        _Perlin1Settings ("Perlin 1 Offset & Scale", Vector) = (0, 0, 8.9234, 0)
        _Perlin2Settings ("Perlin 2 Offset & Scale", Vector) = (0.43423, 0.1963, 6.348, 0)
        _PerlinSettings ("Perlin Push Threshold & Scale", Vector) = (0.001, 10, 0, 0)
        _PerlinScrollSpeeds ("Perlin Scroll Speeds", Vector) = (-0.001234, 0.0009374, 0.0021234, -0.001634)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
        
        ZWrite Off
        Blend One One

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Master.cginc"

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            sampler2D _PerlinTex;
            
            float4 _Color;
            
            float _StepSize;
            float _Opacity;
            
            float _StartYVariation;
            
            // Noise settings
            float4 _Perlin1Settings;
            float4 _Perlin2Settings;
            float4 _PerlinSettings;
            float4 _PerlinScrollSpeeds;
            
            // Viewport info for ray construction
            uniform fixed3 _ViewportCorner;
            uniform fixed3 _ViewportRight;
            uniform fixed3 _ViewportUp;
            
            // Shape settings.
            float4x4 _ToLocalWithoutScale;
            float4x4 _ToWorldWithoutScale;
            float4 _BoundsSize;
            
            sampler2D _ColorFalloff;
            
            sampler2D_float _CameraDepthTexture;
            
            // Thank you devuxer from StackOverflow!
            // https://stackoverflow.com/a/3115514
            inline void IntersectRayBox(float3 origin, float3 size, float3 rayDir, out float t0, out float t1)
            {
                float3 segmentBegin = _WorldSpaceCameraPos;
                float3 segmentEnd = _WorldSpaceCameraPos + rayDir * _ProjectionParams.z;
                
                float3 beginToEnd = segmentEnd - segmentBegin;
                float3 minToMax = float3(size.x, size.y, size.z);
                float3 minPoint = origin - minToMax / 2;
                float3 maxPoint = origin + minToMax / 2;
                float3 beginToMin = minPoint - segmentBegin;
                float3 beginToMax = maxPoint - segmentBegin;
                float tNear = -99999999;
                float tFar = 99999999;
                float distance = length(beginToEnd);
            
                t0 = t1 = 0;
                
                for (int axis = 0; axis < 3; axis++)
                {
                    if (beginToEnd[axis] == 0) // parallel
                    {
                        if (beginToMin[axis] > 0 || beginToMax[axis] < 0)
                            discard; // segment is not between planes
                    }
                    else
                    {
                        float d0 = beginToMin[axis] / beginToEnd[axis];
                        float d1 = beginToMax[axis] / beginToEnd[axis];
                        float tMin = min(d0, d1);
                        float tMax = max(d0, d1);
                        if (tMin > tNear) tNear = tMin;
                        if (tMax < tFar) tFar = tMax;
                        if (tNear > tFar || tFar < 0) discard;
                    }
                }
                if (tNear >= 0 && tNear <= 1) t0 = (distance * tNear);
                if (tFar >= 0 && tFar <= 1) t1 = (distance * tFar);
            
                // From here on it's cleanup duplicates from the capsule/sphere functions
                t0 = max(t0, 0);
                t1 = max(t1, 0);
            
                t0 = min(t0, t1);
                t1 = max(t0, t1);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                o.viewDir = WorldSpaceViewDir(v.vertex);
                o.viewDir.y *= -1;
                o.viewDir.x *= -1;
                o.viewDir.z *= -1;
                
                o.screenPos = ComputeScreenPos(o.vertex);
                
                return o;
            }
            
            float GetNoise(float3 worldPos, out float height, out float yStart)
            {
                // The main mask of the effect is a "difference clouds" of two scrolling Perlin noise textures.
                // This gives a "marble-like" noise pattern of which we then increase the contrast to arrive at our
                // aesthetically pleasing aurora borealis pattern.
                float2 offset1 = _PerlinScrollSpeeds.xy * _Time.x;
                float2 offset2 = _PerlinScrollSpeeds.zw * _Time.y;
                fixed4 perlin1 = tex2Dlod(_PerlinTex, float4((worldPos.xz + _Perlin1Settings.xy) / _Perlin1Settings.z + offset1, 0, 0));
                fixed4 perlin2 = tex2Dlod(_PerlinTex, float4((worldPos.xz + _Perlin2Settings.xy) / _Perlin2Settings.z + offset2, 0, 0));
                float threshold = _PerlinSettings.x;
                float push = _PerlinSettings.y;
                float noise = abs(perlin1.b - perlin2.g);
                noise = (noise - threshold) * push + threshold;
                
                // Apply some noise to the height of the effect.
                height = perlin1.a;
                
                // Vertically offset the effect somewhat, too.
                yStart = (perlin2.a - .5) * 2 * _StartYVariation;
                
                return 1 - saturate(noise);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 screenUV = (i.screenPos.xy / i.screenPos.w);
                
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, fixed3(screenUV, 1));
                float linearDepth = Linear01Depth(rawDepth);
                
                float3 rayViewDir = normalize(i.viewDir);
                float3 rayCompensated = _ViewportCorner + _ViewportRight * screenUV.x + _ViewportUp * screenUV.y;
                
                float3 ray = rayViewDir;
                
                float3 worldPosition = _WorldSpaceCameraPos +  
                    rayCompensated * linearDepth        // This calculates the scene depth while compensating for lens distortion.
                    ;
                    
                float distanceToEntrance;
                float distanceToExit;
                
                float3 boundsOrigin = mul(_ToWorldWithoutScale, float4(0, 0, 0, 1));
                IntersectRayBox(boundsOrigin, _BoundsSize, ray, distanceToEntrance, distanceToExit);
                
                float distance = distanceToEntrance;
                fixed3 color = 0;
                float opacityPerStep = _Opacity * _StepSize;
                while (distance < distanceToExit)
                {
                    float3 samplePosition = _WorldSpaceCameraPos + ray * distance;
                    
                    float3 localPos = mul(unity_WorldToObject, float4(samplePosition, 1)).xyz;
                    
                    float height;
                    float yStart;
                    float noise = GetNoise(localPos, height, yStart);
                    
                    // Also apply some noise to the height of the effect to make a more interesting shape.
                    height = 1 - pow(1 - height, 2);
                    
                    // Mask out the edges to get a smoother look.
                    float edgeMaskX = 1 - (abs(localPos.x) * 2);
                    float y = map(localPos.y + yStart, -.5 * height, .5 * height, 0, 1);
                    float edgeMaskZ = 1 - (abs(localPos.z) * 2);
                    float edgeMask = min(edgeMaskX, edgeMaskZ);
                    
                    float4 localColor = tex2Dlod(_ColorFalloff, float4(y, 0, 0, 0));
                    
                    color += _Color * _Color.a * localColor * localColor.a * opacityPerStep * edgeMask * noise;
                    distance += _StepSize;
                }
                
                return fixed4(color, 1);
            }
            
            ENDCG
        }
    }
}
