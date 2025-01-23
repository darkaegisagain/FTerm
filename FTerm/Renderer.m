/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "Renderer.h"

#import "st.h"
#import "st_types.h"
#import "macos_support.h"

extern Term term;
extern MacOS_Cursor cursor;

extern void run(void);

// Main class performing the rendering
@implementation Renderer

size_t fileSize(const char *file_name)
{
    // opening the file in read mode
    FILE* fp = fopen(file_name, "r");
  
    // checking if the file exist or not
    if (fp == NULL)
    {
        printf("File Not Found!\n");
        return -1;
    }
  
    fseek(fp, 0L, SEEK_END);
  
    // calculating the size of the file
    size_t res = ftell(fp);
  
    // closing the file
    fclose(fp);
  
    return res;
}

int readFile(const char *file_name, void *buffer, size_t len)
{
    // opening the file in read mode
    FILE* fp = fopen(file_name, "r");
  
    // checking if the file exist or not
    if (fp == NULL)
    {
        printf("File Not Found!\n");
        return -1;
    }

    fread(buffer, len, 1, fp);
    
    fclose(fp);
    
    return 0;
}


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


// in macos_support.c
extern unsigned num_default_x11_color_entries;
extern ColorEntry *default_x11_color_table;
extern void macos_loadcols(void);

char *local_strdup(char *str)
{
    size_t len;
    len = 0;
    
    while(!isalnum(*str))
    {
        str++;
    }
    
    len = strlen(str);

    char *new_str;
    new_str = (char *)malloc(len + 1);
    strncpy(new_str, str, len);
    
    // eliminate a trailing \n
    if (str[len - 1] == '\n')
        new_str[len - 1] = 0;
    else
        new_str[len] = 0;
    
    return new_str;
}

- (void)loadX11Colors
{
    NSBundle *mainBundle;
    
    // Get the main bundle for the app.
    mainBundle = [NSBundle mainBundle];
    
    NSString* rgbPath = [mainBundle pathForResource:@"rgb" ofType:@"txt"];
    assert(rgbPath);
    
    FILE *fp;
    fp = fopen([rgbPath cStringUsingEncoding: NSUTF8StringEncoding], "r");
    assert(fp);
    
    int num_entries;
    num_entries = 0;
    while(!feof(fp))
    {
        XRenderColor color;
        char name[128];
        
        fscanf(fp, "%hd %hd %hd", &color.red, &color.green, &color.blue);
        fgets(name, 128, fp);
        
        num_entries++;
    }
    
    fseek(fp, 0, SEEK_SET);
    
    num_default_x11_color_entries = num_entries;
    default_x11_color_table = (ColorEntry *)malloc(sizeof(ColorEntry) * num_default_x11_color_entries);

    for(int i=0; i<num_default_x11_color_entries; i++)
    {
        char name[128];
        
        name[0] = 0;
        fscanf(fp, "%hd %hd %hd", &default_x11_color_table[i].color.red, &default_x11_color_table[i].color.green, &default_x11_color_table[i].color.blue);

        fgets(name, 128, fp);

        // x11 defines it as a short
        default_x11_color_table[i].color.red = default_x11_color_table[i].color.red << 8;
        default_x11_color_table[i].color.green = default_x11_color_table[i].color.green << 8;
        default_x11_color_table[i].color.blue = default_x11_color_table[i].color.blue << 8;

        default_x11_color_table[i].color.alpha = 0xffff;
        default_x11_color_table[i].name = local_strdup(name);
    }
    
    fclose(fp);
}

- (void)setColor:(TTFontPaletteEntry *)entry R:(float)r G:(float)g B:(float)b A:(float)a
{
    entry->r = r;
    entry->g = g;
    entry->b = b;
    entry->a = a;
}

- (void)setColor:(TTFontPaletteEntry *)entry R:(float)r G:(float)g B:(float)b
{
    entry->r = r;
    entry->g = g;
    entry->b = b;
    entry->a = 1.0;
}

- (void)setPaletteEntry:(int)index R:(float)r G:(float)g B:(float)b
{
    [self setColor:&_ftBuffer->palette[index]  R:g G:g B:b];
}

- (void)clearPalette
{
    // 0 is black
    [self setPaletteEntry:0 R:0 G:0 B:0];
    
    // 1 is white
    [self setPaletteEntry:1 R:1 G:1 B:1];
    
    // debug clear rest to black
    for(int i=2; i<256; i++)
    {
        [self setPaletteEntry:1 R:0 G:0 B:0];
    }
    
    // set current color index to 1
    _ftBuffer->current_color_index = 1;
}

- (void)setCurrentColor:(int) index
{
    _ftBuffer->current_color_index = index;
}

- (void)setCharRow:(int)row col:(int)col char:(unsigned char)c
{
    int index;
    index = _ftBuffer->cols * row + col;
    
    _ftBuffer->character_buffer[index].u = c;
}

- (void)clearScreen
{
    for(int row=0; row<_ftBuffer->rows; row++)
    {
        for(int col=0; col<_ftBuffer->cols; col++)
        {
            [self setCharRow:row col:col char: 0];
        }
    }
}

- (bool) createFont: (char *) fontname size:(int)size
{
    if (_ftBuffer->num_fonts > MAX_FONTS)
        return false;

    FILE *fp;
    char path[128];
    char *font_search_paths[] = {
        "/System/Library/Fonts",
        "/System/Library/Fonts/Supplemental",
        "/Library/Fonts",
        "~/Library/Fonts",
        NULL
    };
    char *font_exts[] = {
        "ttf", "otf", "ttc", NULL
    };

    // search all paths and ext for font
    fp = NULL;
    for(int i=0; (fp == NULL) && font_search_paths[i]; i++)
    {
        for(int ext=0; (fp == NULL) && font_exts[ext]; ext++)
        {
            bzero(path, 128);
            snprintf(path, 128, "%s/%s.%s", font_search_paths[i], fontname, font_exts[ext]);
            fp = fopen(path, "r");
        }
    }
    
    if (fp == NULL)
    {
        printf("Unable to open font: %s\n", fontname);
        return false;
    }
    
    size_t len = fileSize(path);
    assert(len);
    
    unsigned char *fileBuffer = (unsigned char *)malloc(len);
    
    int res;
    res = readFile(path, fileBuffer, len);

    // create a new font in the font table
    int font_index;
    font_index = _ftBuffer->num_fonts;

    // stb truetype stuff
    stbtt_fontinfo font;
    unsigned char *bitmap;

    // up size to reflet that we are on a retina system
    size *= 2.0;
    
    // figure out the maxium font size, init to size
    int max_width, max_height;
    max_width = 0;
    max_height = 0;
    for(int i=0; i<256; i++)
    {
        int width, height;

        stbtt_InitFont(&font, fileBuffer, stbtt_GetFontOffsetForIndex(fileBuffer, 0));
        bitmap = stbtt_GetCodepointBitmap(&font, 0, stbtt_ScaleForPixelHeight(&font, size), i, &width, &height, 0, 0);

        max_width = MAX(width, max_width);
        max_height = MAX(height, max_height);
        
        stbtt_FreeBitmap(bitmap, NULL);
    }

    // create a 16x16 glyph array to put font texture in
    max_width *= 16;
    max_height *= 16;
    unsigned char *temp_bitmap;
    temp_bitmap = (unsigned char *)malloc(max_width * max_height);
    
    // stbtt_BakeFontBitmap returns the largest y value filled in for bitmap generation
    // this is our new max_height
    // fill in the local copy of _fontTable cdata
    stbtt_BakeFontBitmap(fileBuffer, 0, size, temp_bitmap, max_width, max_height, 0, 255, _fontTable[font_index].cdata); // no guarantee this fits!
        
    // create a metal descriptor for the font texture
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:max_width height:max_height mipmapped:false];
    
    // fill in font table for cpu
    _fontTable[font_index].font_name = strdup(fontname);
    _fontTable[font_index].font_height = size;
    
    // create a metal texture from descriptor
    _fontTextures[font_index] = [_device newTextureWithDescriptor: desc];
    
    // define region size
    MTLRegion region = {
        { 0, 0, 0 },               // MTLOrigin
        {max_width, max_height, 1} // MTLSize
    };
    
    // copy bitmap to texture
    [_fontTextures[font_index] replaceRegion:region
                mipmapLevel:0
                  withBytes:temp_bitmap
                bytesPerRow:max_width];

    // true type font information
    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&font, &ascent, &descent, &lineGap);
    float scale;
    scale = stbtt_ScaleForPixelHeight(&font, size);

    // scale to pixels
    ascent *= scale;
    descent *= scale;
    lineGap *= scale;
    
    // fill in data needed by gpu
    _ftBuffer->font_info[font_index].size = size;
    _ftBuffer->font_info[font_index].ascent = ascent;
    _ftBuffer->font_info[font_index].descent = descent;
    _ftBuffer->font_info[font_index].len = 256;
    _ftBuffer->font_info[font_index].offset = 0;
    _ftBuffer->font_info[font_index].lineGap = lineGap;
    _ftBuffer->font_info[font_index].sampler_index = font_index;
    _ftBuffer->font_info[font_index].tex_width = max_width;
    _ftBuffer->font_info[font_index].tex_height = max_height;

    // get a baked quad for each glyph for tex coords used by shader
    for(int i=0; i<256; i++)
    {
        int width, height;

        stbtt_InitFont(&font, fileBuffer, stbtt_GetFontOffsetForIndex(fileBuffer, 0));
        bitmap = stbtt_GetCodepointBitmap(&font, 0, stbtt_ScaleForPixelHeight(&font, size), i, &width, &height, 0, 0);

        stbtt_FreeBitmap(bitmap, NULL);
        
        float xpos, ypos;
        stbtt_aligned_quad q;
        xpos = 0;
        ypos = 0;
        stbtt_GetBakedQuad(_fontTable[font_index].cdata, max_width, max_height, i, &xpos, &ypos, &q, 1); //1=opengl & d3d10+,0=d3d9
    }
    
    // update num fonts
    _ftBuffer->num_fonts++;

    // debug code
    _ftBuffer->current_font = font_index;
    
    free(temp_bitmap);
    
    // done!
    return true;
}

- (void)initScreen
{
    // create default font
    [self createFont:"Andale Mono" size: 12];
    
    // set the current font index
    _currentFontIndex = 0;
    
    int font_size;
    font_size = _ftBuffer->font_info[_ftBuffer->current_font].size;

    _ftBuffer->max_row = MAX_ROW;
    _ftBuffer->max_col = MAX_COL;
    
    _ftBuffer->rows = _bufferSize.height / font_size;
    _ftBuffer->cols = _bufferSize.width / font_size;

    _ftBuffer->screen_width = _bufferSize.width;
    _ftBuffer->screen_height = _bufferSize.height;

    [self clearScreen];
    [self clearPalette];
}

- (void) initEventQueue
{
    _numEvents = 0;
    _eventQueueSize = 32;
    _eventQueue = (STEvent *)malloc(sizeof(STEvent) * _eventQueueSize);
}

- (void) resizeEventQueue
{
    STEvent *temp = (STEvent *)malloc(sizeof(STEvent) * _eventQueueSize * 2);
    memcpy(temp, _eventQueue, _eventQueueSize);
    free(_eventQueue);
    _eventQueue = temp;
    _eventQueueSize *= 2;
}

- (NSEvent *) mouseEventHandler: (NSEvent *)event
{
    //CGPoint location = [NSEvent mouseLocation];

    //printf("Local Mouse X,Y: %f,%f\n", location.x, location.y);

    return event;
}

- (void) pasteEvent: (NSEvent *)event
{
    NSPasteboard *generalPasteboard;
    
    generalPasteboard = [NSPasteboard generalPasteboard];
    
    NSString *string = [generalPasteboard stringForType: NSPasteboardTypeString];
    
    if (string == NULL)
        return;
        
    const char *str;
    str = [string UTF8String];
    
    size_t len;
    len = strlen(str);
    
    if (len)
    {
        ttywrite(str, len, 1);
    }
}

- (NSEvent *) keyEventHandler: (NSEvent *)event
{
    STEvent *current_event;
    
    // some events need to be processed by the framework
    // figure these out and return them
    
    // cmd q  (quit)
    if ([event modifierFlags] & NSEventModifierFlagCommand)
    {
        int keyCode;
        keyCode = [event keyCode];
        
        // total hack.. figured out keyCode for cmd-q
        if (keyCode == 12)
            return event;
    }
    
    current_event = &_eventQueue[_numEvents++];
    
    if (_numEvents > _eventQueueSize)
        [self resizeEventQueue];
    
    NSString *characters = [event characters];

    switch([event type])
    {
        case NSEventTypeKeyDown:
            if ([event modifierFlags] & NSEventModifierFlagCommand)
            {
                printf("keycode: %d\n", [event keyCode]);
                
                switch([event keyCode])
                {
                    case 9:
                        [self pasteEvent:event];
                        break;
                        
                    default:
                        break;
                }
            }
            else
            {
                current_event->modifier = (unsigned char)([event modifierFlags] >> 16);
                current_event->type = keyDown;
                if (characters != NULL)
                    current_event->key.buf = strdup([characters UTF8String]);
                else
                    current_event->key.buf = NULL;
                break;
            }
            break;
            
        case NSEventTypeKeyUp:
            _numEvents--;
            return event;
            
        default:
            assert(0);
    }
    
    current_event->key.code = [event keyCode];

    return NULL;
}

- (NSEvent *) windowEventHandler: (NSEvent *)event
{
    
    return event;
}

- (void) initEventHandlers
{
    unsigned mask;
    mask =  NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp |
            NSEventMaskRightMouseDown | NSEventMaskRightMouseUp |
            NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged |
            NSEventMaskRightMouseDragged | NSEventTypeRightMouseDragged;

    [NSEvent addLocalMonitorForEventsMatchingMask: mask handler: ^(NSEvent *event) {
        return [self mouseEventHandler: event];
     }];

//    mask = NSEventMaskKeyDown | NSEventMaskKeyUp;
    mask = NSEventMaskKeyDown;

    [NSEvent addLocalMonitorForEventsMatchingMask: mask handler: ^(NSEvent *event) {
        return [self keyEventHandler: event];
     }];

    mask = NSEventMaskMouseEntered | NSEventMaskMouseExited;

    [NSEvent addLocalMonitorForEventsMatchingMask: mask handler: ^(NSEvent *event) {
        return [self windowEventHandler: event];
     }];
}

void STProcessKey(STEvent *event)
{
//    XKeyEvent *e = &ev->xkey;
    //    KeySym ksym = NoSymbol;
    char buf[64];
    int len;
    Rune c;
    //Status status;
    //Shortcut *bp;

    //if (IS_SET(MODE_KBDLOCK))
    //    return;

    if (event->key.buf)
    {
        len = (int)strlen(event->key.buf);
        if (len > 64)
        {
            assert(0);
        }
        
        strncpy(buf, event->key.buf, 64);
        
        free(event->key.buf);
    }
    else
    {
        len = 1;
        buf[0] = event->key.code;
        assert((event->key.code & 0xff00) == 0);
    }
    
    /* 1. shortcuts */
#if 0
    for (bp = shortcuts; bp < shortcuts + LEN(shortcuts); bp++)
    {
        if (ksym == bp->keysym && match(bp->mod, e->state))
        {
            bp->func(&(bp->arg));
            return;
        }
    }
#endif
    
    /* 3. composed string from input method */
    if (len == 0)
        return;
    
    if (len == 1 && (event->modifier & EventModifierFlagOption))
    {
        if (IS_SET(MODE_8BIT))
        {
            if (*buf < 0177)
            {
                c = *buf | 0x80;
                len = (int)utf8encode(c, buf);
            }
        }
        else
        {
            buf[1] = buf[0];
            buf[0] = '\033';
            len = 2;
        }
    }
    
    ttywrite(buf, len, 1);
}

- (void) processEventQueue
{
    for(int i=0;i<_numEvents; i++)
    {
        switch(_eventQueue[i].type)
        {
            case keyDown:
                STProcessKey(&_eventQueue[i]);
                break;
                
            case mouseMove:
            case mouseEnter:
            case mouseLeave:
                break;
                
            default:
                assert(0);
                break;
        }
    }
    
    _numEvents = 0;
}

- (nonnull instancetype)init:(nonnull MTKView *)mtkView
{
    self = [super init];
    
    return self;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = mtkView.device;
        assert(_device);

        mtkView.preferredFramesPerSecond = 120;
        
        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"termVertexShader"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"termFragmentShader"];
        assert(vertexFunction);
        assert(fragmentFunction);

        // Configure a pipeline descriptor that is used to create a pipeline state.
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"FTerm Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
        vertexDescriptor.layouts[0].stride = sizeof(FTermVertex);
        vertexDescriptor.layouts[0].stepRate = 1;
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
        
        vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].bufferIndex = 0;

        vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
        vertexDescriptor.attributes[1].offset = offsetof(FTermVertex, st);
        vertexDescriptor.attributes[1].bufferIndex = 0;

        pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
                
        // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
        //  If the Metal API validation is enabled, you can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode.)
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        assert(_commandQueue);

        // create a null tex buffer
        // create a metal descriptor for the font texture
        MTLTextureDescriptor *desc = [[MTLTextureDescriptor alloc] init];

        // generic texture
        desc.pixelFormat = MTLPixelFormatRGBA8Unorm;
        desc.width = 512;
        desc.height = 512;
        
        // create a metal texture from descriptor
        id<MTLTexture> _nullTexId;
        _nullTexId = [_device newTextureWithDescriptor: desc];
        assert(_nullTexId);
        
        // create the vertex buffer
        size_t len;
        len = 2 * (sizeof(FTermVertex) * MAX_ROW * MAX_COL * 4);
        _gpuVertexBuffer = [_device newBufferWithLength: len options: MTLResourceStorageModeManaged];
        assert(_gpuVertexBuffer);

        // grab a pointer to the vertex buffer
        _vertexBuffer = [_gpuVertexBuffer contents];
        assert(_vertexBuffer);
        
        // create the element buffer
        len = 2 * (sizeof(unsigned int) * MAX_ROW * MAX_COL * 4);
        _gpuElementBuffer = [_device newBufferWithLength: len options: MTLResourceStorageModeManaged];
        assert(_gpuElementBuffer);

        // grab a pointer to the vertex buffer
        _elementBuffer = [_gpuElementBuffer contents];
        assert(_vertexBuffer);
        
        // create the display buffer for characters and font information
        _gpuFTBuffer = [_device newBufferWithLength:sizeof(FTermBuffer) options: MTLResourceStorageModeManaged];
        assert(_gpuFTBuffer);
        
        // grab a pointer to the gpu buffer
        _ftBuffer = [_gpuFTBuffer contents];
        assert(_ftBuffer);
        
        // init font table
        _maxFonts = MAX_FONTS;
        _fontTable = (FontTableEntry *)malloc(_maxFonts * sizeof(FontTableEntry));
        
        // set the initial buffer size
        NSRect frame;
        frame = [mtkView frame];
        _bufferSize = frame.size;
        
        // init screen after
        [self initScreen];
        
        // init event queue
        [self initEventQueue];
        
        // init event hanlders
        [self initEventHandlers];
        
        // load default x11 colors from rgb.txt
        [self loadX11Colors];
        
        // load colors for st
        macos_loadcols();
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    _bufferSize = size;
    
    // Save the size of the drawable to pass to the vertex shader.
    _ftBuffer->viewportSize.x = size.width;
    _ftBuffer->viewportSize.y = size.height;
    
    int font_size;
    font_size = _ftBuffer->font_info[_ftBuffer->current_font].size;
    
    _ftBuffer->screen_width = size.width;
    _ftBuffer->screen_height = size.height;
    
    _ftBuffer->rows = size.height / font_size;
    _ftBuffer->cols = size.width / font_size;
    
    [_gpuFTBuffer didModifyRange: NSMakeRange(0, sizeof(FTermBuffer))];
    
    macos_cresize(size.width, size.height);
    
    [self clearScreen];
}

- (void)processTTYInput
{
    Glyph *gp;
    int n_rows, n_cols;
    
    run();
    
    n_rows = _ftBuffer->rows = term.row;
    n_cols = _ftBuffer->cols = term.col;

    // copy the glyphs to the gpu buffer
    for(int row=0; row<n_rows; row++)
    {
        for(int col=0; col<n_cols; col++)
        {
            gp = &term.line[row][col];
            _ftBuffer->character_buffer[n_cols * row + col].u = gp->u;
            _ftBuffer->character_buffer[n_cols * row + col].fg = gp->fg;
            _ftBuffer->character_buffer[n_cols * row + col].bg = gp->bg;
        }
    }
    
    // process as quads
    int current_font;
    current_font = _ftBuffer->current_font;

    stbtt_bakedchar *cdata;
    cdata = (stbtt_bakedchar *)_fontTable[current_font].cdata;
    assert(cdata);
    
    FTermVertex *verts;
    verts = _vertexBuffer;
    
    unsigned int *indices;
    indices = _elementBuffer;
    
    unsigned int vert_count;
    vert_count = 0;
    
    // compile number of quads to be drawn by metal
    _compiledGlyphQuads = 0;

    int tex_width, tex_height;
    tex_width = _ftBuffer->font_info[current_font].tex_width;
    tex_height = _ftBuffer->font_info[current_font].tex_height;

    static int once = 0;
    for(int row=0; row<n_rows; row++)
    {
        float xpos, ypos;
        
        xpos = _ftBuffer->font_info[current_font].size;
        ypos = (row + 1) * _ftBuffer->font_info[current_font].size;

        for(int col=0; col<n_cols; col++)
        {
            gp = &term.line[row][col];
            
            if (gp->u >= 32 && gp->u < 128)
            {
                stbtt_aligned_quad q;
                stbtt_GetBakedQuad(cdata, tex_width, tex_height,
                                   gp->u, &xpos, &ypos, &q, 1); //1=opengl & d3d10+,0=d3d9

                // stbtt_GetBakedQuad generates degenerate triangles for glyphs that don't render
                // so skip them
                if (q.y0 != q.y1)
                {
                    verts[0].position.x = q.x0;
                    verts[0].position.y = q.y0;
                    verts[0].st.x = q.s0;
                    verts[0].st.y = q.t0;
                    
                    verts[1].position.x = q.x1;
                    verts[1].position.y = q.y0;
                    verts[1].st.x = q.s1;
                    verts[1].st.y = q.t0;
                    
                    verts[2].position.x = q.x1;
                    verts[2].position.y = q.y1;
                    verts[2].st.x = q.s1;
                    verts[2].st.y = q.t1;
                    
                    verts[3].position.x = q.x0;
                    verts[3].position.y = q.y1;
                    verts[3].st.x = q.s0;
                    verts[3].st.y = q.t1;
                    
                    // quad verts
                    // 0 --- 1
                    // |     |
                    // |     |
                    // |     |
                    // 3 --- 2
                    
                    // first triangle (0, 1, 3) clockwise
                    indices[0] = vert_count + 0;
                    indices[1] = vert_count + 1;
                    indices[2] = vert_count + 3;
                    
                    // second triangle (1, 2, 3) clockwise
                    indices[3] = vert_count + 1;
                    indices[4] = vert_count + 2;
                    indices[5] = vert_count + 3;
                    
                    // move pointers forward
                    verts += 4;
                    indices += 6;
                    
                    // move vert count forward
                    vert_count += 4;
                    
                    // update compiled glyphs to be drawn
                    _compiledGlyphQuads++;
                }
            }
        }
    }
    
    once = 1;
}

extern int macos_palette_dirty;
extern int palette_size;
extern void getPaletteEntryAsFloats(int index, float *color);

- (void)updatePalette
{
    if (macos_palette_dirty)
    {
        for(int i=0; i<palette_size; i++)
        {
            float rgba[4];
            
            getPaletteEntryAsFloats(i, rgba);
            
            _ftBuffer->palette[i].r = rgba[0];
            _ftBuffer->palette[i].g = rgba[1];
            _ftBuffer->palette[i].b = rgba[2];
            _ftBuffer->palette[i].a = rgba[3];
            
            if (rgba[3] > 0.0)
            {
                //printf("%d: %f, %f, %f, %f\n", i, rgba[0], rgba[1], rgba[2], rgba[3]);
            }
        }
        
        macos_palette_dirty = 0;
    }
}

// over in macos_support
extern MacOS_Cursor macos_cursor;

- (void)updateCursor
{
    // copy macos cursor Glyph to Glyph used by shader
    _ftBuffer->cursor.g.mode = macos_cursor.g.mode;
    _ftBuffer->cursor.g.u = macos_cursor.g.u;
    _ftBuffer->cursor.g.fg = macos_cursor.g.fg;
    _ftBuffer->cursor.g.bg = macos_cursor.g.bg;
    
    _ftBuffer->cursor.cx = macos_cursor.cx;
    _ftBuffer->cursor.cy = macos_cursor.cy;
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    // process event queue
    [self processEventQueue];
    
    // process tty input
    [self processTTYInput];
    
    // update palette
    [self updatePalette];
    
    // update cursor info
    [self updateCursor];
        
    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"FTermCommand";
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    
    if(renderPassDescriptor != nil)
    {
        CAMetalLayer *metalLayer = (CAMetalLayer *)[view layer];
        id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0,0.0,0.0,1.0);
        
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"FTermRenderEncoder";
        
        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _ftBuffer->viewportSize.x, _ftBuffer->viewportSize.y, -1.0, 1.0 }];
        
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        // Pass in the parameter data.
        [renderEncoder setVertexBuffer:_gpuVertexBuffer
                                offset:0
                               atIndex:FTermVertexInputIndexVertices];
        
        [renderEncoder setVertexBuffer:_gpuFTBuffer
                                offset:0
                               atIndex:FTermVertexInputIndexUniforms];
        
        // fragment uses same buffer as vertex
        [renderEncoder setFragmentBuffer:_gpuFTBuffer
                                  offset:0
                                 atIndex:FTermFragmentInputIndexUniforms];
        
        // pass in the texures
        for(int i=0; i<_ftBuffer->num_fonts; i++)
        {
            [renderEncoder setFragmentTexture:_fontTextures[i]
                                      atIndex:i];
        }
        
        // upload screen buffer information
        [_gpuFTBuffer didModifyRange: NSMakeRange(0, sizeof(FTermBuffer))];
        
        // if there are quads to render..
        if (_compiledGlyphQuads > 0)
        {
            unsigned vertex_count;
            vertex_count = _compiledGlyphQuads * 4;
            
            unsigned index_count;
            index_count = _compiledGlyphQuads * 6;
            
            // upload updated vertex buffer vertex_count
            [_gpuVertexBuffer didModifyRange: NSMakeRange(0, sizeof(FTermVertex) * vertex_count)];
            
            // upload updated element buffer index_count
            [_gpuElementBuffer didModifyRange: NSMakeRange(0, sizeof(unsigned int) * index_count)];
            
            // Draw triangles
            [renderEncoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle indexCount: index_count indexType: MTLIndexTypeUInt32 indexBuffer: _gpuElementBuffer indexBufferOffset: 0];
        }
        
        
        [renderEncoder endEncoding];
        
        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:drawable];
    }
    
    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
    
    // update frame count
    _frameNumber++;
}

@end
