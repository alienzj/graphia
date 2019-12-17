#version 330 core

in vec2 vPosition;

layout (location = 0) out vec4 fragColor;

uniform usampler2DMS frameBufferTexture;
uniform int width;
uniform int height;
uniform int multisamples;
uniform vec4 outlineColor;
uniform float alpha;

// Find the mean of the available samples using a method that avoids integer overflow
uint meanOfMSFor(ivec2 coord, int channel, uint s)
{
    coord.x = clamp(coord.x, 0, width - 1);
    coord.y = clamp(coord.y, 0, height - 1);

    uint sM1 = s - 1u;

    uint quotientSum = 0u;
    uint remainderSum = 0u;
    for(int i = 0; i < multisamples; i++)
    {
        uint v = texelFetch(frameBufferTexture, coord, i)[channel];

        quotientSum += (v / s);
        remainderSum += (v % s);
    }

    return quotientSum + ((remainderSum + (s * sM1)) / s) - sM1;
}

uint meanOfNonZeroMSFor(ivec2 coord, int channel)
{
    coord.x = clamp(coord.x, 0, width - 1);
    coord.y = clamp(coord.y, 0, height - 1);

    uint numNonZeroSamples = 0u;
    for(int i = 0; i < multisamples; i++)
    {
        uint v = texelFetch(frameBufferTexture, coord, i)[channel];

        if(v > 0u)
            numNonZeroSamples++;
    }

    if(numNonZeroSamples == 0u)
        return 0u;

    return meanOfMSFor(coord, channel, numNonZeroSamples);
}

uint quantOfMSFor(ivec2 coord, int channel)
{
    coord.x = clamp(coord.x, 0, width - 1);
    coord.y = clamp(coord.y, 0, height - 1);

    uint mean = meanOfMSFor(coord, channel, uint(multisamples));

    // Find the sample value closest to the mean,
    // thereby quantising it, so that we can identify the
    // most representative sample from those available
    uint min = 0xFFFFFFFFu;
    int qi = 0;

    for(int i = 0; i < multisamples; i++)
    {
        uint v = texelFetch(frameBufferTexture, coord, i)[channel];
        uint diff = abs(mean - v);

        if(diff < min)
        {
            min = diff;
            qi = i;
        }
    }

    return texelFetch(frameBufferTexture, coord, qi).r;
}

float edgeStrengthAt(ivec2 coord)
{
    uint s = quantOfMSFor(coord, 0);

    float numDiffPixels = 0.0;
    float projectionScale = 0.0;

    for(int i = -1; i <= 1; i++)
    {
        for(int j = -1; j <= 1; j++)
        {
            if(i == 0 && j == 0)
                continue;

            if(s != quantOfMSFor(coord + ivec2(i, j), 0))
                numDiffPixels += 1.0;

            float p = float(meanOfNonZeroMSFor(coord + ivec2(i, j), 1));

            if(p > projectionScale)
                projectionScale = p;
        }
    }

    projectionScale /= float(0xFFFFFFFFu);

    const float MIN_PS = 0.001;
    const float MAX_PS = 0.015;
    projectionScale = clamp((projectionScale - MIN_PS) / (MAX_PS - MIN_PS), 0.0, 1.0);

    // Clamp to a maximum difference, otherwise we get abnormally dark
    // spots at the junction of many elements
    const float maxNumDiffPixels = 5.0;
    numDiffPixels = min(numDiffPixels, maxNumDiffPixels);

    // Normalise
    float value = numDiffPixels / maxNumDiffPixels;

    // Give the value a bit of ramp; this thins the edges out a bit
    value = pow(value, 1.0 + ((1.0 - projectionScale) * 2.0));

    // Dial the value back a bit, helping the color come through
    // when edges are densely packed
    const float MIN_VALUE = 0.1;
    value *= MIN_VALUE + (projectionScale * (1.0 - MIN_VALUE));

    return value;
}

void main()
{
    ivec2 coord = ivec2(vPosition);
    float outlineAlpha = edgeStrengthAt(coord);

    fragColor = vec4(outlineColor.rgb, outlineAlpha * alpha);
}

