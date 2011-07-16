#define EPS		1e-5f
#define PI		((float)3.14159265358979323846)

struct ray {
	float4 org;
	float4 dir;
};

float4 ray_at(struct ray ray, float t)
{
	return ray.org + ray.dir * t;
}

float4 xform_vec(float16 xform, float4 v)
{
	float4 res;
	res  = xform.s0123 * v.x;
	res += xform.s4567 * v.y;
	res += xform.s89ab * v.z;
	res += xform.scdef * v.w;
	return res;
}

float2 to_spherical(float4 v)
{
	return (float2)(acos(v.y), atan2(v.x, v.z));
}

float4 srgb_to_linear(float4 c)
{
	float4 res;
	res.x = c.x <= 0.0031308f ? 12.92f * c.x : 1.055f * pow(c.x, 1.0f / 2.4f) - 0.055f;
	res.y = c.y <= 0.0031308f ? 12.92f * c.y : 1.055f * pow(c.y, 1.0f / 2.4f) - 0.055f;
	res.z = c.z <= 0.0031308f ? 12.92f * c.z : 1.055f * pow(c.z, 1.0f / 2.4f) - 0.055f;
	res.w = c.w;
	return res;
}

float4 linear_to_srgb(float4 c)
{
	float4 res;
	res.x = c.x <= 0.04045f ? c.x / 12.92f : pow((c.x + 0.055f) / 1.055f, 2.4f);
	res.y = c.y <= 0.04045f ? c.y / 12.92f : pow((c.y + 0.055f) / 1.055f, 2.4f);
	res.z = c.z <= 0.04045f ? c.z / 12.92f : pow((c.z + 0.055f) / 1.055f, 2.4f);
	res.w = c.w;
	return res;
}
