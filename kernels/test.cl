#define EPS		1e-5f
#define ARRAY_SIZE(a)	(sizeof(a) / sizeof(a[0]))

constant ushort primes[] = {
	2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
	31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
	73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
	127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
	179, 181, 191, 193, 197, 199, 211, 223, 227, 229,
	233, 239, 241, 251, 257, 263, 269, 271, 277, 281,
	283, 293, 307, 311, 313, 317, 331, 337, 347, 349,
	353, 359, 367, 373, 379, 383, 389, 397, 401, 409,
	419, 421, 431, 433, 439, 443, 449, 457, 461, 463,
	467, 479, 487, 491, 499, 503, 509, 521, 523, 541
};

float rad_inv(unsigned n, unsigned base, unsigned omega)
{
	float res = 0;
	float inv_base = 1.0f / base;
	float inv_bi = inv_base;
	while (n > 0) {
		res += ((n * omega) % base) * inv_bi;
		n /= base;
		inv_bi *= inv_base;
	}
	return res;
}

struct sampler {
	unsigned dim;
	unsigned omega;
};

void sam_init(struct sampler *sam, unsigned seed)
{
	sam->dim = 0;
	sam->omega = seed % ARRAY_SIZE(primes);
}

float sam_get(struct sampler *sam, unsigned sample)
{
	unsigned omega = sam->omega;
	if (omega == sam->dim)
		omega++;
	float res = rad_inv(sample, primes[sam->dim], primes[omega]);
	sam->dim++;
	return res;
}

struct ray {
	float4 org;
	float4 dir;
};

float4 ray_at(struct ray ray, float t)
{
	return ray.org + ray.dir * t;
}

float4 xform_vec(float16 xform, float4 vec)
{
	float4 res;
	res  = xform.s0123 * vec.x;
	res += xform.s4567 * vec.y;
	res += xform.s89ab * vec.z;
	res += xform.scdef * vec.w;
	return res;
}

struct ray cam_get_ray(float16 xform, float2 xy)
{
	const float2 film_size = (float2)(2.0f, 2.0f);
	const float focal_len = 1.0f;

	struct ray res;
	xy -= (float2)(0.5f);
	xy *= (float2)(1.0f, -1.0f);
	xy *= film_size;

	res.org = (float4)(xform.scde, 1.0f);
	res.dir = normalize((float4)(xy, -focal_len, 0.0f));
	res.dir = xform_vec(xform, res.dir);

	return res;
}

float ruby(float radius, float density, float4 p)
{
	p = fabs(p);
	return density * step(p.x + p.y + p.z, radius);
}

float sphere(float4 center, float radius, float density, float4 p)
{
	return density * step(distance(center, p), radius);
}

float4 background(read_only image2d_t env, struct ray ray, float2 pos)
{
	float phi = acos(ray.dir.y);
	float theta = atan2(ray.dir.x, ray.dir.z);
	if (theta < 0)
		theta += (float)2 * M_PI;
	float u = theta / (float)(2.0f * M_PI);
	float v = phi / (float)M_PI;
	u += 0.5f;
//	if (u > 1.0f)
//		u -= 1.0f;

//#if 1
//	if (u > 0.5)
//		u -= 0.5f;
//	else
//		u += 0.5f;
//#else
//	u = 1.0f - u;
//#endif
	float2 p = (float2)(u, v);

	const sampler_t env_sampler = CLK_FILTER_LINEAR
				    | CLK_ADDRESS_REPEAT
				    | CLK_NORMALIZED_COORDS_TRUE;
	return read_imagef(env, env_sampler, p);
	return mix((float4)(0.0f), (float4)(0.0f, 0.1f, 0.1f, 1.0f), pos.y);
	return (float4)(1.0f, 0.5f, 0.0f, 1.0f);
}

//#define SCENE(p)	sphere((float4)(0,0,0,1), 2.0f, 0.25f, p)
#define SCENE(p)	ruby(2.0f, 0.25f, p)

kernel void foo(
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
	float step = 0.25f;
	int nr_steps = ceil(farz / step);

	float4 sphere_color = (float4)(1.0f, 0.5f, 0.0f, 1.0f);
	struct ray ray = cam_get_ray(cam_xform, pos);
	float d = 0.0f;
	for (int i = 0; i < nr_steps; i++) {
		float4 p = ray_at(ray, (i + jit) * step);
		d += SCENE(p) * step;
	}

	float4 res = mix(background(env, ray, pos), sphere_color, min(d, 1.0f));
	res /= (float)sample;
	if (sample > 1) {
		const sampler_t back_sampler = CLK_FILTER_NEAREST
					     | CLK_ADDRESS_CLAMP
					     | CLK_NORMALIZED_COORDS_FALSE;
		float4 back = read_imagef(back_buf, back_sampler, id);
		res += back * ((sample - 1) / (float)sample);
	}
	write_imagef(front_buf, id, res);
}
