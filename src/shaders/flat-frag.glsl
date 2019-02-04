#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

float fov = 90.0 * 3.14159 / 180.0;

void main() {
	vec3 u_Right = normalize(cross(u_Ref - u_Eye, u_Up));
	float len = length(u_Ref - u_Eye);
	float aspectRatio = u_Dimensions.x / u_Dimensions.y;
	vec3 v = tan(fov / 2.0) * len * u_Up;
	vec3 h = aspectRatio * tan(fov / 2.0) * len * u_Right;
	vec3 point = u_Ref + fs_Pos.x * h + fs_Pos.y * v;
	vec3 ray_direction = normalize(point - u_Eye);

	vec3 color = 0.5 * (ray_direction + vec3(1.0, 1.0, 1.0));
  out_Col = vec4(color, 1.0);
}
