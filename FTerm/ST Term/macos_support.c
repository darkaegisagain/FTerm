//
//  macos_support.c
//  FTerm
//
//  Created by Michael Larson on 11/28/23.
//

#include <unistd.h>
#include <assert.h>
#include <string.h>

#include "st.h"
#include "st_types.h"
#include "macos_support.h"


typedef struct {
    unsigned short red, green, blue, alpha;
} XRenderColor;

typedef struct _XftColor {
    unsigned long   pixel;
    XRenderColor    color;
} XftColor;

typedef XftColor Color;

typedef struct {
    char *name;
    XRenderColor color;
} ColorEntry;

// color table loaded from rgb.txt
unsigned num_default_x11_color_entries = 0;
ColorEntry *default_x11_color_table;

// palette table
#define MAX_COLOR_TABLE_ENTRY 1024
int init_color_palette = 1;
int macos_palette_dirty = 0;                // read in Renederer updatePalette
int palette_size = MAX_COLOR_TABLE_ENTRY;
ColorEntry color_palette[MAX_COLOR_TABLE_ENTRY];

/* Font structure */
#define Font Font_
typedef struct {
    int height;
    int width;
    int ascent;
    int descent;
    int badslant;
    int badweight;
    short lbearing;
    short rbearing;
    //XftFont *match;
    //FcFontSet *set;
    //FcPattern *pattern;
} Font;

/* Drawing Context */
typedef struct {
    Color *col;
    size_t collen;
    Font font, bfont, ifont, ibfont;
    //GC gc;
} DC;

// this is a constant used in st.c.. doesn't seem to change
static int macos_borderpx = 2;

// from st.c, its a global there
extern Term term;

// local copy of win structure
TWindow win;

// cursor information here, filled out by draw cursor, read by
// render.m in drawing screen
MacOS_Cursor macos_cursor;

// display list codes
enum {
    kBell,
    kClipCopy,
    kDrawCursor,
    kDrawLine,
    kFinishDraw,
    kLoadCols,
    kSetColorName,
    //kGetColor,
    kEnd
};

//typedef unsigned X11_Color;

/* Terminal colors (16 first used in escape sequence) */
static const char *colorname[] = {
    /* 8 normal colors */
    "black",
    "red3",
    "green3",
    "yellow3",
    "blue2",
    "magenta3",
    "cyan3",
    "gray90",

    /* 8 bright colors */
    "gray50",
    "red",
    "green",
    "yellow",
    "#5c5cff",
    "magenta",
    "cyan",
    "white",

    [255] = 0,

    /* more colors can be added after 255 to use with DefaultXX */
    "#cccccc",
    "#555555",
    "gray90", /* default foreground colour */
    "black", /* default background colour */
};


/*
 * Default colors (colorname index)
 * foreground, background, cursor, reverse cursor
 */
//unsigned int defaultfg = 258;
//unsigned int defaultbg = 259;
//unsigned int defaultcs = 256;
static unsigned int defaultrcs = 257;

ushort sixd_to_16bit(int x)
{
    return x == 0 ? 0 : 0x3737 + 0x2828 * x;
}

int searchDefaultX11ColorTableForName(const char *name)
{
    if (name && name[0] != '#')
    {
        for(int i=0; i<num_default_x11_color_entries; i++)
        {
            if (!strcmp(default_x11_color_table[i].name, name))
            {
                return i;
            }
        }
    }
    
    return -1;
}

int compareColors(XRenderColor *a, XRenderColor *b)
{
    if (a->red != b->red)
        return 0;
    
    if (a->green != b->green)
        return 0;

    if (a->blue != b->blue)
        return 0;

    if (a->alpha != b->alpha)
        return 0;
    
    return 1;
}

int searchDefaultX11ColorTableForColor(XRenderColor *color)
{
    for(int i=0; i<num_default_x11_color_entries; i++)
    {
        if (compareColors(&default_x11_color_table[i].color, color))
        {
            return i;
        }
    }
    
    return -1;
}

int allocPaletteEntry(XRenderColor *color, Color *ncolor)
{
    const char *name;
    
    for(int i=0; i<MAX_COLOR_TABLE_ENTRY; i++)
    {
        name = colorname[i];
        
        int index;
        index = searchDefaultX11ColorTableForName(name);
        
        if (index != -1)
        {
            ncolor->pixel = index;
            ncolor->color = *color;
            
            return 1;
        }
    }
    
    // ok we didn't find a color add one to table
    for(int i=0; i<MAX_COLOR_TABLE_ENTRY; i++)
    {
        if (color_palette[i].name == NULL)
        {
            char derived_name[128];
            
            snprintf(derived_name, 128, "color_%d_%d_%d_%d", color->red, color->green, color->blue, color->alpha);
            
            color_palette[i].name = strdup(derived_name);
            color_palette[i].color = *color;
            
            ncolor->pixel = i;
            ncolor->color = *color;
            
            // mark the palette dirty so it gets uploaded to the GPU
            macos_palette_dirty = 1;
            
            return 1;
        }
    }
    
    assert(0);
    return 0;
}

void initDefaultColorTable(void)
{
    size_t len;
    
    len = (sizeof(colorname) / sizeof(char *));
    
    // load defaults from color table
    for(int i=0; i<len; i++)
    {
        color_palette[i].name = default_x11_color_table[i].name;
        color_palette[i].color = default_x11_color_table[i].color;
    }
    
    for(int i=0; i<len; i++)
    {
        const char *name;
        
        name = colorname[i];
        
        int index;
        index = searchDefaultX11ColorTableForName(name);
        
        if (index != -1)
        {
            color_palette[i] = default_x11_color_table[index];
        }
        else if (name && name[0] == '#')
        {
            XRenderColor color;
            Color ncolor;

            unsigned char r, g, b;
            
            const char *tmp;
            tmp = name + 1;
            r = *tmp++ - '0';
            r = (r<<4) + (*tmp++ - '0');
            g = *tmp++ - '0';
            g = (g<<4) + (*tmp++ - '0');
            b = *tmp++ - '0';
            b = (b<<4) + (*tmp++ - '0');

            color.red = r << 8;
            color.green = g << 8;
            color.blue = b << 8;
            color.alpha = 0xffff;
            
            allocPaletteEntry(&color, &ncolor);
        }
    }
    
    macos_palette_dirty = 1;
    init_color_palette = 0;
}

int getColor(int i, const char *name, Color *ncolor)
{
    XRenderColor color = { .alpha = 0xffff };

    if (init_color_palette)
    {
        initDefaultColorTable();
    }
    
    if (!name)
    {
        if (BETWEEN(i, 16, 255))
        {
            /* 256 color */
            if (i < 6*6*6+16)
            {
                /* same colors as xterm */
                color.red   = sixd_to_16bit( ((i-16)/36)%6 );
                color.green = sixd_to_16bit( ((i-16)/6) %6 );
                color.blue  = sixd_to_16bit( ((i-16)/1) %6 );
            }
            else
            {
                /* greyscale */
                color.red = 0x0808 + 0x0a0a * (i - (6*6*6+16));
                color.green = color.blue = color.red;
            }
            
            //return XftColorAllocValue(xw.dpy, xw.vis,
            //                          xw.cmap, &color, ncolor);
            return allocPaletteEntry(&color, ncolor);
        }
        else
        {
            name = colorname[i];
        }
    }

    
    int pixel = searchDefaultX11ColorTableForName(name);
    
    if (pixel != -1)
    {
        ncolor->pixel = pixel;
        ncolor->color = default_x11_color_table[pixel].color;
        
        return 1;
    }
    
    return allocPaletteEntry(&color, ncolor);
}

float x11ColorComponentAsFloat(unsigned short c)
{
    return (float) c / (float)((1 << 16) - 1);
}

void getPaletteEntryAsFloats(int index, float *color)
{
    color[0] = x11ColorComponentAsFloat(color_palette[index].color.red);
    color[1] = x11ColorComponentAsFloat(color_palette[index].color.green);
    color[2] = x11ColorComponentAsFloat(color_palette[index].color.blue);
    color[3] = x11ColorComponentAsFloat(color_palette[index].color.alpha);
}

void macos_bell(void)
{
//    assert(0);
}

void macos_clipcopy(void)
{
    assert(0);
}

void macos_drawcursor(int cx, int cy, Glyph g, int ox, int oy, Glyph og)
{
//    X11_Color drawcol;

    if (IS_SET(MODE_HIDE))
        return;

    /*
     * Select the right color for the right mode.
     */
    g.mode &= ATTR_BOLD|ATTR_ITALIC|ATTR_UNDERLINE|ATTR_STRUCK|ATTR_WIDE;

    if (IS_SET(MODE_REVERSE)) {
        g.mode |= ATTR_REVERSE;
        g.bg = defaultfg;
        if (selected(cx, cy)) {
//            drawcol = dc.col[defaultcs];
            g.fg = defaultrcs;
        } else {
//            drawcol = dc.col[defaultrcs];
            g.fg = defaultcs;
        }
    } else {
        if (selected(cx, cy)) {
            g.fg = defaultfg;
            g.bg = defaultrcs;
        } else {
            g.fg = defaultbg;
            g.bg = defaultcs;
        }
//        drawcol = dc.col[g.bg];
    }
    
    macos_cursor.cx = cx;
    macos_cursor.cy = cy;
    macos_cursor.g = g;
    macos_cursor.mode = win.mode;
}

void macos_drawline(Line line, int x1, int y1, int x2)
{
    //printf("%s line %p x1:%d y1:%d x2:%d\n", __FUNCTION__, line, x1, y1, x2);
}

void macos_finishdraw(void)
{
    //printf("%s\n", __FUNCTION__);
}

void macos_loadcols(void)
{
    if (init_color_palette)
    {
        initDefaultColorTable();
    }
}

int macos_setcolorname(int x, const char *name)
{
    assert(0);

    return 0;
}

int macos_getcolor(int x, unsigned char *r, unsigned char *g, unsigned char *b)
{
    assert(0);

    return 0;
}

void macos_seticontitle(char *p)
{
    assert(0);
}

void macos_settitle(char *p)
{
    assert(0);
}

int macos_setcursor(int cursor)
{
    assert(0);

    return 0;
}

void macos_setmode(int set, unsigned int flags)
{
    //printf("%s set:%d flags:%u\n", __FUNCTION__, set, flags);

    int mode = win.mode;
    
    MODBIT(win.mode, set, flags);
    if ((win.mode & MODE_REVERSE) != (mode & MODE_REVERSE))
        redraw();
}

void macos_setpointermotion(int set)
{
    assert(0);
}

void macos_setsel(char *str)
{
    assert(0);
}

int macos_startdraw(void)
{
    //printf("%s\n", __FUNCTION__);
    
    return 1;
}

void macos_ximspot(int x, int y)
{
    //printf("%s x:%d y:%d\n", __FUNCTION__, x, y);
}

void macos_cresize(int width, int height)
{
    int col, row;

    if (width != 0)
        win.w = width;
    if (height != 0)
        win.h = height;

    col = (win.w - 2 * macos_borderpx) / win.cw;
    row = (win.h - 2 * macos_borderpx) / win.ch;
    col = MAX(1, col);
    row = MAX(1, row);

    win.tw = col * win.cw;
    win.th = row * win.ch;

    printf("%s width,height: %d,%d rows,cols: %d,%d\n", __FUNCTION__, width, height, row, col);
    
    tresize(col, row);
    ttyresize(win.tw, win.th);
}
