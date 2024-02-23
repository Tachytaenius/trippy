// The following code is not mine, mine is below

/* https://www.shadertoy.com/view/XsX3zB
 *
 * The MIT License
 * Copyright © 2013 Nikita Miropolskiy
 * 
 * ( license has been changed from CCA-NC-SA 3.0 to MIT
 *
 *   but thanks for attributing your source code when deriving from this sample 
 *   with a following link: https://www.shadertoy.com/view/XsX3zB )
 *
 * ~
 * ~ if you're looking for procedural noise implementation examples you might 
 * ~ also want to look at the following shaders:
 * ~ 
 * ~ Noise Lab shader by candycat: https://www.shadertoy.com/view/4sc3z2
 * ~
 * ~ Noise shaders by iq:
 * ~     Value    Noise 2D, Derivatives: https://www.shadertoy.com/view/4dXBRH
 * ~     Gradient Noise 2D, Derivatives: https://www.shadertoy.com/view/XdXBRH
 * ~     Value    Noise 3D, Derivatives: https://www.shadertoy.com/view/XsXfRH
 * ~     Gradient Noise 3D, Derivatives: https://www.shadertoy.com/view/4dffRH
 * ~     Value    Noise 2D             : https://www.shadertoy.com/view/lsf3WH
 * ~     Value    Noise 3D             : https://www.shadertoy.com/view/4sfGzS
 * ~     Gradient Noise 2D             : https://www.shadertoy.com/view/XdXGW8
 * ~     Gradient Noise 3D             : https://www.shadertoy.com/view/Xsl3Dl
 * ~     Simplex  Noise 2D             : https://www.shadertoy.com/view/Msf3WH
 * ~     Voronoise: https://www.shadertoy.com/view/Xd23Dh
 * ~ 
 *
 */

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
	float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j);
	j *= .125;
	r.x = fract(512.0*j);
	j *= .125;
	r.y = fract(512.0*j);
	return r-0.5;
}

/* skew constants for 3d simplex functions */
const float F3 =  0.3333333;
const float G3 =  0.1666667;

/* 3d simplex noise */
float simplex3d(vec3 p) {
	 /* 1. find current tetrahedron T and it's four vertices */
	 /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
	 /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
	 
	 /* calculate s and x */
	 vec3 s = floor(p + dot(p, vec3(F3)));
	 vec3 x = p - s + dot(s, vec3(G3));
	 
	 /* calculate i1 and i2 */
	 vec3 e = step(vec3(0.0), x - x.yzx);
	 vec3 i1 = e*(1.0 - e.zxy);
	 vec3 i2 = 1.0 - e.zxy*(1.0 - e);
	 	
	 /* x1, x2, x3 */
	 vec3 x1 = x - i1 + G3;
	 vec3 x2 = x - i2 + 2.0*G3;
	 vec3 x3 = x - 1.0 + 3.0*G3;
	 
	 /* 2. find four surflets and store them in d */
	 vec4 w, d;
	 
	 /* calculate surflet weights */
	 w.x = dot(x, x);
	 w.y = dot(x1, x1);
	 w.z = dot(x2, x2);
	 w.w = dot(x3, x3);
	 
	 /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
	 w = max(0.6 - w, 0.0);
	 
	 /* calculate surflet components */
	 d.x = dot(random3(s), x);
	 d.y = dot(random3(s + i1), x1);
	 d.z = dot(random3(s + i2), x2);
	 d.w = dot(random3(s + 1.0), x3);
	 
	 /* multiply d by w^4 */
	 w *= w;
	 w *= w;
	 d *= w;
	 
	 /* 3. return the sum of the four surflets */
	 return dot(d, vec4(52.0));
}

/* const matrices for 3d rotation */
const mat3 rot1 = mat3(-0.37, 0.36, 0.85,-0.14,-0.93, 0.34,0.92, 0.01,0.4);
const mat3 rot2 = mat3(-0.55,-0.39, 0.74, 0.33,-0.91,-0.24,0.77, 0.12,0.63);
const mat3 rot3 = mat3(-0.71, 0.52,-0.47,-0.08,-0.72,-0.68,-0.7,-0.45,0.56);

/* directional artifacts can be reduced by rotating each octave */
float simplex3d_fractal(vec3 m) {
    return   0.5333333*simplex3d(m*rot1)
			+0.2666667*simplex3d(2.0*m*rot2)
			+0.1333333*simplex3d(4.0*m*rot3)
			+0.0666667*simplex3d(8.0*m);
}

// My code:

uniform float time;
uniform vec4 viewQuaternion;
uniform mat4 screenToSky;
uniform float nearPlaneDistance;
uniform vec3 baseTextureColour;

float calculateFogFactor(float dist, float maxDist, float fogFadeLength) { // More fog the further you are
	if (fogFadeLength == 0.0) { // Avoid dividing by zero
		return dist < maxDist ? 0.0 : 1.0;
	}
	return clamp((dist - maxDist + fogFadeLength) / fogFadeLength, 0.0, 1.0);
}

float calculateFogFactor2(float dist, float fogFadeLength) { // More fog the closer you are
	if (fogFadeLength == 0.0) { // Avoid dividing by zero
		return 1.0; // Immediate fog
	}
	return clamp(1 - dist / fogFadeLength, 0.0, 1.0);
}

float pingPong(float x, float height) {
	return height - abs(height - mod(x, 2.0 * height));
}

float jaggedify(float x, float mul1, float mul2, float height, float add) {
	return mul1 * x + mul2 * pingPong(x, height) + add;
}

float bumpify(float x, float a, float b, float c, float d) {
	return a * x + b * sin(c * d) + d;
}

vec3 hsv2rgb(vec3 hsv) {
	float h = hsv[0];
	float s = hsv[1];
	float v = hsv[2];
	if (s == 0.0) {
		return vec3(v);
	}
	float _h = h / 60.0;
	int i = int(_h);
	float f = _h - i;
	float p = v * (1 - s);
	float q = v * (1 - f * s);
	float t = v * (1 - (1 - f) * s);
	if (i == 0) {
		return vec3(v, t, p);
	} else if (i == 1) {
		return vec3(q, v, p);
	} else if (i == 2) {
		return vec3(p, v, t);
	} else if (i == 3) {
		return vec3(p, q, v);
	} else if (i == 4) {
		return vec3(t, p, v);
	} else if (i == 5) {
		return vec3(v, p, q);
	}
}

vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	// vec3 v = normalize(vec3(textureCoords - 0.5, 1));
	// vec3 uv = cross(viewQuaternion.xyz, v);
	// vec3 uuv = cross(viewQuaternion.xyz, uv);
	// vec3 coord = v + ((uv * viewQuaternion.w) + uuv) * 2.0;
	// coord.xy *= 4.0;
	// vec3 direction = normalize(coord);

	// This solution to get the  was figured out by me
	vec3 direction = normalize(
		(
			screenToSky * vec4( // screenToSky is inverse(perspectiveProjectionMatrix * cameraMatrixAtOriginWithCameraOrientation)
				textureCoords * 2.0 - 1.0,
				nearPlaneDistance,
				1.0
			)
		).xyz
	);
	vec3 directionOriginal = direction;
	direction.z /= 4.0;
	direction = normalize(direction);
	vec3 directionJagged = vec3(
		jaggedify(direction.x * 10.0, 2.0, 1.5, 1.0, -4.0) / 10.0,
		jaggedify(direction.y * 10.0, 1.9, 1.6, 1.1, -2.0) / 10.0,
		jaggedify(direction.z * 10.0, 1.8, 1.7, 1.2, sin(time / 2.5) * 0.25) / 10.0
	);
	vec3 directionBumpified = vec3(
		bumpify(direction.x, 0.1, 0.2, 0.3, 0.4),
		bumpify(direction.y, -1.0, 1.0, 2.0, 3.0),
		bumpify(direction.z, 4.0, 3.0, 2.0, 1.0)
	);
	vec3 directionMixed = direction + dot(directionJagged, directionBumpified) - sin(time * 0.2) * 0.2 * cross(directionJagged, directionBumpified);
	float whiteness = max(
		calculateFogFactor2(distance(direction, vec3(0, 0, -1)), 0.75),
		calculateFogFactor2(distance(direction, vec3(0, 0, 1)), 1.0)
	);
	vec3 baseSkyColour =
		vec3(
			pow(simplex3d(directionMixed * 1.0 - time * 0.025), 2.0),
			pow(simplex3d(directionMixed * 2.0 - time * 0.05), 2.0),
			pow(simplex3d(directionMixed * 0.5 + time * 0.1), 2.0)
		)
		+
		1.25 * vec3(
			pow(simplex3d(direction * 1.0 - time * 0.025), 2.0),
			pow(simplex3d(direction * 2.0 - time * 0.05), 2.0),
			pow(simplex3d(direction * 3.0 + time * 0.1), 2.0)
		)
		+
		(sin(time * 0.5) * 0.5 + 0.5 + 0.25) * hsv2rgb(vec3(
			mod(simplex3d(directionJagged * 1.0), 1.0) * 360.0,
			1.0,
			pow(simplex3d(directionBumpified * 5.0 + 10.0), 1.0)
		))
	;
	vec3 skyColour = mix(baseSkyColour, vec3(1.0), whiteness);
	return vec4(skyColour, 1.0);
}
