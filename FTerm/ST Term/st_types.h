//
//  st_types.h
//  FTerm
//
//  Created by Michael Larson on 12/6/23.
//

#ifndef st_types_h
#define st_types_h


/* Arbitrary sizes */
#define UTF_INVALID   0xFFFD
#define UTF_SIZ       4
#define ESC_BUF_SIZ   (128*UTF_SIZ)
#define ESC_ARG_SIZ   16
#define STR_BUF_SIZ   ESC_BUF_SIZ
#define STR_ARG_SIZ   ESC_ARG_SIZ

/* macros */
#define IS_SET(flag)        ((term.mode & (flag)) != 0)
#define ISCONTROLC0(c)        (BETWEEN(c, 0, 0x1f) || (c) == 0x7f)
#define ISCONTROLC1(c)        (BETWEEN(c, 0x80, 0x9f))
#define ISCONTROL(c)        (ISCONTROLC0(c) || ISCONTROLC1(c))
#define ISDELIM(u)        (u && wcschr(worddelimiters, u))

enum term_mode {
    MODE_WRAP        = 1 << 0,
    MODE_INSERT      = 1 << 1,
    MODE_ALTSCREEN   = 1 << 2,
    MODE_CRLF        = 1 << 3,
    MODE_ECHO        = 1 << 4,
    MODE_PRINT       = 1 << 5,
    MODE_UTF8        = 1 << 6,
};

enum cursor_movement {
    CURSOR_SAVE,
    CURSOR_LOAD
};

enum cursor_state {
    CURSOR_DEFAULT  = 0,
    CURSOR_WRAPNEXT = 1,
    CURSOR_ORIGIN   = 2
};

enum charset {
    CS_GRAPHIC0,
    CS_GRAPHIC1,
    CS_UK,
    CS_USA,
    CS_MULTI,
    CS_GER,
    CS_FIN
};

enum escape_state {
    ESC_START      = 1,
    ESC_CSI        = 2,
    ESC_STR        = 4,  /* DCS, OSC, PM, APC */
    ESC_ALTCHARSET = 8,
    ESC_STR_END    = 16, /* a final string was encountered */
    ESC_TEST       = 32, /* Enter in test mode */
    ESC_UTF8       = 64,
};

typedef struct {
    Glyph attr; /* current char attributes */
    int x;
    int y;
    char state;
} TCursor;

typedef struct {
    int mode;
    int type;
    int snap;
    /*
     * Selection variables:
     * nb – normalized coordinates of the beginning of the selection
     * ne – normalized coordinates of the end of the selection
     * ob – original coordinates of the beginning of the selection
     * oe – original coordinates of the end of the selection
     */
    struct {
        int x, y;
    } nb, ne, ob, oe;

    int alt;
} Selection;

/* Internal representation of the screen */
typedef struct {
    int row;      /* nb row */
    int col;      /* nb col */
    Line *line;   /* screen */
    Line *alt;    /* alternate screen */
    int *dirty;   /* dirtyness of lines */
    TCursor c;    /* cursor */
    int ocx;      /* old cursor col */
    int ocy;      /* old cursor row */
    int top;      /* top    scroll limit */
    int bot;      /* bottom scroll limit */
    int mode;     /* terminal mode flags */
    int esc;      /* escape state flags */
    char trantbl[4]; /* charset table translation */
    int charset;  /* current charset */
    int icharset; /* selected charset for sequence */
    int *tabs;
    Rune lastc;   /* last printed char outside of sequence, 0 if control */
} Term;

/* CSI Escape sequence structs */
/* ESC '[' [[ [<priv>] <arg> [;]] <mode> [<mode>]] */
typedef struct {
    char buf[ESC_BUF_SIZ]; /* raw string */
    size_t len;            /* raw string length */
    char priv;
    int arg[ESC_ARG_SIZ];
    int narg;              /* nb of args */
    char mode[2];
} CSIEscape;

/* STR Escape sequence structs */
/* ESC type [[ [<priv>] <arg> [;]] <mode>] ESC '\' */
typedef struct {
    char type;             /* ESC type ... */
    char *buf;             /* allocated raw string */
    size_t siz;            /* allocation size */
    size_t len;            /* raw string length */
    char *args[STR_ARG_SIZ];
    int narg;              /* nb of args */
} STREscape;

#ifdef __APPLE__
typedef struct {
    int w, h;
    int tw, th;
    int cw, ch;
    int mode;
} TWindow;
#endif

#endif /* st_types_h */
