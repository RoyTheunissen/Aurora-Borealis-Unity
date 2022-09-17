#ifndef UTILITIES_INC
#define UTILITIES_INC

#define PI 3.141592653589793238462
#define DEG2RAD 0.01745329
#define RAD2DEG 57.29578

float3 GetObjectPosition()
{
    return mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
}

float GetObjectSeed()
{
    float3 objectPosition = GetObjectPosition();
    return
        objectPosition.x * 348723.694857389
        + objectPosition.y * 747374.57248724
        + objectPosition.z * 5657385.946583
        ;
}

float3 rgb2hsv(float3 c) {
  float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c) {
  c = float3(c.x, clamp(c.yz, 0.0, 1.0));
  float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float WrapAround(float value, float wrap)
{
    return wrap + value * (1 - wrap);
}

float push(float v, float factor, float from = 0.5)
{
    return max(0, from + (v - from) * factor);
}

float map(float value, float min1, float max1, float min2, float max2)
{
    float fraction = (value - min1) / (max1 - min1);
    return saturate(fraction) * (max2 - min2) + min2;
}

#endif // UTILITIES_INC
