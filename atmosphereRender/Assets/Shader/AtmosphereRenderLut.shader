Shader "Atmo/AtmosphereRenderLut"
{
    Properties
    {
    }
    SubShader
    {
        Tags {"PreviewType" = "Skybox" "RenderType" = "Background" "Queue" = "Background"}
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "AtmosphereCore.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionWS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _plantCenter;
                float4 _lightColor;

                float _ifMulAtmosphereRender;
                float _lightInstensity;
                float _rayMarchCount;
                float _plantRadius;
                float _atmosphereHeight;
                float _mieScatteringScale;
                float _mieAnisotropyScale;
                float _mieScatteringHeight;
                float _rayLeighScatteringScale;
                float _rayLeighScatteringHeight;
                float _ozoneAnisotropyScale;
                float _ozoneHeight;
                float _ozoneWidth;
                float _mulAtmosphereRenderStrength;
            CBUFFER_END

            TEXTURE2D(_CameraDepthTexture);      SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_TransmittanceLut);        SAMPLER(sampler_TransmittanceLut);
            TEXTURE2D(_MulTransmittanceLut);        SAMPLER(sampler_MulTransmittanceLut);

            v2f vert (appdata v)
            {
                v2f o;
                o.positionWS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                float3 viewDir = UvToViewDir(i.uv);
                float3 position = float3(0, _WorldSpaceCameraPos.y + _plantRadius, 0); 
                
                float3 atmoSphereColor = AtmosphereTransmittance(_rayMarchCount,
                _lightColor, _lightInstensity,
                _plantCenter, _plantRadius, _atmosphereHeight, -1,
                _mieScatteringScale, _mieAnisotropyScale, _mieScatteringHeight,
                _rayLeighScatteringScale, _rayLeighScatteringHeight,
                _ozoneAnisotropyScale, _ozoneHeight, _ozoneWidth, _ifMulAtmosphereRender,
                position, viewDir, lightDir, _mulAtmosphereRenderStrength, 
                _TransmittanceLut, sampler_TransmittanceLut, _MulTransmittanceLut, sampler_MulTransmittanceLut);
                
                float4 col = float4(atmoSphereColor, 1);
                return col;
            }
            ENDHLSL
        }
    }
}
