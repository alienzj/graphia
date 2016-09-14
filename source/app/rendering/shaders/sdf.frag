#version 330 core

// This Shader Generates an SDF map of a large texture
// the resulting texture will be texSize.x/scaleFactor wide and texSize.y/scaleFactor talln
// tex is the texture to SDF
// texSize is the size of the texture in pixels
// scaleFactor is how much smaller the resultant texture will be in height + width

uniform sampler2D tex;
uniform vec2 texSize;
uniform float scaleFactor;

layout(location = 0) out vec4 outColor;

in vec2 vPosition;

bool isIn(vec2 uv)
{
   return (texture(tex, uv)).a > 0.1;
}

float squaredDistanceBetween(vec2 uv1, vec2 uv2)
{
    vec2 delta = uv1 - uv2;
    float dist = (delta.x * delta.x) + (delta.y * delta.y);
    return dist;
}

void main()
{
    // gl_FragCoord is in pixels so will be smaller than texSize
    vec2 scaledFragCoord = gl_FragCoord.xy * scaleFactor;
    vec2 uv = scaledFragCoord / texSize.xy;

    const float range = 8.0;
    // Have to set manually to scaleFactor! (4.0 in this case)
    const int scalediRange = int(range * 4.0);
    float scaledHalfRange = (range / 2.0) * scaleFactor;
    vec2 startPosition = vec2(scaledFragCoord.x - scaledHalfRange, scaledFragCoord.y - scaledHalfRange);

    bool fragIsIn = isIn(uv);
    float squaredDistanceToEdge = (scaledHalfRange * scaledHalfRange) * 2.0;

    for(int dx = 0; dx < scalediRange; dx++)
    {
        for(int dy = 0; dy < scalediRange; dy++)
        {
            vec2 scanPosition = startPosition + vec2(dx, dy);

            bool scanIsIn = isIn(scanPosition / texSize.xy);
            if(scanIsIn != fragIsIn)
            {
                float scanDistance = squaredDistanceBetween(scaledFragCoord.xy, scanPosition);
                if(scanDistance < squaredDistanceToEdge)
                    squaredDistanceToEdge = scanDistance;
            }
        }
    }

    float normalised = squaredDistanceToEdge / (scaledHalfRange * scaledHalfRange) * 2.0;
    float distanceToEdge = sqrt(normalised);
    if(fragIsIn)
        normalised = -normalised;
    normalised = 0.5 - (normalised / 2.0);

    // Uncomment for outline
    //if(normalised > 0.5)
    //   fragColor = vec4(1.0);
    //else
        outColor = vec4(normalised, normalised, normalised, 1.0);
}


