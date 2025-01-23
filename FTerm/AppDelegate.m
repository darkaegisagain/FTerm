//
//  AppDelegate.m
//  FTerm
//
//  Created by Michael Larson on 11/29/23.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSApplication *app;
    
    app = [NSApplication sharedApplication];
    
    NSRect frame = NSMakeRect(64, 64, 1024, 1280);
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
    NSWindowStyleMaskMiniaturizable |
    NSWindowStyleMaskClosable |
    NSWindowStyleMaskResizable;
    
    _window  = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:styleMask
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];

    [_window setTitle: @"FTerm"];
    [_window makeKeyAndOrderFront:NSApp];
    [_window setDelegate: self];
    
    frame = [_window contentRectForFrameRect: frame];

    _terminalView = [[MTKView alloc] initWithFrame: frame];
    
    _terminalView.device = MTLCreateSystemDefaultDevice();

    if(!_terminalView.device)
    {
        NSLog(@"Metal is not supported on this device");
        _window.contentView = [[NSView alloc] initWithFrame: frame];
        return;
    }
    
    _renderer = [[Renderer alloc] initWithMetalKitView: _terminalView];

    [_renderer mtkView:_terminalView drawableSizeWillChange: _terminalView.bounds.size];

    _terminalView.delegate = _renderer;

    if ([_terminalView wantsLayer])
    {
        CALayer *layer;
        
        layer = [_terminalView layer];
        
        layer.backgroundColor = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 1.0);
    }
    
    _window.contentView = _terminalView;

    frame = [_window frame];
    frame.size = NSMakeSize(1024, 1280);
    
    [_window setFrame: frame display: NO animate: NO];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
