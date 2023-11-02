#include"Math.hlsl"

//
//散射函数
//

//大气高度密度函数
inline float HeightAtmosphereThickness(float height, float h)
{
	return exp(-(h / height));
}

//RayLeigh散射
inline float3 Rayleigh_Coefficient(float rayLeighScatteringScale, float rayLeighScatteringHeight, float height)
{
	const float3 sigma = float3(5.802, 13.558, 33.1) * 1e-6;
	float thp = HeightAtmosphereThickness(rayLeighScatteringHeight, height);
	return sigma * thp * rayLeighScatteringScale;
}

//RayLeigh相位函数
inline float Rayleight_Phase(float cosTheta)
{
	float phase = (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
	return phase;
}

//Mie散射
inline float3 Mie_Coefficient(float mieScatteringScale, float mieScatteringHeight, float height)
{
	const float3 sigma = float3(3.996, 3.996, 3.996) * 1e-6;
	float thp = HeightAtmosphereThickness(mieScatteringHeight, height);
	return sigma * thp * mieScatteringScale;
}

//Mie散射相位函数
inline float Mie_Phase(float mieAnisotropyScale, float cosTheta)
{
	float mieAnisotropyPow = mieAnisotropyScale * mieAnisotropyScale;
	float phase = (3.0 / (8.0 * PI))
		* ((1.0 - mieAnisotropyPow) / (2.0 + mieAnisotropyPow))
		* ((1.0 + cosTheta * cosTheta) / pow(1.0 + mieAnisotropyPow - 2.0 * mieAnisotropyScale * cosTheta, 1.5));
	return phase;
}

//散射，rayleigh和mie结合
inline float3 Scattering(float3 position, float3 planeCenter, float planeRadius,
	float mieAnisotropyScale, float mieScatteringScale, float mieScatteringHeight,
	float rayLeighScatteringScale, float rayLeighScatteringHeight,
	float3 viewDir, float3 lightDir)
{
	float cosTheta = dot(viewDir, lightDir);
	float h = length(position - planeCenter) - planeRadius;
	float3 rayLeigh = Rayleigh_Coefficient(rayLeighScatteringScale, rayLeighScatteringHeight, h) * Rayleight_Phase(cosTheta);
	float3 mie = Mie_Coefficient(mieScatteringScale, mieScatteringHeight, h) * Mie_Phase(mieAnisotropyScale, cosTheta);
	float3 scatter = rayLeigh + mie;
	return scatter;
}

//
//透射函数，看笔记，rayleigh不参与吸收, 只有mie和臭氧层会有吸收
//

//臭氧层透射衰减
inline float3 OzoneAbsorption(float ozoneAnisotropyScale, float ozoneHeight, float ozoneWidth, float h)
{
	float3 sigma = float3(0.650, 1.881, 0.085) * 1e-6;
	float thp = max(0, 1.0 - abs(h - ozoneHeight) / ozoneWidth);
	return sigma * thp * ozoneAnisotropyScale;
}

//mie透射衰减,(这里会有点问题，到时候看)
inline float3 MieAbsorption(float mieAnisotropyScale, float mieScatteringHeight, float h)
{
	float3 sigma = float3(4.4, 4.4, 4.4) * 1e-6;
	float thp = HeightAtmosphereThickness(mieScatteringHeight, h);
	return sigma * thp * mieAnisotropyScale;
}


//----------------------------------------------------------采样lut贴图-----------------------------------------------------------------------
//获取到采样lut的uv,并不直接对r和天顶角sita存值，需要经过变换
inline float2 GetSampleTransmittanceLutUv(float maxRadius, float minRadius, float radius, float cosSita)
{
	float h = sqrt(max(0, maxRadius * maxRadius - minRadius * minRadius));
	float rho = sqrt(max(0, radius * radius - minRadius * minRadius));

	float dMax = rho + h;
	float dMin = maxRadius - radius;
	float sinSitaPow = 1 - cosSita * cosSita;
	float d = max(0, sqrt(maxRadius * maxRadius - radius * radius * sinSitaPow) - radius * cosSita);

	float sita = (d - dMin) / (dMax - dMin);
	float r = rho / h;

	return float2(sita, r);
}

//大气层到p点的衰减，查找lut
inline float3 AtmosphereLutTransmittance(float planeRadius, float atmoSphereHeight, float3 position, float3 planeCenter, float3 lightDir, Texture2D lut, SamplerState sampler_Lut)
{
	float minRadius = planeRadius;
	float maxRadius = planeRadius + atmoSphereHeight;
	float3 r = position - planeCenter;
	float3 upVector = normalize(r);
	float radius = length(r);
	float cosSita = dot(upVector, lightDir);
	float2 uv = GetSampleTransmittanceLutUv(maxRadius, minRadius, radius, cosSita);
	float3 atmoSphereTranmit = lut.SampleLevel(sampler_Lut, uv, 0).rgb;
	return atmoSphereTranmit;
}

//多级散射,采样之前算到的多级散射Lut
inline float3 MulAtmosphereTransmittance(float planeRadius, float atmoSphereHeight, float3 position, float3 planeCenter, float3 lightDir,
	float rayLeighScatteringScale, float rayLeighScatteringHeight, float mieScatteringScale, float mieScatteringHeight,
	Texture2D lut, SamplerState sampler_Lut)
{
	float h = length(position) - planeRadius;
	float3 scattering = Rayleigh_Coefficient(rayLeighScatteringScale, rayLeighScatteringHeight, h) +
		Mie_Coefficient(mieScatteringScale, mieScatteringHeight, h);  // scattering

	float cosSunZenithAngle = dot(normalize(position), lightDir);
	float2 uv = float2(cosSunZenithAngle * 0.5 + 0.5, -h / atmoSphereHeight);
	float3 G_ALL = lut.SampleLevel(sampler_Lut, uv, 0).rgb;

	return G_ALL * scattering;
}

//---------------------------------------------------生成lut贴图,单级和多级------------------------------------------------------------

///生成lut贴图
//因为存储lut的uv是需要转换的，所以这里寻找到radius和cosSita需要转换回来
inline float2 GetUvToTransmittanceRadiusAndCosSita(float maxRadius, float minRadius, float2 uv)
{
	float sita = uv.x;
	float r = uv.y;

	float h = sqrt(max(0, maxRadius * maxRadius - minRadius * minRadius));
	float rho = r * h;
	float radius = sqrt(max(0, rho * rho + minRadius * minRadius));

	float dMax = rho + h;
	float dMin = maxRadius - radius;
	float d = sita * (dMax - dMin) + dMin;
	float cosSita = d == 0.0f ? 1.0f : (h * h - rho * rho - d * d) / (2.0f * radius * d);
	cosSita = clamp(cosSita, -1.0f, 1.0f);
	
	return float2(radius, cosSita);
}

//预计算单级散射Transmittance
inline float3 Transmittance(int rayMarchCount,
	float3 planeCenter, float planeRadius, float atmosphereHeight,
	float mieScatteringScale, float mieAnisotropyScale, float mieScatteringHeight,
	float rayLeighScatteringScale, float rayLeighScatteringHeight,
	float ozoneAnisotropyScale, float ozoneHeight, float ozoneWidth,
	float3 viewDir, float3 samplePostion)
{
	
	float rayTransmittanceDistance = rayIntersectSphereDistance(planeCenter, planeRadius + atmosphereHeight, samplePostion, viewDir);
	float rayStepDistance = rayTransmittanceDistance / 30;
	float3 transmittance = 0;
	float3 rayMarchPosition = samplePostion + 0.5 * rayStepDistance * viewDir;

	for (int i = 1; i < 30; i++)
	{
		float h = length(rayMarchPosition - planeCenter) - planeRadius;
		float3 transmit = Rayleigh_Coefficient(1, rayLeighScatteringHeight, h) + Mie_Coefficient(1, mieScatteringHeight, h)
			+ MieAbsorption(1, mieScatteringHeight, h) + OzoneAbsorption(1, ozoneHeight, ozoneWidth, h);
		
		transmittance += rayStepDistance * transmit;
		rayMarchPosition += rayStepDistance * viewDir;
	}

	float3 t = exp2(-transmittance);
	return t;
}

//预计算多级散射Transmittance
inline float3 MulTransmittance(
	float3 planeCenter, float planeRadius, float atmosphereHeight,
	float mieScatteringScale, float mieAnisotropyScale, float mieScatteringHeight,
	float rayLeighScatteringScale, float rayLeighScatteringHeight,
	float ozoneAnisotropyScale, float ozoneHeight, float ozoneWidth,
	float3 lightDir, float3 startPosition, Texture2D transmittanceLut, SamplerState sampler_transmittanceLut)
{
	//随机球体采样
	float3 RandomSphereSamples[64] = {
		float3(-0.7838,-0.620933,0.00996137),
		float3(0.106751,0.965982,0.235549),
		float3(-0.215177,-0.687115,-0.693954),
		float3(0.318002,0.0640084,-0.945927),
		float3(0.357396,0.555673,0.750664),
		float3(0.866397,-0.19756,0.458613),
		float3(0.130216,0.232736,-0.963783),
		float3(-0.00174431,0.376657,0.926351),
		float3(0.663478,0.704806,-0.251089),
		float3(0.0327851,0.110534,-0.993331),
		float3(0.0561973,0.0234288,0.998145),
		float3(0.0905264,-0.169771,0.981317),
		float3(0.26694,0.95222,-0.148393),
		float3(-0.812874,-0.559051,-0.163393),
		float3(-0.323378,-0.25855,-0.910263),
		float3(-0.1333,0.591356,-0.795317),
		float3(0.480876,0.408711,0.775702),
		float3(-0.332263,-0.533895,-0.777533),
		float3(-0.0392473,-0.704457,-0.708661),
		float3(0.427015,0.239811,0.871865),
		float3(-0.416624,-0.563856,0.713085),
		float3(0.12793,0.334479,-0.933679),
		float3(-0.0343373,-0.160593,-0.986423),
		float3(0.580614,0.0692947,0.811225),
		float3(-0.459187,0.43944,0.772036),
		float3(0.215474,-0.539436,-0.81399),
		float3(-0.378969,-0.31988,-0.868366),
		float3(-0.279978,-0.0109692,0.959944),
		float3(0.692547,0.690058,0.210234),
		float3(0.53227,-0.123044,-0.837585),
		float3(-0.772313,-0.283334,-0.568555),
		float3(-0.0311218,0.995988,-0.0838977),
		float3(-0.366931,-0.276531,-0.888196),
		float3(0.488778,0.367878,-0.791051),
		float3(-0.885561,-0.453445,0.100842),
		float3(0.71656,0.443635,0.538265),
		float3(0.645383,-0.152576,-0.748466),
		float3(-0.171259,0.91907,0.354939),
		float3(-0.0031122,0.9457,0.325026),
		float3(0.731503,0.623089,-0.276881),
		float3(-0.91466,0.186904,0.358419),
		float3(0.15595,0.828193,-0.538309),
		float3(0.175396,0.584732,0.792038),
		float3(-0.0838381,-0.943461,0.320707),
		float3(0.305876,0.727604,0.614029),
		float3(0.754642,-0.197903,-0.62558),
		float3(0.217255,-0.0177771,-0.975953),
		float3(0.140412,-0.844826,0.516287),
		float3(-0.549042,0.574859,-0.606705),
		float3(0.570057,0.17459,0.802841),
		float3(-0.0330304,0.775077,0.631003),
		float3(-0.938091,0.138937,0.317304),
		float3(0.483197,-0.726405,-0.48873),
		float3(0.485263,0.52926,0.695991),
		float3(0.224189,0.742282,-0.631472),
		float3(-0.322429,0.662214,-0.676396),
		float3(0.625577,-0.12711,0.769738),
		float3(-0.714032,-0.584461,-0.385439),
		float3(-0.0652053,-0.892579,-0.446151),
		float3(0.408421,-0.912487,0.0236566),
		float3(0.0900381,0.319983,0.943135),
		float3(-0.708553,0.483646,0.513847),
		float3(0.803855,-0.0902273,0.587942),
		float3(-0.0555802,-0.374602,-0.925519),
	};

	const float uniform_phase = 1.0 / (4.0 * PI);
	const float sphereSolidAngle = 4.0 * PI / float(64);
	//初一方向

	float3 G2 = 0;
	float3 fms = 0;

	for (int i = 0; i < 64; i++)
	{
		// 光线和大气层求交
		// 视角方向是随机的
		// 按照设定的视角方向数量去定义
		float3 viewDir = RandomSphereSamples[i];
		float rayMarchDistance = rayIntersectSphereDistance(0, planeRadius + atmosphereHeight, startPosition, viewDir);
		float d = rayIntersectSphereDistance(0, planeRadius, startPosition, viewDir);
		if (d > 0)
		{
			rayMarchDistance = min(rayMarchDistance, d);
		}
		float ds = rayMarchDistance / float(32);

		float3 rayMarchPosition = startPosition + rayMarchDistance * ds;
		float3 accumulateAttenution = 0;

		for (int j = 0; j < 32; j++)
		{
			float h = length(rayMarchPosition) - planeRadius;
			float3 scattering = Rayleigh_Coefficient(rayLeighScatteringScale, rayLeighScatteringHeight, h) +
				Mie_Coefficient(mieScatteringScale, mieScatteringHeight, h);  // scattering
			float3 absorption = MieAbsorption(mieAnisotropyScale, mieScatteringHeight, h) +
				OzoneAbsorption(ozoneAnisotropyScale, ozoneHeight, ozoneWidth, h);     // absorption
			float3 transmit = scattering + absorption;
			accumulateAttenution += transmit * rayMarchDistance;

			float3 t1 = AtmosphereLutTransmittance(planeRadius, atmosphereHeight, rayMarchPosition, planeCenter, lightDir, transmittanceLut, sampler_transmittanceLut);
			float3 s = Scattering(rayMarchPosition, planeCenter, planeRadius, mieAnisotropyScale, mieScatteringScale, mieScatteringHeight,
				rayLeighScatteringScale, rayLeighScatteringHeight, viewDir, lightDir);
			float3 t2 = exp2(-accumulateAttenution);

			rayMarchPosition += rayMarchDistance * viewDir;

			// 用 1.0 代替太阳光颜色, 该变量在后续的计算中乘上去
			G2 += t1 * s * t2 * uniform_phase * ds;
			fms += t2 * scattering * uniform_phase * ds;//自然散射

			//步进距离增加
			rayMarchPosition += viewDir * ds;
		}
	}

	G2 *= sphereSolidAngle;
	fms *= sphereSolidAngle;
	return G2 * (1.0 / (1.0 - fms));
}

//渲染TransmittanceLut
//uv为屏幕空间uv
inline float3 RenderTransmittanceLut(float2 uv, float rayMarchCount,
	float planeRadius, float3 planeCenter, float atmosphereHeight, 
	float mieScatteringScale, float mieAnisotropyScale, float mieScatteringHeight,
	float rayLeighScatteringScale, float rayLeighScatteringHeight,
	float ozoneAnisotropyScale, float ozoneHeight, float ozoneWidth
	)
{
	float maxRadius = planeRadius + atmosphereHeight;
	float minRadius = planeRadius;
	float2 param = GetUvToTransmittanceRadiusAndCosSita(maxRadius, minRadius, uv);
	float r = param.x;
	float cosSita = param.y;

	float3 viewDir = float3(sqrt(1 - cosSita * cosSita), cosSita, 0);
	float3 samplePostion = float3(0, r, 0);

	float3 color = Transmittance(rayMarchCount,
	 planeCenter, planeRadius, atmosphereHeight,
	 mieScatteringScale, mieAnisotropyScale, mieScatteringHeight,
	 rayLeighScatteringScale, rayLeighScatteringHeight,
	 ozoneAnisotropyScale, ozoneHeight, ozoneWidth,
	 viewDir, samplePostion);

	return color;
}

//渲染多级散射TransmittanceLut
inline float3 RenderMulTransmittanceLut(float2 uv, float rayMarchCount,
	float planeRadius, float3 planeCenter, float atmosphereHeight,
	float mieScatteringScale, float mieAnisotropyScale, float mieScatteringHeight,
	float rayLeighScatteringScale, float rayLeighScatteringHeight,
	float ozoneAnisotropyScale, float ozoneHeight, float ozoneWidth, Texture2D transmittanceLut, SamplerState sampler_transmittanceLut
)
{
	float r = uv.y * atmosphereHeight + planeRadius;
	float cosSita = uv.x * 2.0 - 1.0;
	float3 lightDir = float3(sqrt(1.0 - cosSita * cosSita), cosSita, 0);
	float3 samplePostion = float3(0, r, 0);

	float3 color = float3(0.0, 0.0, 0.0);
	color = MulTransmittance(planeCenter, planeRadius, atmosphereHeight,
	mieScatteringScale, mieAnisotropyScale, mieScatteringHeight,
	rayLeighScatteringScale, rayLeighScatteringHeight,
	ozoneAnisotropyScale, ozoneHeight, ozoneWidth,
	lightDir, samplePostion, transmittanceLut, sampler_transmittanceLut);

	return color;
}


//----------------------------------------------------------光线步进-----------------------------------------------------------------------
//p点到摄像机的散射 + 衰减（单级散射）
inline float3 AtmosphereTransmittance(int rayMarchCount,
	float3 lightColor, float lightInstensity,
	float3 planeCenter, float planeRadius, float atmosphereHeight, float maxDistance,
	float mieScatteringScale, float mieAnisotropyScale, float mieScatteringHeight,
	float rayLeighScatteringScale, float rayLeighScatteringHeight,
	float ozoneAnisotropyScale, float ozoneHeight, float ozoneWidth, float _ifMulAtmosphereRender,
	float3 startPosition, float3 viewDir, float3 lightDir, float mulAtmosphereRenderStrength,
	Texture2D transmittanceLut, SamplerState sampler_transmittanceLut, Texture2D mulTransmittanceLut, SamplerState sampler_mulTransmittanceLut)
{
	float3 rayMarchPosition = 0;
	float3 atmoSphereColor = 0;
	float3 sunColor = lightColor * lightInstensity;

	//与大气层碰撞
	float rayIntersectAtmoDistance = rayIntersectSphereDistance(planeCenter, planeRadius + atmosphereHeight, startPosition, viewDir);
	//与地球表面碰撞
	float rayIntersectPlanetDistance = rayIntersectSphereDistance(planeCenter, planeRadius, startPosition, viewDir);
	//if(rayIntersectAtmoDistance < 0)
	//{
	//	return atmoSphereColor; 
	//}
	//if(rayIntersectPlanetDistance > 0)
	//{
	//	rayIntersectAtmoDistance = min(rayIntersectAtmoDistance, rayIntersectPlanetDistance);
	//}
	

	maxDistance = maxDistance < 0 ? rayIntersectAtmoDistance : maxDistance;

	//float rayMarchDistance = rayIntersectAtmoDistance / rayMarchCount;
	float rayMarchDistance = 1000;
	float rayMarchCurrentDistance = rayMarchDistance;
	rayMarchPosition = startPosition + rayMarchDistance * viewDir;
	//累积衰减
	float3 accumulateAttenution = 0;
	
	for (int i = 1; i < rayMarchCount; i++)
	{
		//raylrigh参与散射，不参与吸收
		//mie参与散射也参与吸收
		//大气不参与散射，参与吸收
		float h = length(rayMarchPosition - planeCenter) - planeRadius;
		float3 transmit = Rayleigh_Coefficient(rayLeighScatteringScale, rayLeighScatteringHeight, h) +
			Mie_Coefficient(mieScatteringScale, mieScatteringHeight, h) + MieAbsorption(mieAnisotropyScale, mieScatteringHeight, h) +
			OzoneAbsorption(ozoneAnisotropyScale, ozoneHeight, ozoneWidth, h);
		accumulateAttenution += transmit * rayMarchDistance;

		//lut采样t1衰减
		float3 t1 = AtmosphereLutTransmittance(planeRadius, atmosphereHeight, rayMarchPosition, planeCenter, lightDir, transmittanceLut, sampler_transmittanceLut);
		float3 s = Scattering(rayMarchPosition, planeCenter, planeRadius, mieAnisotropyScale, mieScatteringScale, mieScatteringHeight,
			 rayLeighScatteringScale, rayLeighScatteringHeight, viewDir, lightDir);
		float3 t2 = exp2(-accumulateAttenution);
		
		atmoSphereColor += sunColor * t1 * s * t2 * rayMarchDistance;
		rayMarchPosition += rayMarchDistance * viewDir;

		if (_ifMulAtmosphereRender > 0)
		{
			atmoSphereColor += MulAtmosphereTransmittance(planeRadius, atmosphereHeight, rayMarchPosition, planeCenter, lightDir,
				rayLeighScatteringScale, rayLeighScatteringHeight, mieScatteringScale, mieScatteringHeight,
				 mulTransmittanceLut, sampler_mulTransmittanceLut) * mulAtmosphereRenderStrength * t2 * rayMarchDistance * sunColor;
		}

		if (rayMarchCurrentDistance > maxDistance) break;
		rayMarchCurrentDistance += rayMarchDistance;
	}
	
	return atmoSphereColor;
}