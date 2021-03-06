/**
 * This file is part of prototype.
 *
 * (c) 2013 Nicolas Hillegeer <nicolas@hillegeer.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with the source code.
 *
 * layout(location = 0) = position
 * layout(location = 1) = normal
 * layout(location = 2) = texcoord
 * layout(location = 3) = color
 * layout(location = 4) = tangent
 */

#version 150
#extension GL_ARB_explicit_attrib_location : enable

/* uniform buffers */
layout(std140) uniform StaticMatrices {
    mat4 projectionMatrix;
    // mat3 normalMatrix;
    // vec4 ambient;
    // vec4 diffuse;
    // vec4 specular;
    // vec4 position;
    // vec4 direction;
    float timer;
};

/* uniforms */
uniform float xs = 3.0, zs = 4.0;
// uniform mat4 projection;

/* in */
layout(location = 0) in vec3 in_position;

out VertexData {
    vec4 color;
} o;

void main() {
    float PI             = 3.14159265358979323846264;
    float width          = 5.0;
    vec3 vtimer          = mod(width * in_position + timer, 2.0 * PI);
    float s              = 1.0 * sin(vtimer.x) * cos(vtimer.z);

    /* assume input y is always 0 */
    float maxy = 0.5 * 1 * 1;
    float miny = 0.5 * -1 * 1;

    vec3 trans_position = in_position;
    trans_position.y = s; //* in_position.y;

    float color_base = (s + maxy) / (maxy - miny);

    o.color = vec4(
        clamp(color_base * color_base, 0.0, 1.0),
        clamp(1.0 - (color_base - 0.5) * (color_base - 0.5), 0.0, 1.0),
        clamp(1.0 - color_base, 0.0, 1.0),
        1.0
    );

    gl_Position = projectionMatrix * vec4(trans_position, 1.0);
}