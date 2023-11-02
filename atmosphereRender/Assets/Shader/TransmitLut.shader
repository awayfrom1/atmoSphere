Shader "Atmo/TransmitLut"
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
            CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.positionWS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 col = RenderTransmittanceLut(i.uv, _rayMarchCount,
	            _plantRadius, _plantCenter, _atmosphereHeight, 
	            _mieScatteringScale, _mieAnisotropyScale, _mieScatteringHeight,
	            _rayLeighScatteringScale, _rayLeighScatteringHeight,
	            _ozoneAnisotropyScale, _ozoneHeight, _ozoneWidth);
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
