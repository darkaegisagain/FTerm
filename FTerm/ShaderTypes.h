/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header containing types and enum constants shared between Metal shaders and C/ObjC source
*/

#ifndef FTermTypes_h
#define FTermTypes_h

#include <simd/simd.h>

#define MAX_FONTS   32
#define MAX_ROW     512
#define MAX_COL     512
#define MAX_COLOR_TABLE_ENTRY 1024

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum FTermVertexInputIndex
{
    FTermVertexInputIndexVertices    = 0,
    FTermVertexInputIndexUniforms    = 1,
} FTermVertexInputIndex;

typedef enum FTermFragmentInputIndex
{
    FTermFragmentInputIndexUniforms    = 0,
} FTermFragmentInputIndex;

//  This structure defines the layout of vertices sent to the vertex
//  shader. This header is shared between the .metal shader and C code, to guarantee that
//  the layout of the vertex array in the C code matches the layout that the .metal
//  vertex shader expects.
typedef struct {
    vector_float2 position;
    vector_float2 st;
} FTermVertex;

typedef struct {
    float r, g, b, a;
} TTFontPaletteEntry;

typedef struct
{
   unsigned short x0, y0, x1, y1; // coordinates of bbox in bitmap
   float xoff, yoff, xadvance;
} TTFontBakedChar;

typedef struct {
    int size;
    int ascent, descent, lineGap;
    int len;        // number of glyphs
    int offset;     // first glyph
    int sampler_index;
    float tex_width, tex_height;
} TTFontInfo;

typedef uint32_t Rune;

typedef struct {
    Rune u;           /* character code */
    ushort mode;      /* attribute flags */
    uint32_t fg;      /* foreground  */
    uint32_t bg;      /* background  */
} Glyph;

typedef struct {
    int cx, cy;
    int mode;
    Glyph g;
} Cursor;

typedef struct {
    vector_float2 viewportSize;
    int screen_width, screen_height;
    float screen_offset;
    
    int max_row, max_col;
    int rows, cols;

    int current_color_index;
    TTFontPaletteEntry palette[MAX_COLOR_TABLE_ENTRY];

    int fg, bg;
    
    int num_fonts;
    int current_font;
    TTFontInfo font_info[MAX_FONTS];

    Cursor cursor;
    
    Glyph character_buffer[MAX_ROW * MAX_COL];
} FTermBuffer;

#endif /* FTermTypes_h */
