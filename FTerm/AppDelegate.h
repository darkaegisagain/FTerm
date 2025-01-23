//
//  AppDelegate.h
//  FTerm
//
//  Created by Michael Larson on 11/29/23.
//

@import Cocoa;
@import MetalKit;
@import QuartzCore;
#import "Renderer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
{
    NSWindow *_window;
    MTKView *_terminalView;
    Renderer *_renderer;
}

@end
