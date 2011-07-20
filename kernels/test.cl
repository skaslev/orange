#include "noise.cl"
#include "sampler.cl"
#include "math.cl"

//#define SCENE(p)	sphere((float4)(0,0,0,1), 2.0f, 0.25f, p)
//#define SCENE(p)	ruby(2.0f, 0.25f, p)
#define SCENE(p)	pyroclastic((float4)(0,0,0,1), 2.0f, 1.0f, p)

float ruby(float radius, float density, float4 p)
{
	p = fabs(p);
	return density * step(p.x + p.y + p.z, radius);
}

float sphere(float4 center, float radius, float density, float4 p)
{
	return density * step(distance(center, p), radius);
}

float pyroclastic(float4 center, float radius, float density, float4 p)
{
	float d = distance(center, p);
	float n = 0.06f * turbulence3d(p, 5.0f, 1.0f, 1.0f, 8.0f);
	return density * step(d + n, radius);
}

struct ray cam_get_ray(float16 xform, float2 xy)
{
	const float2 film_size = (float2)(2.0f, 2.0f);
	const float focal_len = 1.0f;

	xy -= (float2)(0.5f);
	xy *= (float2)(1.0f, -1.0f);
	xy *= film_size;

	struct ray res;
	res.org = xform.scdef;
	res.dir = normalize((float4)(xy, -focal_len, 0.0f));
	res.dir = xform_vec(xform, res.dir);
	return res;
}

float4 background(read_only image2d_t env, struct ray ray)
{
	float2 p = to_spherical(ray.dir);
	p = (float2)(-p.y / (2.0f * PI), p.x / PI);

	const sampler_t env_sampler = CLK_FILTER_LINEAR
				    | CLK_ADDRESS_REPEAT
				    | CLK_NORMALIZED_COORDS_TRUE;
	return srgb_to_linear(read_imagef(env, env_sampler, p));
}

kernel void test(
	global const float *camera_xform,
	int sample,
	read_only image2d_t env,
	read_only image2d_t back_buf,
	write_only image2d_t front_buf)
{
	float16 cam_xform = vload16(0, camera_xform);
	struct sampler sam;
	sam_init(&sam, get_global_id(0) * get_global_size(1) + get_global_id(1));

	int2 id = (int2)(get_global_id(0), get_global_id(1));
	float2 pos = (float2)(get_global_id(0), get_global_id(1));
	pos += (float2)(sam_get(&sam, sample), sam_get(&sam, sample));
	pos /= (float2)(get_global_size(0), get_global_size(1));

	float jit = sam_get(&sam, sample);
	float farz = 10.0f;
	float step = 2.0f;
	int nr_steps = ceil(farz / step);

	float4 object_color = (float4)(1.0f, 1.0f, 1.0f, 1.0f);
	struct ray ray = cam_get_ray(cam_xform, pos);
	float d = 0.0f;
	for (int i = 0; i < nr_steps; i++) {
		float4 p = ray_at(ray, (i + jit) * step);
		d += SCENE(p) * step;
	}

	float4 res = mix(background(env, ray), object_color, min(d, 1.0f));
	res /= (float)sample;
	if (sample > 1) {
		const sampler_t back_sampler = CLK_FILTER_NEAREST
					     | CLK_ADDRESS_CLAMP
					     | CLK_NORMALIZED_COORDS_FALSE;
		float4 back = srgb_to_linear(read_imagef(back_buf, back_sampler, id));
		res += back * ((sample - 1) / (float)sample);
	}
	write_imagef(front_buf, id, linear_to_srgb(res));
}
