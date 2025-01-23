//
//  main.m
//  FTerm
//
//  Created by Michael Larson on 11/29/23.
//

#import <Cocoa/Cocoa.h>
#import "st.h"

#import "sys/ioctl.h"
#import "util.h"
#import "wchar.h"
#import "pthread.h"

#import "config.def.h"
#import "macos_support.h"
#import "st_types.h"

// globals
int ttyfd;
fd_set rfd;

extern TWindow win;

//static char *opt_class = NULL;
static char **opt_cmd  = NULL;
static char *opt_embed = NULL;
static char *opt_font  = NULL;
static char *opt_io    = NULL;
static char *opt_line  = NULL;
static char *opt_name  = NULL;
static char *opt_title = NULL;

/* Globals */
static int iofd = 1;
static int cmdfd;
static pid_t pid;


void
init_run(void)
{
    char *shell;
    
    shell = getenv("SHELL");
    assert(shell);
    
    int w = win.w, h = win.h;
    macos_cresize(w, h);

    ttyfd = ttynew(opt_line, shell, opt_io, opt_cmd);
}

void
run(void)
{
    fd_set rfd;
    struct timespec seltv, *tv, now, lastblink, trigger;
    double timeout;
    
    lastblink = (struct timespec){0};
    
    FD_ZERO(&rfd);
    FD_SET(ttyfd, &rfd);

    // 10ms timeout
    timeout = 10;
    seltv.tv_sec = timeout / 1E3;
    seltv.tv_nsec = 1E6 * (timeout - 1E3 * seltv.tv_sec);
    tv = timeout >= 0 ? &seltv : NULL;

    if (pselect(ttyfd+1, &rfd, NULL, NULL, tv, NULL) < 0)
    {
        if (errno == EINTR)
            return;

        die("select failed: %s\n", strerror(errno));
    }
    
    clock_gettime(CLOCK_MONOTONIC, &now);

    if (FD_ISSET(ttyfd, &rfd))
        ttyread();

    /*
     * To reduce flicker and tearing, when new content or event
     * triggers drawing, we first wait a bit to ensure we got
     * everything, and if nothing new arrives - we draw.
     * We start with trying to wait minlatency ms. If more content
     * arrives sooner, we retry with shorter and shorter periods,
     * and eventually draw even without idle after maxlatency ms.
     * Typically this results in low latency while interacting,
     * maximum latency intervals during `cat huge.txt`, and perfect
     * sync with periodic updates from animations/key-repeats/etc.
     */
    if (FD_ISSET(ttyfd, &rfd))
    {
        timeout = (maxlatency - TIMEDIFF(now, trigger)) \
                  / maxlatency * minlatency;
        if (timeout > 0)
            return;  /* we have time, try to find idle */
    }

    /* idle detected or maxlatency exhausted -> draw */
    timeout = -1;
    if (blinktimeout && tattrset(ATTR_BLINK))
    {
        timeout = blinktimeout - TIMEDIFF(now, lastblink);
        if (timeout <= 0)
        {
            if (-timeout > blinktimeout) /* start visible */
                win.mode |= MODE_BLINK;
            
            win.mode ^= MODE_BLINK;
            tsetdirtattr(ATTR_BLINK);
            lastblink = now;
            timeout = blinktimeout;
        }
    }

    draw();
}

void initTTY(void)
{
    setlocale(LC_CTYPE, "");
    cols = MAX(cols, 1);
    rows = MAX(rows, 1);
    
    // gues for now
    win.w = 1024;
    win.h = 1280;
    win.cw = 24;
    win.ch = 24;
    win.tw = cols * win.cw;
    win.th = rows * win.ch;

    tnew(cols, rows);
    selinit();
    init_run();
}

int main(int argc, const char * argv[]) {
    
    initTTY();
    
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }

    return NSApplicationMain(argc, argv);
}
