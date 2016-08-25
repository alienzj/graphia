#version 330 core

layout (location = 0) in vec3 vertexPosition;
layout (location = 1) in vec3 vertexNormal;
layout (location = 2) in vec2 vertexTexCoord;

layout (location = 3) in vec3  sourcePosition; // The position of the source node
layout (location = 4) in vec3  targetPosition; // The position of the target node

layout (location = 5) in int   component; // The component index

layout (location = 6) in float size; // The size of the edge
layout (location = 7) in vec3  color; // The color of the edge
layout (location = 8) in vec3  outlineColor; // The outline color of the node

out vec3 position;
out vec3 normal;
out vec3 vColor;
out vec3 vOutlineColor;

uniform samplerBuffer componentData;

mat4 makeOrientationMatrix(vec3 up)
{
    mat3 m;

    m[1] = up;
    m[0].y = -m[1].x;
    m[0].z = m[1].y;
    m[0].x = m[1].z;

    float d = dot(m[0], m[1]);
    m[0] -= (d * m[1]);
    m[0] = normalize(m[0]);
    m[2] = cross(m[0], m[1]);

    return mat4(m);
}

void main()
{
    float edgeLength = distance(sourcePosition, targetPosition);
    vec3 midpoint = mix(sourcePosition, targetPosition, 0.5);
    mat4 orientationMatrix = makeOrientationMatrix(normalize(targetPosition - sourcePosition));

    vec3 scaledVertexPosition = vertexPosition;
    scaledVertexPosition.xz *= size;
    scaledVertexPosition.y *= edgeLength;

    int index = component * 8;

    mat4 modelViewMatrix = mat4(texelFetch(componentData, index + 0),
                                texelFetch(componentData, index + 1),
                                texelFetch(componentData, index + 2),
                                texelFetch(componentData, index + 3));

    mat4 projectionMatrix = mat4(texelFetch(componentData, index + 4),
                                 texelFetch(componentData, index + 5),
                                 texelFetch(componentData, index + 6),
                                 texelFetch(componentData, index + 7));

    position = (orientationMatrix * vec4(scaledVertexPosition, 1.0)).xyz;
    position = (modelViewMatrix * vec4(position + midpoint, 1.0)).xyz;

    mat3 normalMatrix = transpose(inverse(mat3(modelViewMatrix * orientationMatrix)));
    normal = normalMatrix * vertexNormal;
    vColor = color;
    vOutlineColor = outlineColor;
    gl_Position = projectionMatrix * vec4(position, 1.0);
}
