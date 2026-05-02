/*
 * Copyright 2017 Cheng Cao
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// =============================================================================
//  PLEASE FOLLOW THE LICENSE AND PLEASE DO NOT REMOVE THE LICENSE HEADER
// =============================================================================
//  ANY USE OF THE SHADER ONLINE OR OFFLINE IS CONSIDERED AS INCLUDING THE CODE
//  IF YOU DOWNLOAD THE SHADER, IT MEANS YOU AGREE AND OBSERVE THIS LICENSE
// =============================================================================

#version 120

#include "compat.glsl"

#pragma optimize(on)

#define NORMALS

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;
uniform float frameTimeCounter;

varying f16vec4 color;
varying vec4 coords;
varying vec4 wdata;

varying float dis;

#define normal wdata.xyz
#define flag wdata.w

#define texcoord coords.rg
#define lmcoord coords.ba

#ifdef NORMALS
varying f16vec3 tangent;
varying f16vec3 binormal;
#else
f16vec3 tangent;
f16vec3 binormal;

f16vec2 normalEncode(f16vec3 n) {return sqrt(-n.z*0.125f+0.125f) * normalize(n.xy) + 0.5f;}
varying vec2 n2;
#endif

#define ParallaxOcclusion
#ifdef ParallaxOcclusion
varying f16vec3 tangentpos;
#endif

#define PARALLAX_SELF_SHADOW
#ifdef PARALLAX_SELF_SHADOW
varying vec3 sun;

uniform vec3 shadowLightPosition;
#endif

#define WAVING_FOILAGE

#define hash(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

void main() {
	color = gl_Color;
	
	normal = gl_NormalMatrix * gl_Normal;

	tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
    binormal = cross(tangent, normal);

	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	flag = 0.7;

	#ifdef WAVING_FOILAGE
	float maxStrength = 1.0 + rainStrength * 0.5;
	float time = frameTimeCounter * 3.0;
	#endif

	// Use block properties categories for waving foliage
	// Category 31: Short plants and flowers (defined in block.properties) - only lower part waves
	if (mc_Entity.x == 31.0) {
		#ifdef WAVING_FOILAGE
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			// Use integer-based hash to prevent jittering
			ivec2 intPos = ivec2(floor(gl_Vertex.x), floor(gl_Vertex.z));
			float rand_ang = hash(vec2(intPos));
			float reset = cos(rand_ang * 10.0 + time * 0.1);
			reset = max( reset * reset, max(rainStrength, 0.1));
			// Remove position.y from sin to decouple waving from player's Y coordinate
			position.x += (sin(rand_ang * 10.0 + time) * 0.05) * (reset * maxStrength);
		}
		#endif
		// Don't modify alpha - let the texture's original alpha control transparency
		// color.a *= 0.4; // REMOVED: This was causing flowers to not render
		flag = 0.50;
	// Category 32: Tall grass and double-height plants - both parts wave
	} else if (mc_Entity.x == 32.0) {
		#ifdef WAVING_FOILAGE
		// Both upper and lower parts wave together for tall grass
		// Use integer-based hash to prevent jittering
		ivec2 intPos = ivec2(floor(gl_Vertex.x), floor(gl_Vertex.z));
		float rand_ang = hash(vec2(intPos));
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		
		// Apply waving with different amplitudes for upper and lower parts
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			// Lower part: amplitude 0.1
			position.x += (sin(rand_ang * 10.0 + time) * 0.15) * (reset * maxStrength);
		} else {
			// Upper part: smaller amplitude 0.05
			position.x += (sin(rand_ang * 10.0 + time) * 0.05) * (reset * maxStrength);
		}
		#endif
		flag = 0.50;
	// Category 18: Leaves (defined in block.properties)
	} else if(mc_Entity.x == 18.0) {
		#ifdef WAVING_FOILAGE
		// Use integer-based hash to prevent jittering
		ivec2 intPos = ivec2(floor(gl_Vertex.x), floor(gl_Vertex.z));
		float rand_ang = hash(vec2(intPos));
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		// Remove position.y from sin to decouple waving from player's Y coordinate
		position.xyz += (sin(rand_ang * 5.0 + time) * 0.035 + 0.035) * (reset * maxStrength) * tangent;
		#endif
		flag = 0.50;
	// Other waving blocks (crops, mushrooms, etc.)
	} else if (mc_Entity.x == 59.0 || mc_Entity.x == 141.0 || mc_Entity.x == 142.0 || mc_Entity.x == 37.0 || mc_Entity.x == 38.0 || mc_Entity.x == 39.0 || mc_Entity.x == 40.0 || mc_Entity.x == 6.0 || mc_Entity.x == 83.0 || mc_Entity.x == 104.0 || mc_Entity.x == 105.0 || mc_Entity.x == 115.0) {
		flag = 0.51;
	}

	position = gl_ModelViewMatrix * position;
	vec3 wpos = position.xyz;
	gl_Position = gl_ProjectionMatrix * position;
	texcoord = gl_MultiTexCoord0.st;
	lmcoord = (gl_TextureMatrix[1] *  gl_MultiTexCoord1).xy;

	#ifdef ParallaxOcclusion
	f16mat3 TBN = f16mat3(tangent, binormal, normal);
	tangentpos = normalize(wpos * TBN);
	#ifdef PARALLAX_SELF_SHADOW
	sun = TBN * normalize(shadowLightPosition);
	#endif
	#endif
	
	#ifndef NORMALS
	n2 = normalEncode(normal);
	#endif
	
	dis = length(wpos);
}
