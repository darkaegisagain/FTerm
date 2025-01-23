/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for a platform independent renderer class, which performs Metal setup and per frame rendering.
*/

@import MetalKit;
@import QuartzCore;

#import <pthread/pthread.h>

// Header shared between C code here, which executes Metal API commands, and .metal files, which
// uses these types as inputs to the shaders.
#import "ShaderTypes.h"

// import true type defs
#import "stb_truetype.h"

typedef struct {
    char * _Nullable font_name;
    int font_height;
    int tex_width, tex_height;
    stbtt_bakedchar cdata[256];
} FontTableEntry;

enum EvenType {
    keyDown,
    mouseLeftBuffonDown,
    mouseRightButtonDown,
    mouseMove,
    mouseEnter,
    mouseLeave
};

enum EventKeyModifier {
    EventModifierFlagCapsLock           = 1 << 0, // Set if Caps Lock key is pressed.
    EventModifierFlagShift              = 1 << 1, // Set if Shift key is pressed.
    EventModifierFlagControl            = 1 << 2, // Set if Control key is pressed.
    EventModifierFlagOption             = 1 << 3, // Set if Option or Alternate key is pressed.
    EventModifierFlagCommand            = 1 << 4, // Set if Command key is pressed.
    EventModifierFlagNumericPad         = 1 << 5, // Set if any key in the numeric keypad is pressed.
    EventModifierFlagHelp               = 1 << 6, // Set if the Help key is pressed.
    EventModifierFlagFunction           = 1 << 7, // Set if any function key is pressed.
};

typedef struct {
    enum EvenType type;
    float x, y;
    unsigned char modifier;
    
    union {
        struct {
            unsigned short code;
            char * _Nullable buf;
        } key;
        struct {
            bool dragged;
            unsigned mouse_button;
        } mouse;
    };
} STEvent;

@interface Renderer : NSObject<MTKViewDelegate>
{
    id<MTLDevice> _device;
    
    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;
    
    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;
    
    CGSize _bufferSize;
    CGSize _fontSize;
    
    // buffer to carry vertex data to GPU
    id<MTLBuffer> _gpuVertexBuffer;
    
    // buffer to carry index data to GPU
    id<MTLBuffer> _gpuElementBuffer;
    
    // buffer to carry data to GPU
    id<MTLBuffer> _gpuFTBuffer;
    
    // null tex
    id<MTLTexture> _nullTexId;

    // font textures
    id<MTLTexture> _fontTextures[MAX_FONTS];
    
    // local pointer to GPU vertex buffer
    FTermVertex *_vertexBuffer;
    
    // local pointer to GPU vertex buffer
    unsigned int *_elementBuffer;
    
    // local pointer to GPU buffer
    FTermBuffer *_ftBuffer;
    
    // compiled quads that need to be drawn using metal
    int _compiledGlyphQuads;
    
    // local information to index fonts from table
    int _maxFonts;
    FontTableEntry *_fontTable;
    
    int _currentFontIndex;
    
    // debug
    int _frameNumber;
    int _framesPerSecond;

    // event queue
    unsigned _numEvents;
    unsigned _eventQueueSize;
    STEvent *_eventQueue;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
@end

