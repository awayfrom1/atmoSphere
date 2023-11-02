#define PI 3.1415926

/**
 * \brief 射线与任意球体求交点
 * \param sphereCenter 
 * \param sphereRadius 
 * \param rayOrigin 
 * \param rayDir 
 * \return 
 */
float rayIntersectSphereDistance(float3 sphereCenter, float sphereRadius, float3 rayOrigin, float3 rayDir)
{
    float OS = length(sphereCenter - rayOrigin);
    float SH = dot(sphereCenter - rayOrigin, rayDir);
    float OH = sqrt(OS * OS - SH * SH);
    float PH = sqrt(sphereRadius * sphereRadius - OH * OH);
    
    if (OH > sphereRadius) return -1;
    
    float t1 = SH - PH;
    float t2 = SH + PH;

    return (t1 < 0) ? t2 : t1;
}

/**
 * \brief 视角坐标转换到uv
 * \param viewDir 
 * \return 
 */
float2 ViewDirToUv(float3 viewDir)
{
    float2 uv = float2(atan2(viewDir.z, viewDir.x), asin(viewDir.y));
    uv /= float2(2.0 * PI, PI);
    uv += float2(0.5, 0.5);
    return uv;
}

/**
 * \brief uv转换到视角坐标
 * \param uv 
 * \return 
 */
float3 UvToViewDir(float2 uv)
{
    float theta = (1.0 - uv.y) * PI;
    float phi = (uv.x * 2 - 1) * PI;
    
    float x = sin(theta) * cos(phi);
    float z = sin(theta) * sin(phi);
    float y = cos(theta);

    return float3(x, y, z);
}