using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AtmosphereRender : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

        [Header("散射系数:")]
        public Material atmosphereRenderLutMat;
        public Material transmitLutMat;
        public float lightInstensity = 31.4f;
        public Color lightColor;
        public float rayMarchCount = 32;
        public Vector3 plantCenter = Vector3.zero;
        public float plantRadius = 6360000;
        public float atmosphereHeight = 60000;
        [Range(0.0f, 3.0f)]
        public float mieScatteringScale = 0.5f;
        [Range(0.0f, 1.0f)]
        public float mieAnisotropyScale = 0.5f;
        public float mieScatteringHeight = 8000;
        [Range(0.0f, 1.0f)]
        public float rayLeighScatteringScale = 1.0f;
        public float rayLeighScatteringHeight = 15000;
        [Range(0.0f, 1.0f)]
        public float ozoneAnisotropyScale = 0.8f;
        public float ozoneHeight = 25000;
        public float ozoneWidth = 15000;

        [Header("多级散射系数:")]
        public bool ifMulAtmosphereRender = true;
        public Material mulTransmitLutMat;
        [Range(0.0f, 10.0f)]
        public float mulAtmosphereRenderStrength;

        [Header("AerialPerspective系数:")]
        public bool ifRenderAerialPerspective = true;
        public Material aerialPerspectiveLutMat;
        public Material aerialPerspectiveMat;
        public float aerialPerspectiveDistance = 1;
        [Range(0.0f, 2.0f)]
        public float aerialInstensity = 1;
        [Range(0.0f, 10.0f)]
        public float aerialDistanceAttenuation = 1;
    }

    public Setting setting = new Setting();

    public class AtmoLutPass : ScriptableRenderPass
    {
        private Setting setting;
        private Material atmosphereRenderLutMat;
        private Material transmitLutMat;
        private Material mulTransmitLutMat;
        private Material aerialPerspectiveLutMat;
        private RenderTexture transmitLut;
        private RenderTexture multransmitLut;
        private RenderTexture skyBoxColor;
        private RenderTexture aerialPerspectiveLut;

        private int lightColorID = Shader.PropertyToID("_lightColor");
        private int lightInstensityID = Shader.PropertyToID("_lightInstensity");
        private int rayMarchCountID = Shader.PropertyToID("_rayMarchCount");
        private int plantCenterID = Shader.PropertyToID("_plantCenter");
        private int plantRadiusID = Shader.PropertyToID("_plantRadius");
        private int atmosphereHeightID = Shader.PropertyToID("_atmosphereHeight");
        private int mieScatteringScaleID = Shader.PropertyToID("_mieScatteringScale");
        private int mieAnisotropyScaleID = Shader.PropertyToID("_mieAnisotropyScale");
        private int mieScatteringHeightID = Shader.PropertyToID("_mieScatteringHeight");
        private int rayLeighScatteringScaleID = Shader.PropertyToID("_rayLeighScatteringScale");
        private int rayLeighScatteringHeightID = Shader.PropertyToID("_rayLeighScatteringHeight");
        private int ozoneAnisotropyScaleID = Shader.PropertyToID("_ozoneAnisotropyScale");
        private int ozoneHeightID = Shader.PropertyToID("_ozoneHeight");
        private int ozoneWidthID = Shader.PropertyToID("_ozoneWidth");
        private int ifMulAtmosphereRenderID = Shader.PropertyToID("_ifMulAtmosphereRender");
        private int mulAtmosphereRenderStrengthID = Shader.PropertyToID("_mulAtmosphereRenderStrength");
        private int aerialPerspectiveDistanceID = Shader.PropertyToID("_aerialPerspectiveDistance");
        private int aerialPerspectiveVoxelSizeID = Shader.PropertyToID("_aerialPerspectiveVoxelSize");

        private int atmoSphereScatterTexID = Shader.PropertyToID("_atmoSphereScatterTex");
        private int transmitLutID = Shader.PropertyToID("_TransmittanceLut");
        private int mulTransmitLutID = Shader.PropertyToID("_MulTransmittanceLut");
        private int aerialPerspectiveLutID = Shader.PropertyToID("_AerialPerspectiveLut");
        public AtmoLutPass(Setting setting)
        {
            this.setting = setting;
            this.atmosphereRenderLutMat = this.setting.atmosphereRenderLutMat;
            this.transmitLutMat = this.setting.transmitLutMat;
            this.mulTransmitLutMat = this.setting.mulTransmitLutMat;
            this.aerialPerspectiveLutMat = this.setting.aerialPerspectiveLutMat;
            this.renderPassEvent = this.setting.Event;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureTarget(skyBoxColor);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            transmitLut = RenderTexture.GetTemporary(256, 128, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            if (this.setting.ifMulAtmosphereRender)
            {
                multransmitLut = RenderTexture.GetTemporary(256, 128, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            }
            skyBoxColor = RenderTexture.GetTemporary(256, 128, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            if (this.setting.ifRenderAerialPerspective)
            {
                aerialPerspectiveLut = RenderTexture.GetTemporary(32 * 32, 32, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            }
            CommandBuffer cmd = CommandBufferPool.Get("atmosphereRender");
            cmd.SetGlobalColor(lightColorID, this.setting.lightColor);
            cmd.SetGlobalFloat(lightInstensityID, this.setting.lightInstensity);
            cmd.SetGlobalFloat(rayMarchCountID, this.setting.rayMarchCount);
            cmd.SetGlobalVector(plantCenterID, this.setting.plantCenter);
            cmd.SetGlobalFloat(plantRadiusID, this.setting.plantRadius);
            cmd.SetGlobalFloat(atmosphereHeightID, this.setting.atmosphereHeight);
            cmd.SetGlobalFloat(mieScatteringScaleID, this.setting.mieScatteringScale);
            cmd.SetGlobalFloat(mieAnisotropyScaleID, this.setting.mieAnisotropyScale);
            cmd.SetGlobalFloat(mieScatteringHeightID, this.setting.mieScatteringHeight);
            cmd.SetGlobalFloat(rayLeighScatteringScaleID, this.setting.rayLeighScatteringScale);
            cmd.SetGlobalFloat(rayLeighScatteringHeightID, this.setting.rayLeighScatteringHeight);
            cmd.SetGlobalFloat(rayLeighScatteringHeightID, this.setting.rayLeighScatteringHeight);
            cmd.SetGlobalFloat(ozoneAnisotropyScaleID, setting.ozoneAnisotropyScale);
            cmd.SetGlobalFloat(ozoneHeightID, this.setting.ozoneHeight);
            cmd.SetGlobalFloat(ozoneWidthID, this.setting.ozoneWidth);
            cmd.SetGlobalInt(ifMulAtmosphereRenderID, this.setting.ifMulAtmosphereRender ? 1 : 0);
            cmd.SetGlobalFloat(mulAtmosphereRenderStrengthID, this.setting.mulAtmosphereRenderStrength * 10);
            cmd.SetGlobalFloat(aerialPerspectiveDistanceID, this.setting.aerialPerspectiveDistance);
            cmd.SetGlobalVector(aerialPerspectiveVoxelSizeID, new Vector3(32, 32, 32));

            cmd.Blit(null, transmitLut, transmitLutMat);
            cmd.SetGlobalTexture(transmitLutID, transmitLut);
            if (this.setting.ifMulAtmosphereRender)
            {
                cmd.Blit(null, multransmitLut, mulTransmitLutMat);
                cmd.SetGlobalTexture(mulTransmitLutID, multransmitLut);
            }
            cmd.Blit(null, skyBoxColor, atmosphereRenderLutMat);
            cmd.SetGlobalTexture(atmoSphereScatterTexID, skyBoxColor);
            if (this.setting.ifRenderAerialPerspective)
            {
                cmd.Blit(null, aerialPerspectiveLut, aerialPerspectiveLutMat);
                cmd.SetGlobalTexture(aerialPerspectiveLutID, aerialPerspectiveLut);
            }

            RenderTexture.ReleaseTemporary(transmitLut);
            RenderTexture.ReleaseTemporary(skyBoxColor);
            if (this.setting.ifMulAtmosphereRender)
            {
                RenderTexture.ReleaseTemporary(multransmitLut);
            }
            if (this.setting.ifRenderAerialPerspective)
            {
                RenderTexture.ReleaseTemporary(aerialPerspectiveLut);
            }
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        public override void FrameCleanup(CommandBuffer cmd)
        {
            base.FrameCleanup(cmd);
        }
    }

    //地表物件AerialPerspective后处理
    public class AerialPerspective : ScriptableRenderPass
    {
        private Setting setting;
        private Material aerialPerspectiveMat;

        private RenderTargetIdentifier sour;
        private int tempID = Shader.PropertyToID("_temp");
        private int aerialPerspectiveDistanceID = Shader.PropertyToID("_aerialPerspectiveDistance");
        private int distanceAttenuationID = Shader.PropertyToID("_distanceAttenuation");
        private int aerialInstensityID = Shader.PropertyToID("_aerialInstensity");

        public AerialPerspective(Setting setting)
        {
            this.setting = setting;
            this.aerialPerspectiveMat = setting.aerialPerspectiveMat;
            this.renderPassEvent = setting.Event + 1;
        }

        public void Setup(RenderTargetIdentifier sour)
        {
            this.sour = sour;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (this.setting.ifRenderAerialPerspective)
            {
                CommandBuffer cmd = CommandBufferPool.Get("aerialPerspective");
                cmd.SetGlobalFloat(aerialPerspectiveDistanceID, this.setting.aerialPerspectiveDistance);
                cmd.SetGlobalFloat(aerialInstensityID, this.setting.aerialInstensity);
                cmd.SetGlobalFloat(distanceAttenuationID, this.setting.aerialDistanceAttenuation);
                cmd.GetTemporaryRT(tempID, renderingData.cameraData.cameraTargetDescriptor);
                cmd.Blit(sour, tempID);
                cmd.Blit(tempID, sour, aerialPerspectiveMat);
                cmd.ReleaseTemporaryRT(tempID);
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }
        }
    }

    AtmoLutPass pass;
    AerialPerspective pass0;
    public override void Create()
    {
        pass = new AtmoLutPass(setting);
        pass0 = new AerialPerspective(setting);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
        pass0.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(pass0);
    }
}
