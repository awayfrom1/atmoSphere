Shader "Atmo/AerialPerspectiveLut"
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

                float3 _aerialPerspectiveVoxelSize;
                float _aerialPerspectiveDistance;
            CBUFFER_END

                TEXTURE2D(_CameraDepthTexture);      SAMPLER(sampler_CameraDepthTexture);
                TEXTURE2D(_TransmittanceLut);        SAMPLER(sampler_TransmittanceLut);
                TEXTURE2D(_MulTransmittanceLut);        SAMPLER(sampler_MulTransmittanceLut);

            v2f vert(appdata v)
            {
                v2f o;
                o.positionWS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 uv = float3(0, 0, 0);
                uv.x = frac(i.uv.x * _aerialPerspectiveVoxelSize.z);
                uv.y = i.uv.y;
                uv.z = int(i.uv.x * _aerialPerspectiveVoxelSize.z) / _aerialPerspectiveVoxelSize.z;

                //光线步进距离限制
                half distance = uv.z * _aerialPerspectiveDistance;

                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                 float aspect = _ScreenParams.x / _ScreenParams.y;
                float3 viewDir = normalize(mul(unity_CameraToWorld, float4(
                    (uv.x * 2.0 - 1.0), 
                    (uv.y * 2.0 - 1.0) / aspect, 
                    1.0, 0.0
                )).xyz);
                float3 position1 = float3(0, _WorldSpaceCameraPos.y + _plantRadius, 0);
                float3 position2 = position1 + viewDir * distance;

            float3 atmoSphereColor = AtmosphereTransmittance(_rayMarchCount,
                _lightColor, _lightInstensity,
                _plantCenter, _plantRadius, _atmosphereHeight, distance,
                _mieScatteringScale, _mieAnisotropyScale, _mieScatteringHeight,
                _rayLeighScatteringScale, _rayLeighScatteringHeight,
                _ozoneAnisotropyScale, _ozoneHeight, _ozoneWidth, _ifMulAtmosphereRender, 
                position1, viewDir, lightDir, _mulAtmosphereRenderStrength,
                _TransmittanceLut, sampler_TransmittanceLut, _MulTransmittanceLut, sampler_MulTransmittanceLut);

                float t1 = AtmosphereLutTransmittance(_plantRadius, _atmosphereHeight, position1, _plantCenter,
                    lightDir, _TransmittanceLut, sampler_TransmittanceLut);
                float t2 = AtmosphereLutTransmittance(_plantRadius, _atmosphereHeight, position2, _plantCenter,
                    lightDir, _TransmittanceLut, sampler_TransmittanceLut);

                float t = t1 / t2;

                half4 color = half4(atmoSphereColor, dot(t, float3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)));
                color = max(0, color);
                return color;
            }
            ENDHLSL
        }
    }
}