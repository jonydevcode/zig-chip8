// This is a vertex shader. A vertex shader runs once for each vertex the CPU
// asks the GPU to draw. In this demo, main.c calls SDL_DrawGPUPrimitives with
// 6 vertices, so this shader runs 6 times per frame.
//
// The job of this shader is deliberately small: make one rectangle that covers
// the entire window, then pass texture coordinates to the fragment shader so it
// can look up CHIP-8 pixels from the uploaded framebuffer texture.
#version 450

// `layout(location = 0)` gives this output a fixed slot number. The fragment
// shader has a matching `layout(location = 0) in vec2 in_uv;`, so the GPU knows
// these two variables are connected.
//
// `out` means this value leaves the vertex shader.
//
// `vec2` is a pair of floating-point numbers. Here they are UV texture
// coordinates: U is horizontal position in the texture, V is vertical position.
layout(location = 0) out vec2 out_uv;

// These are the six clip-space positions for two triangles.
//
// GPUs normally draw triangles, not rectangles. To fill a rectangular window we
// draw two triangles:
//
//   triangle 1: bottom-left, bottom-right, top-right
//   triangle 2: bottom-left, top-right, top-left
//
// `vec2 positions[6]` means "an array of 6 vec2 values."
//
// The numbers are in clip space, the coordinate system used after the vertex
// shader:
//
//   x = -1.0 is the left edge of the output
//   x =  1.0 is the right edge of the output
//   y = -1.0 is the bottom edge of the output
//   y =  1.0 is the top edge of the output
//
// Using exactly -1.0 and 1.0 makes the triangles cover the whole render target.
vec2 positions[6] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0,  1.0)
);

// These are the matching texture coordinates for each vertex above.
//
// Texture coordinates are usually normalized: 0.0 means one edge of the texture
// and 1.0 means the opposite edge, regardless of the actual texture size.
// That is why these values are 0.0 and 1.0 even though the CHIP-8 framebuffer
// is 64 x 32 pixels.
//
// The V values look flipped compared with clip-space Y:
//
//   bottom clip-space vertices use v = 1.0
//   top clip-space vertices use v = 0.0
//
// This matches the usual CPU framebuffer layout where row 0 is the top row of
// the image. The texture data is uploaded from that top-to-bottom C array, so
// the top of the rectangle should sample v = 0.0.
vec2 uvs[6] = vec2[](
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(1.0, 0.0),
    vec2(0.0, 1.0),
    vec2(1.0, 0.0),
    vec2(0.0, 0.0)
);

void main()
{
    // `gl_VertexIndex` is built in by GLSL. It is the number of the vertex
    // currently being processed: 0, 1, 2, 3, 4, or 5 for this draw call.
    //
    // `gl_Position` is the required vertex-shader output. It tells the GPU
    // where this vertex lands on screen after clipping and rasterization.
    //
    // `vec4` has four floats: x, y, z, and w.
    //   x/y come from the table above.
    //   z = 0.0 puts this rectangle in the middle of depth range; depth testing
    //       is not used in this demo, so any ordinary value would work.
    //   w = 1.0 means these x/y/z values are already normal clip-space values.
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);

    // Pass the matching UV coordinate to the fragment shader. The GPU will
    // automatically interpolate this value across the two triangles, so every
    // output pixel gets the correct place to sample from the CHIP-8 texture.
    out_uv = uvs[gl_VertexIndex];
}
