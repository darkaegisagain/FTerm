# FTerm
Fast terminal written in Metal

Its a fun toy, I thought I could beat the standard MacOS terminal app.. unfortunately its not the draw speed thats the limiting factor its the pipe speed. Oh well.

I learned alot making this, hopefully someone learns a bit from this also.

It uses ST Term as a base which is X11 based, but I was able to convert this to work with a custom renderer (see Renderer.m). TrueType information is from stb_truetype by Sean Barrett which works great.

It uses a custom shader to render from this to a MTKView and its done.

Have fun
