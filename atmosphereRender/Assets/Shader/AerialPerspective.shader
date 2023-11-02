Shader "Atmo/AerialPerspective"
{
    Properties
    {
        _MainTex("_MainTex", 2D) = "White"{}
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
                float4 positionCS : SV_POSITION;
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

                float3 _aerialPerspectiveVoxelSize;
                float _aerialPerspectiveDistance;
                float _aerialInstensity;
                float _distanceAttenuation;
            CBUFFER_END
                TEXTURE2D(_MainTex);                 SAMPLER(sampler_MainTex);
                TEXTURE2D(_CameraDepthTexture);      SAMPLER(sampler_CameraDepthTexture);
                TEXTURE2D(_AerialPerspectiveLut);    SAMPLER(sampler_AerialPerspectiveLut);
                                                     SAMPLER(sampler_LinearClamp);

            v2f vert(appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                #if UNITY_REVERSED_Z
                    if(depth == 0.0f) return col;
                #else
                    if(depth == 1.0f) col;
                #endif
                float4 ndc = float4(i.uv * 2 + 1, depth, 1);
                #if UNITY_UV_STARTS_AT_TOP
                    ndc.y *= -1;
                #endif
                float4 worldPos = mul(UNITY_MATRIX_I_VP, ndc);
                worldPos.xyz /= worldPos.w;
                
                float3 eyePos = _WorldSpaceCameraPos.xyz;
                float dis = length(worldPos - eyePos);
                
                float dis01 = saturate(dis / _aerialPerspectiveDistance);
                float dis0Z = dis01 * (_aerialPerspectiveVoxelSize.z - 1);  // [0 ~ SizeZ-1]
                float slice = floor(dis0Z);
                float nextSlice = min(slice + 1, _aerialPerspectiveVoxelSize.z - 1);
                float lerpFactor = dis0Z - floor(dis0Z);
                
                float2 uv = i.uv;
                uv.x /= _aerialPerspectiveVoxelSize.z;
                uv.y = uv.y * 0.5 + 0.5;
                float2 uv0 = float2(uv.x + slice / _aerialPerspectiveVoxelSize.z, uv.y);
                float2 uv1 = float2(uv.x + nextSlice / _aerialPerspectiveVoxelSize.z, uv.y);
                float4 aerialPerspective0 = SAMPLE_TEXTURE2D(_AerialPerspectiveLut, sampler_LinearClamp, uv0);
                float4 aerialPerspective1 = SAMPLE_TEXTURE2D(_AerialPerspectiveLut, sampler_LinearClamp, uv1);
                float4 aerialPerspective = lerp(aerialPerspective0, aerialPerspective1, lerpFactor);
                aerialPerspective = lerp(col, aerialPerspective, i.uv.y);
                col.xyz = lerp(col.xyz, aerialPerspective.xyz, pow(Linear01Depth(depth, _ZBufferParams), _distanceAttenuation) * _aerialInstensity);
                return col;
            }
            ENDHLSL
        }
    }
}