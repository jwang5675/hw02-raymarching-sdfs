#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

uniform vec3 u_LightColor;
uniform float u_Speed;

in vec2 fs_Pos;
out vec4 out_Col;

float TWO_PI = 6.2831853;

// Lights and Camera Variables
float fov = 0.7853975; // = 45.0 * 3.14159 / 180.0
vec3 light_pos = vec3(0, 15, -10);

// Metaball variables
int numMetaballs = 7;
vec4 METABALLS[7]; 
float THRESHOLD = 1.0;

// Cube Struct Object
struct Cube {
	vec3 min;
	vec3 max;
};

// Bounding Boxes
Cube cubes[2];

// Adapted from 460 slides
float rayCubeIntersect(Cube c, vec3 ray_origin, vec3 ray_dir) {
	float tnear = -1000.0;
	float tfar = 1000.0;

	for (int i = 0; i < 3; i++) {
		// edge case with 0 slope
		if (ray_dir[i] == 0.0) {
			if (ray_origin[i] < c.min[i] || ray_origin[i] > c.max[i]) {
				return 1000.0;
			}
		}

		// set up t values
		float t0 = (c.min[i] - ray_origin[i]) / ray_dir[i];
		float t1 = (c.max[i] - ray_origin[i]) / ray_dir[i];
		if (t0 > t1) {
			float temp = t0;
			t0 = t1;
			t1 = temp;
		}

		// rewrite t values
		tnear = max(t0, tnear);
		tfar = min(t1, tfar);
	}

	// miss the cube
	if (tnear > tfar) {
		return 1000.0;
	}
	// hit the cube
	return tnear;
}

// finds the next t value from bounding boxes to check
// returns <t, index> where index is the index of the shape at cubes[index]
vec2 boundingVolumeHierachy(vec3 point, vec3 dir, Cube cubes[2]) {
	float t = 1000.0;
	float index = 0.0;
	for (int i = 0; i < cubes.length(); i++) {
		float intersect = rayCubeIntersect(cubes[i], point, dir); 
		if (t > intersect) {
			t = intersect;
			index = float(i);
		}
	}
	return vec2(t, index);
}


float random1(vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 lambert(vec3 normal, vec3 direction, vec3 color) {
	float diffuseTerm = dot(normalize(normal), normalize(direction));
	diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);
	float ambientTerm = 0.2;

	float lightIntensity = diffuseTerm + ambientTerm;
	return clamp(vec3(color.rgb * lightIntensity * u_LightColor), 0.0, 1.0);
}

vec3 rotateY(vec3 original, float amt) {
	float cosA = cos(amt);
	float sinA = sin(amt);
	float x = cosA * original.x + sinA * original.z;
	float z = cosA * original.z - sinA * original.x;
	return vec3(x, original.y, z);
}

float parabola(float x, float k) {
	return pow(4.0f * x * (1.0 - x), k);
}

float sUnionSDF(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h); 
}

float sdMetaball(vec3 p) {
	float influence = 0.0;
	for (int i = 0; i < numMetaballs; i++) {
		vec3 deltaDistance = p - METABALLS[i].xyz;
		float radius = METABALLS[i].w;
		influence += radius / dot(deltaDistance, deltaDistance);
	}
	return THRESHOLD - influence;
}

// Normal found from reference: http://blackpawn.com/texts/metanormals/default.html
vec3 metaballNormal(vec3 p) {
	vec3 normal = vec3(0.0);
	for (int i = 0; i < numMetaballs; i++) {
		vec3 deltaDistance = METABALLS[i].xyz - p;
		float deltaDistanceSq = dot(deltaDistance, deltaDistance);
		normal -= 2.0 * deltaDistance / (deltaDistanceSq * deltaDistanceSq);
	}
	return normal;
}

float ambientOcclusionMetaball(vec3 p) {
	vec3 normal = metaballNormal(p);
	float ret = 0.0;
	float delta = 0.1;
	float oscillation = 2.0;
	// 5 tap AO
	for(int i = 1; i < 5; i++) {
		vec3 point = p + float(i) * delta * normal;
		float value = float(i) * delta - sdMetaball(point);
		ret = ret + value / oscillation;
		oscillation =  oscillation * 2.0;
	}
	return clamp(1.0 - 10. * ret, 0.0, 1.0);
}

vec3 metaballColor(vec3 p) {
	float t = u_Speed * u_Time;
	float x = 0.3 * (cos(t) + sin(p[0])) + 0.2;
  float y = 0.3 * (sin(t) + cos(p[1])) + 0.2;
  float z = 0.3 * (sin(t) + sin(p[2])) + 0.2;
  vec3 color = vec3(x, y, z);
  return clamp(lambert(metaballNormal(p), light_pos - p, color) + 0.15 * ambientOcclusionMetaball(p), 0.0, 1.0);
}

void setUpMetaballs() {
	for (int i = 0; i < numMetaballs; i++) {
		float rand = random1(vec2(i + 7, i + 5), vec2(i + 23, i + 41));
		float tmultiple = u_Speed * u_Time * 3.14159265;
		float offset = 3.14159265 * rand;
		if (rand > 0.5) {
			METABALLS[i].xyz = vec3(2.0 * cos(tmultiple + 17.0 * offset), 2.0 * cos(tmultiple + 34.0 * offset), 2.0 * cos(tmultiple+ 5.0 * offset));
		} else {
			METABALLS[i].xyz = vec3(2.0 * sin(tmultiple + 5.0 * offset), 2.0 * sin(tmultiple + 17.0 * offset), 2.0 * sin(tmultiple + 34.0 * offset));	
		}
		METABALLS[i].w = 0.5 * sin(tmultiple + offset * 3.0) + 0.8;
	}

	// float tmultiple = u_Speed * u_Time * 3.14159265;
	// METABALLS[0].xyz = vec3(0, 0, 0);
	// METABALLS[0].w = 0.5;
	// for (int i = 1; i < numMetaballs; i++) {
	// 	float rand = random1(vec2(i + 7, i + 5), vec2(i + 23, i + 41));
	// 	tmultiple += 3.14159265 * rand;

	// 	float movement = parabola((sin(tmultiple) + 1.0) / 2.0, 0.25);
	// 	if (mod(float(i), 2.0) == 0.0) {
	// 		movement = -1.0 * movement;
	// 	}

	// 	float height = 1.0;
	// 	if (mod(float(i), 5.0) == 0.0) {
	// 		height = 0.0;
	// 	}

	// 	METABALLS[i].xyz = 3.0 * movement * vec3(cos(tmultiple), height, 1.0 * sin(tmultiple));
	// 	METABALLS[i].w = 0.25;
	// }

}

Cube metaballsBoundingBox() {
	Cube cube;
	cube.min = vec3(-5, -5, -5);
	cube.max = vec3(5, 5, 5);
	return cube;
}

float sdFloor(vec3 p) {
	vec3 point = p + vec3(0, 7, 0);
	float radius = 5.0;
	float height = 0.5;
	vec2 d = abs(vec2(length(point.xz), point.y)) - vec2(radius, height);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));


	// dimensions of floor
	// vec3 b = vec3(5, 0.25, 5);

	// // inverse transformation of floor
	// vec3 point = rotateY(p, -1.0 * u_Speed * u_Time) + vec3(0, 7, 0);
 //  vec3 d = abs(point) - b;
 //  return length(max(d,0.0)) + min(max(d.x,max(d.y,d.z)),0.0);
}

vec3 estimateFloorNormal(vec3 p) {
	float epsilon = 0.1;
	return normalize(vec3(
		sdFloor(vec3(p.x + epsilon, p.y, p.z)) - sdFloor(vec3(p.x - epsilon, p.y, p.z)),
		sdFloor(vec3(p.x, p.y + epsilon, p.z)) - sdFloor(vec3(p.x, p.y - epsilon, p.z)),
		sdFloor(vec3(p.x, p.y, p.z + epsilon)) - sdFloor(vec3(p.x, p.y, p.z - epsilon))
	));
}

// Penumbra Shadow
float softShadowFloor(in vec3 ro, in vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  float ph = 1e20;
  for(float t = mint; t < maxt;) {
    float h = sdMetaball(ro + rd*t);
    if(h < 0.001) {
      return 0.0;
    }
    float y = h * h / (2.0 * ph);
    float d = sqrt(h * h - y * y);
    res = min(res, k * d/ max(0.0, t - y));
    ph = h;
    t += h;
  }
  return res;
}

vec3 floorColor(vec3 p) {
	vec3 point = rotateY(p, -1.0 * u_Speed * u_Time);
	float binary = floor(mod(4.0 * (sin(point.x * 2.0) + sin(point.z * 2.0)), 2.0));
	vec3 color = vec3(binary);
	if (binary == 0.0) {
		color = vec3(1, 0.713, 0.756);
	} 
	
	float shadow = softShadowFloor(p, estimateFloorNormal(p), 0.1, 10.0, 8.0);
	color = clamp(shadow * color, 0.0, 1.0);

	return clamp(lambert(estimateFloorNormal(point), light_pos - point, color) + vec3(0.15), 0.0, 1.0);
}

Cube boundingBoxFloor() {
	Cube cube;
	cube.min = vec3(-10, -10, -10);
	cube.max = vec3(10, -3, 10);
	return cube;
}

float sdPopUp(vec3 p) {
	float rise = parabola((sin(10.0 * u_Speed * u_Time) + 1.0) / 2.0, 2.5);
	vec3 dim = vec3(0.6, 0.6, 0.6);
	vec3 point = rotateY(p + vec3(0, -rise, 0), 5.0 * u_Speed * u_Time);
	float radius = 0.1;
  return length(max(abs(point) - dim, 0.0)) - radius;
}

float sdMole(vec3 p) {
	vec3 points[4];
	points[0] = rotateY(p, 3.0 * u_Speed * u_Time) + vec3(7, 7, 0);
	points[1] = rotateY(p, 3.0 * u_Speed * u_Time) + vec3(0, 7, 7);
	points[2] = rotateY(p, 3.0 * u_Speed * u_Time) + vec3(-7, 7, 0);
	points[3] = rotateY(p, 3.0 * u_Speed * u_Time) + vec3(0, 7, -7);

	float ret = 10.0;
	for (int i = 0; i < points.length(); i++) {
		vec3 point = points[i];
		vec2 t = vec2(1.25, 0.5);
  	vec2 q = vec2(length(point.xz) - t.x, point.y);
  	ret = min(ret, sUnionSDF(length(q) - t.y, sdPopUp(point), 0.2));
	}
	return ret;
}

vec3 estimateMoleNormal(vec3 p) {
	float epsilon = 0.1;
	return normalize(vec3(
		sdMole(vec3(p.x + epsilon, p.y, p.z)) - sdMole(vec3(p.x - epsilon, p.y, p.z)),
		sdMole(vec3(p.x, p.y + epsilon, p.z)) - sdMole(vec3(p.x, p.y - epsilon, p.z)),
		sdMole(vec3(p.x, p.y, p.z + epsilon)) - sdMole(vec3(p.x, p.y, p.z - epsilon))
	));
}

float ambientOcclusionMole(vec3 p) {
	vec3 normal = estimateMoleNormal(p);
	float ret = 0.0;
	float delta = 0.1;
	float oscillation = 2.0;
	// 5 tap AO
	for(int i = 1; i < 5; i++) {
		vec3 point = p + float(i) * delta * normal;
		float value = float(i) * delta - sdMole(point);
		ret = ret + value / oscillation;
		oscillation =  oscillation * 2.0;
	}
	return clamp(1.0 - 10.0 * ret, 0.0, 1.0);
}

vec3 moleColor(vec3 p) {
	//vec3 color = vec3(0.450, 0.482, 0.611);
	vec3 point = rotateY(p, 3.0 * u_Speed * u_Time) + vec3(7, 7, 0);
	float binary = floor(mod(4.0 * (sin(point.x * 2.0) + sin(point.z * 2.0)), 2.0));
	vec3 color = vec3(binary);
	if (binary == 0.0) {
		color = vec3(1, 0.713, 0.756);
	} 
	return clamp(lambert(estimateMoleNormal(p), light_pos - p, color) + 0.15 * vec3(ambientOcclusionMole(p)), 0.0, 1.0);
}

void setUpBoundingBoxes() {
	cubes[0] = metaballsBoundingBox();
	cubes[1] = boundingBoxFloor();
}

void main() {
	// Set up Rays
	vec3 u_Right = normalize(cross(u_Ref - u_Eye, u_Up));
	float len = length(u_Ref - u_Eye);
	float aspectRatio = u_Dimensions.x / u_Dimensions.y;
	vec3 v = tan(fov / 2.0) * len * u_Up;
	vec3 h = aspectRatio * tan(fov / 2.0) * len * u_Right;
	vec3 worldPoint = u_Ref + fs_Pos.x * h + fs_Pos.y * v;
	vec3 ray_direction = normalize(worldPoint - u_Eye);

	// Set up Scene
	setUpMetaballs();
	setUpBoundingBoxes();

	// Ray Marching
	vec3 color =  clamp(0.5 * (rotateY(ray_direction, u_Speed * u_Time - 0.5) + vec3(1.0, 1.0, 1.0)) + 0.2 * u_LightColor, 0.0, 1.0);
	vec2 params = boundingVolumeHierachy(u_Eye, ray_direction, cubes);
	float t = params.x;
	while (t < 50.0) {
		vec3 point = u_Eye + t * ray_direction;
		if (sdMetaball(point) < 0.1) {
			color = metaballColor(point);
			break;
		}
		if (sdFloor(point) < 0.1) {
			color = floorColor(point);
			break;
		}
		if (sdMole(point) < 0.1) {
			color = moleColor(point);
			break;
		}
		t = t + 0.05;
	}

  out_Col = vec4(color, 1.0);
}
