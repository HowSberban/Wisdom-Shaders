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

// 改进的哈希函数 - 使用世界坐标实现区域独立晃动
float plantHash(vec2 coord) {
    return fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	vec4 position = gl_Vertex;
	color = gl_Color.rgb;

	float blockId = mc_Entity.x;
	#ifdef WAVING_SHADOW
	// 使用 gl_Vertex + cameraPosition 计算稳定的世界坐标（避免矩阵转换的精度问题）
	vec3 plantWorldPos = gl_Vertex.xyz + cameraPosition;
	
	// 类别 31：矮植物和花朵 - 只有下部晃动
	if (gl_MultiTexCoord0.t < mc_midTexCoord.t && blockId == 31.0) {
		// 使用稳定的世界坐标生成独立随机种子
		vec2 plantPos = floor(plantWorldPos.xz);
		float rand_ang = plantHash(plantPos);
		float maxStrength = 1.0 + rainStrength * 0.5;
		// 雨天时加快晃动速度（基础速度 3.0，雨天最怏可达 4.5）
		float time = frameTimeCounter * (3.0 + rainStrength * 1.5);
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.5));
		position.x += (sin(rand_ang * 10.0 + time) * 0.2) * (reset * maxStrength);
	}
	// 类别 32：高草 - 上下部分都晃动
	if (blockId == 32.0) {
		// 使用稳定的世界坐标生成独立随机种子
		vec2 plantPos = floor(plantWorldPos.xz);
		float rand_ang = plantHash(plantPos);
		float maxStrength = 1.0 + rainStrength * 0.5;
		// 雨天时加快晃动速度（基础速度 3.0，雨天最怏可达 4.5）
		float time = frameTimeCounter * (3.0 + rainStrength * 1.5);
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.5));
		position.x += (sin(rand_ang * 10.0 + time) * 0.2) * (reset * maxStrength);
	}
	position = gl_ProjectionMatrix * (gl_ModelViewMatrix * position);
	#else
	position = ftransform();
	#endif
	
	float l = sqrt(dot(position.xy, position.xy));

//	vec4 testpos = shadowProjection * (gbufferModelViewInverse * vec4(0.0, 0.0, 1.0, 1.0));
//	if (dot(normalize(testpos.xy), normalize(position.xy)) < -0.3) position.z -= 1000000.0f;

	position.xy /= l * SHADOW_MAP_BIAS + negBias;
	
	LOD = l * 2.0;
	// 禁用远距离晃动物体的阴影投射
	if ((blockId == 31.0 || blockId == 32.0) && l > 0.5) position.z -= 1000000.0f;

	gl_Position = position;
	texcoord = gl_MultiTexCoord0.st;
}
