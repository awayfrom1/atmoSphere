Shader "Atmo/skyBox"
{
    Properties
    {
        [Header(Sun)]
        _SunInnerBoundaryColor("太阳内维颜色", Color) = (1, 1, 1, 1)
        _SunInnerBoundary("太阳内维", Range(0, 1)) = 0
        _SunOuterBoundaryColor("太阳外维颜色", Color) = (1, 1, 1, 1)
        _SunOuterBoundary("太阳外维", Range(0, 1)) = 1
        _SunRadius("太阳大小", Range(0, 1)) = 1
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
                float4 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _SunInnerBoundaryColor;
                half4 _SunOuterBoundaryColor;

                half _SunInnerBoundary;
                half _SunOuterBoundary;

                half _SunRadius;
            CBUFFER_END
            
            TEXTURE2D(_atmoSphereScatterTex);   SAMPLER(sampler_atmoSphereScatterTex);

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.positionWS = TransformObjectToWorld(v.positionOS);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                half3 viewPos = _WorldSpaceCameraPos;
                half3 viewDir = i.uv.xyz;
                //float3 viewDir = normalize(TransformWorldToViewDir(i.positionWS));
                float2 uv = ViewDirToUv(viewDir);
                float3 skyColor = SAMPLE_TEXTURE2D(_atmoSphereScatterTex, sampler_atmoSphereScatterTex, uv);

                //地平线位置
                half verticalPos = i.uv.y * 0.5 + 0.5;

                half sunDist = distance(i.uv.xyz, lightDir);
                half sunArea = saturate(1 - sunDist / _SunRadius);
                half SunInnerBoundary = min(_SunInnerBoundary, _SunOuterBoundary);
                half SunOuterBoundary = max(_SunInnerBoundary, _SunOuterBoundary);
                sunArea = smoothstep(SunInnerBoundary, SunOuterBoundary, sunArea) * step(0.5, verticalPos);
                half3 sunColor = lerp(_SunOuterBoundaryColor, _SunInnerBoundaryColor, sunArea) * lerp(0.0001, 1, sunArea) * step(0.5, verticalPos);
                
                sunColor = saturate(sunColor);

                skyColor = skyColor + sunColor;
                return half4(skyColor, 1);
            }
            ENDHLSL
        }
    }
}