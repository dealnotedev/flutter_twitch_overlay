/*
 * OpenGL ES renderer through ANGLE on Direct3D 11 for the benchmark host.
 * Mirrors GpuRenderer from flutter_obs_source (src/flutter-renderer-gpu.cpp)
 * without OBS: frames stay on the GPU and are copied into a second D3D11
 * texture on present, like the plugin's shared frame buffers.
 */
#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <wchar.h>

#include "embedder.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Loads libEGL.dll/libGLESv2.dll from angle_dir and creates the device,
 * contexts and render target. on_present runs on the raster thread after
 * each frame is published, with the time spent in present.
 *
 * The plugin calls glFinish before copying the frame. With flush_only the
 * copy is ordered after the GL work by the shared D3D11 immediate context
 * instead, so present only submits work and never waits for the GPU. */
bool gpu_renderer_init(const wchar_t *angle_dir, uint32_t width, uint32_t height, bool flush_only,
		       void (*on_present)(double present_ms));

FlutterRendererConfig gpu_renderer_config(void);

/* Reads back the last published frame and writes it as a 32-bit BMP.
 * Call it only while no frame is being rendered. */
bool gpu_renderer_dump_bmp(const char *path);

#ifdef __cplusplus
}
#endif
