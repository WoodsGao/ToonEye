#define PI 3.1415926535898

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max(float3(1 ,1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

float3x3 GetRotationFromEuler(float3 euler)
{
    float sinx = sin(euler.x);
    float cosx = cos(euler.x);
    float3x3 x = float3x3(
    1,0,0,
    0,cosx,-sinx,
    0,sinx,cosx
    );

    float siny = sin(euler.y);
    float cosy = cos(euler.y);
    float3x3 y = float3x3(
    cosy,0,siny,
    0,1,0,
    -siny,0,cosy
    );

    float sinz = sin(euler.z);
    float cosz = cos(euler.z);
    float3x3 z = float3x3(
    cosz,-sinz,0,
    sinz,cosz,0,
    0,0,1
    );


    return mul(z, mul(x, y));
}
