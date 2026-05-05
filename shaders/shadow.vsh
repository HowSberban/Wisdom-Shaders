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

#pragma optimize(on)

#define SHADOW_MAP_BIAS 0.85
const float negBias = 1.0f - SHADOW_MAP_BIAS;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying vec2 texcoord;
varying vec3 color;
varying float LOD;

//uniform mat4 shadowProjection;

#define hash(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

#define WAVING_SHADOW

// 高性能哈希函数，并不追求精度
float plantHash(vec2 coord) {
    return fract(dot(coord, vec2(0.1, 0.3)));
}

void main() {
	vec4 position = gl_Vertex;
	color = gl_Color.rgb;

	float blockId = mc_Entity.x;
	#ifdef WAVING_SHADOW
	// 使用四舍五入计算方块位置，避免边界跳变导致的抖动
	vec2 plantPos = floor((gl_Vertex.xz + cameraPosition.xz) + 0.5);
	
	// 使用方块属性分类植物晃动
	if (gl_MultiTexCoord0.t < mc_midTexCoord.t && blockId == 31.0) {
		// 使用稳定的世界坐标生成独立随机种子
		float rand_ang = plantHash(plantPos);
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand_ang * 10.0 + frameTimeCounter * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.5));
		// X 和 Z 方向都晃动（使用相同相位，形成对角线摆动）
		float waveOffset = (sin(rand_ang * 10.0 + time) * 0.05) * (reset * maxStrength);
		position.x += waveOffset;
		position.z += waveOffset;
	} else if (blockId == 32.0) {
		// 使用稳定的世界坐标生成独立随机种子
		float rand_ang = plantHash(plantPos);
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand_ang * 10.0 + frameTimeCounter * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.5));
		// 上部使用较大幅度，与 gbuffers_terrain.vsh 保持一致
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			float waveOffset = (sin(rand_ang * 10.0 + time) * 0.15) * (reset * maxStrength);
			position.x += waveOffset;
			position.z += waveOffset;
		} else {
			float waveOffset = (sin(rand_ang * 10.0 + time) * 0.05) * (reset * maxStrength);
			position.x += waveOffset;
			position.z += waveOffset;
		}
	} else if (blockId == 18.0) {
		// 使用稳定的世界坐标生成独立随机种子
		float rand_ang = plantHash(plantPos);
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand_ang * 10.0 + frameTimeCounter * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.5));
		position.xyz += (sin(rand_ang * 5.0 + time) * 0.035 + 0.035) * (reset * maxStrength);
	}
	position = gl_ProjectionMatrix * (gl_ModelViewMatrix * position);
	#else
	position = ftransform();
	#endif
	
	float l = sqrt(dot(position.xy, position.xy));

	// 阴影偏移：使用径向压缩防止漏光（只能简单地防止。。）
	position.xy /= l * SHADOW_MAP_BIAS + negBias;
	
	LOD = l * 2.0;
	// 禁用远距离晃动物体的阴影投射
	if ((blockId == 31.0 || blockId == 32.0 || blockId == 18.0) && l > 0.5) position.z -= 1000000.0f;

	gl_Position = position;
	texcoord = gl_MultiTexCoord0.st;
}
