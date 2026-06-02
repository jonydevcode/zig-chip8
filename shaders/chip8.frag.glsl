// This is a fragment shader. A fragment shader runs for each output pixel
// covered by the triangles from the vertex shader.
//
// In this demo, the vertex shader draws a fullscreen rectangle. This fragment
// shader decides the final color of every window pixel by sampling the tiny
// 64 x 32 CHIP-8 RGBA framebuffer texture.
#version 450

// This input comes from `out_uv` in fullscreen.vert.glsl.
//
// `layout(location = 0)` is the agreed slot number that connects the vertex
// shader output to this fragment shader input.
//
// `in` means this value enters the fragment shader.
//
// `vec2` is two floats: U and V texture coordinates. The GPU interpolates them
// across the triangles, so each fragment receives the coordinate for the part
// of the CHIP-8 texture it should read.
layout(location = 0) in vec2 in_uv;

// This is the final color produced by the fragment shader.
//
// `out` means the value leaves the shader and goes to the render target, which
// is the swapchain texture SDL will present in the window.
//
// `vec4` is four floats: red, green, blue, alpha. Each component usually ranges
// from 0.0 to 1.0, where 0.0 is none of that channel and 1.0 is full strength.
layout(location = 0) out vec4 out_color;

// `uniform` means this value is provided by the application, not calculated by
// the shader. Here the application binds the uploaded CHIP-8 framebuffer
// texture with SDL_BindGPUFragmentSamplers.
//
// `sampler2D` combines two ideas:
//   texture: the stored image data
//   sampler: the rules for reading it, such as nearest-neighbor filtering
//
// The C code creates the texture as SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM, so
// each sampled texel is already a complete red, green, blue, alpha color.
//
// SDL3 GPU expects fragment sampled textures/samplers in SPIR-V descriptor set
// 2. `binding = 0` means this is the first sampler in that set, matching the
// fragment shader's `.num_samplers = 1` and the bind call at slot 0 in main.c.
layout(set = 2, binding = 0) uniform sampler2D chip8_screen;

void main()
{
    // Read and output the RGBA framebuffer texture directly. The CPU-side
    // conversion step has already turned CHIP-8 off/on pixels into colors.
    out_color = texture(chip8_screen, in_uv);
}
