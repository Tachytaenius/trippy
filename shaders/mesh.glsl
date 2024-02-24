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

varying vec3 fragmentNormal;
varying vec3 fragmentPosition;

#ifdef VERTEX

uniform mat4 modelToWorld;
uniform mat3 modelToWorldNormal;
uniform mat4 modelToScreen;

attribute vec3 VertexNormal;

vec4 position(mat4 loveTransform, vec4 homogenVertexPosition) {
	fragmentNormal = modelToWorldNormal * VertexNormal;
	vec4 ret = modelToScreen * homogenVertexPosition;
	ret.y *= -1.0;
	fragmentPosition = (modelToWorld * homogenVertexPosition).xyz; // Probably needs -y as well
	return ret;
}

#endif

float pingPong(float x, float height) {
	return height - abs(height - mod(x, 2.0 * height));
}

float jaggedify(float x) {
	return 2.0 * x + 1.5 * pingPong(x, 1.0) - 4.0;
}

float calculateFogFactor2(float dist, float fogFadeLength) { // More fog the closer you are
	if (fogFadeLength == 0.0) { // Avoid dividing by zero
		return 1.0; // Immediate fog
	}
	return clamp(1 - dist / fogFadeLength, 0.0, 1.0);
}

#ifdef PIXEL

uniform float time;
uniform bool drawTrippy;
uniform sampler2D baseTexture;
uniform vec3 baseTextureColour;
uniform sampler2D gridIndicatorTexture;
uniform float gridIndicatorTextureCellCount;
uniform float gridCellEdgeBlendFactor;
uniform vec3 gridBaseColour;

vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	vec3 surfaceColour;
	if (drawTrippy) {
		vec3 textureColour = Texel(baseTexture, textureCoords).rgb;
		vec3 textureColour2 = Texel(baseTexture, textureCoords / 10.0 + time * 0.125).rgb * 0.25;
		vec3 positionJagged = vec3(
			jaggedify(fragmentPosition.x * 1.0) / 1.0,
			jaggedify(fragmentPosition.y * 1.0) / 1.0,
			jaggedify(fragmentPosition.z * 1.0) / 1.0
		);
		vec3 simplexColour = vec3(
			simplex3d(positionJagged / 30.0 + time * 0.5),
			pow(simplex3d(fragmentPosition / 25.0 + 10030.0 - time * 1/3), 4.0),
			pow(simplex3d(fragmentPosition / 12.5 - 1000.0 + time * 0.25), 2.0)
		);
		vec3 gridColour =
			gridBaseColour
		;
		float gridEdgeBlend = (1.0 - max(
			max(
				calculateFogFactor2(
					mod(textureCoords.s * gridIndicatorTextureCellCount, 1.0),
					gridCellEdgeBlendFactor
				),
				calculateFogFactor2(
					1.0 - mod(textureCoords.s * gridIndicatorTextureCellCount, 1.0),
					gridCellEdgeBlendFactor
				)
			),
			max(
				calculateFogFactor2(
					mod(textureCoords.t * gridIndicatorTextureCellCount, 1.0),
					gridCellEdgeBlendFactor
				),
				calculateFogFactor2(
					1.0 - mod(textureCoords.t * gridIndicatorTextureCellCount, 1.0),
					gridCellEdgeBlendFactor
				)
			)
		));
		surfaceColour =
			textureColour * baseTextureColour * (simplexColour * 0.6 + 0.4)
			+ gridColour * (Texel(gridIndicatorTexture, textureCoords).rrr * 0.5 + 0.5)
			* clamp(
				gridEdgeBlend *
					Texel(gridIndicatorTexture, textureCoords).bbb
					* ((sin(time * 0.1) * 0.5 + 0.5) * 0.1 + 0.6),
				0.0,
				1.0
			)
		;
	} else {
		surfaceColour = fragmentNormal / 2.0 + 0.5;
	}
	return colour * vec4(surfaceColour, 1.0);
}

#endif
