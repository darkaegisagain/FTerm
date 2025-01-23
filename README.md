# FTerm
Fast terminal written in Metal

Its a fun toy, I thought I could beat the standard MacOS terminal app.. unfortunately its not the draw speed thats the limiting factor its the pipe speed. Oh well.

I learned alot making this, hopefully someone learns a bit from this also.

It uses ST Term as a base which is X11 based, but I was able to convert this to work with a custom renderer (see Renderer.m). TrueType information is from stb_truetype by Sean Barrett which works great.

All the event processing was moved to Renderer.m, there wasn't a good reason to jamm in all the window controller stuff so I just put it in the renderer.

And it uses a custom vertex and fragment shader to render from this to a MTKView and its done.

Have fun hacking, just keep my name in the files I created.
