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
	unsigned sample;
};

void sam_init(struct sampler *sam, unsigned sample, unsigned seed)
{
	sam->dim = 0;
	sam->sample = sample;
	sam->omega = seed % ARRAY_SIZE(primes);
}

float sam_get(struct sampler *sam)
{
	unsigned omega = sam->omega;
	if (omega == sam->dim)
		omega++;
	float res = rad_inv(sam->sample, primes[sam->dim], primes[omega]);
	sam->dim++;
	return res;
}
