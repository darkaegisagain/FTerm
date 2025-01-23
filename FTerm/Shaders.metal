/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal shaders used for this sample
*/

#include <metal_stdlib>

using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands.
#include "ShaderTypes.h"

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];
    float2 st;
    
    float2 pixelSpacePosition [[flat]];
    int isCursor [[flat]];
};

// To convert from positions in pixel space to positions in clip-space,
//  divide the pixel coordinates by half the size of the viewport.
float2 convert_to_metal_coordinates(float2 point, float2 viewSize) {
    
    float2 inverseViewSize = 1.0f / viewSize;
    float clipX = (2.0f * point.x * inverseViewSize.x) - 1.0f;
    float clipY = (2.0f * -point.y * inverseViewSize.y) + 1.0f;
    
    return float2(clipX, clipY);
}

vertex RasterizerData
termVertexShader(uint vertexID [[vertex_id]],
             constant FTermVertex *vertices [[buffer(FTermVertexInputIndexVertices)]],
             constant FTermBuffer *ftBuffer [[buffer(FTermVertexInputIndexUniforms)]])
{
    RasterizerData out;

    // Index into the array of positions to get the current vertex.
    // The positions are specified in pixel dimensions (i.e. a value of 100
    // is 100 pixels from the origin).
    float2 pixelSpacePosition = vertices[vertexID].position.xy;

    // Get the viewport size and cast to float.
    vector_float2 viewportSize = ftBuffer->viewportSize;
    
    out.position = vector_float4(convert_to_metal_coordinates(pixelSpacePosition, viewportSize), 0.0, 1.0);
    out.st = vertices[vertexID].st;
    
    // pixelSpacePosition is needed to figure out the row col.. should probably do it in the vertex shader.
    out.pixelSpacePosition = pixelSpacePosition;
    
    // the first quad drawn is the cursor
    if (vertexID < 4)
        out.isCursor = 1;
    else
        out.isCursor = 0;
    
    return out;
}


constexpr sampler textureSampler (mag_filter::nearest,
                                  min_filter::nearest);


fragment float4 termFragmentShader(RasterizerData in [[stage_in]],
                               constant FTermBuffer *ftBuffer [[buffer(FTermFragmentInputIndexUniforms)]],
                               texture2d<float> tex [[texture(0)]]
                               )
{
    // return float4(1.0, 1.0, 1.0, 1.0);
    // return tex.sample(textureSampler, in.st);
    float4 color;

    int current_font;
    current_font = ftBuffer->current_font;
    
    int font_size;
    font_size = ftBuffer->font_info[current_font].size;
    
    Glyph glyph;

    // figure out the glyph for this location
    int row, col;
    
    col = in.pixelSpacePosition.x / font_size;
    row = in.pixelSpacePosition.y / font_size;
    
    int n_cols, n_rows;
    n_cols = ftBuffer->cols;
    n_rows = ftBuffer->rows;
    
    glyph = ftBuffer->character_buffer[row * n_cols + col];
    
    int c;
    c = glyph.u;
    
    if (c != 0)
    {
        float fg_r, fg_g, fg_b, fg_a;
        float bg_r, bg_g, bg_b, bg_a;
        
        int fg, bg;
        
        fg = glyph.fg;
        bg = glyph.bg;
        
        if (fg < MAX_COLOR_TABLE_ENTRY)
        {
            fg_r = ftBuffer->palette[fg].r;
            fg_g = ftBuffer->palette[fg].g;
            fg_b = ftBuffer->palette[fg].b;
            fg_a = ftBuffer->palette[fg].a;
        }
        
        if (bg < MAX_COLOR_TABLE_ENTRY)
        {
            bg_r = ftBuffer->palette[bg].r;
            bg_g = ftBuffer->palette[bg].g;
            bg_b = ftBuffer->palette[bg].b;
            bg_a = ftBuffer->palette[bg].a;
        }
        
        color = tex.sample(textureSampler, in.st);
        if (color.r > 0.3)
        {
            color.r = fg_r;
            color.g = fg_g;
            color.b = fg_b;
            color.a = 1.0;
            color = float4(fg_r, fg_g, fg_b, fg_a);
        }
        else
        {
            color.r = bg_r;
            color.g = bg_g;
            color.b = bg_b;
            color.a = 1.0;
            color = float4(bg_r, bg_g, bg_b, bg_a);
        }
        
        color = float4(color.r, color.g, color.b, 1.0);
    }
    else
    {
        color = float4(0.0, 0.0, 1.0, 1.0);
    }

    // Return the interpolated color.
    return color;
}

