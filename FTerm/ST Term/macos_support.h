//
//  macos_support.h
//  FortranProcessing
//
//  Created by Michael Larson on 11/28/23.
//

#ifndef macos_support_h
#define macos_support_h

#include <stdio.h>
#include "st.h"

enum win_mode {
    MODE_VISIBLE     = 1 << 0,
    MODE_FOCUSED     = 1 << 1,
    MODE_APPKEYPAD   = 1 << 2,
    MODE_MOUSEBTN    = 1 << 3,
    MODE_MOUSEMOTION = 1 << 4,
    MODE_REVERSE     = 1 << 5,
    MODE_KBDLOCK     = 1 << 6,
    MODE_HIDE        = 1 << 7,
    MODE_APPCURSOR   = 1 << 8,
    MODE_MOUSESGR    = 1 << 9,
    MODE_8BIT        = 1 << 10,
    MODE_BLINK       = 1 << 11,
    MODE_FBLINK      = 1 << 12,
    MODE_FOCUS       = 1 << 13,
    MODE_MOUSEX10    = 1 << 14,
    MODE_MOUSEMANY   = 1 << 15,
    MODE_BRCKTPASTE  = 1 << 16,
    MODE_NUMLOCK     = 1 << 17,
    MODE_MOUSE       = MODE_MOUSEBTN|MODE_MOUSEMOTION|MODE_MOUSEX10\
                      |MODE_MOUSEMANY,
};

typedef struct {
    int cx, cy;
    int mode;
    Glyph g;
} MacOS_Cursor;

void macos_bell(void);
void macos_clipcopy(void);
void macos_drawcursor(int cx, int cy, Glyph g, int ox, int oy, Glyph og);
void macos_drawline(Line line, int x1, int y1, int x2);
void macos_finishdraw(void);
void macos_loadcols(void);
int macos_setcolorname(int x, const char *name);
int macos_getcolor(int x, unsigned char *r, unsigned char *g, unsigned char *b);
void macos_seticontitle(char *p);
void macos_settitle(char *p);
int macos_setcursor(int cursor);
void macos_setmode(int set, unsigned int flags);
void macos_setpointermotion(int set);
void macos_setsel(char *str);
int macos_startdraw(void);
void macos_ximspot(int x, int y);

// from unused x file
void macos_cresize(int width, int height);

#endif /* macos_support_h */
