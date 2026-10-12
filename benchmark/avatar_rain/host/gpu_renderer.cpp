/*
 * See gpu_renderer.h. The structure follows GpuRenderer in
 * flutter_obs_source so the engine sees the same OpenGL configuration.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d11_4.h>
#include <wrl/client.h>

#include <cstdio>
#include <string>

#include "gpu_renderer.h"

#pragma comment(lib, "d3d11.lib")

using Microsoft::WRL::ComPtr;

namespace {

/* Minimal EGL declarations: the ANGLE headers are not shipped with the SDK. */
using EGLDisplay = void *;
using EGLConfig = void *;
using EGLContext = void *;
using EGLSurface = void *;
using EGLDeviceEXT = void *;
using EGLClientBuffer = void *;
using EGLint = int32_t;
using EGLAttrib = intptr_t;
using EGLBoolean = unsigned int;
using EGLenum = unsigned int;

constexpr EGLint EGL_ALPHA_SIZE = 0x3021;
constexpr EGLint EGL_BLUE_SIZE = 0x3022;
constexpr EGLint EGL_GREEN_SIZE = 0x3023;
constexpr EGLint EGL_RED_SIZE = 0x3024;
constexpr EGLint EGL_DEPTH_SIZE = 0x3025;
constexpr EGLint EGL_STENCIL_SIZE = 0x3026;
constexpr EGLint EGL_SURFACE_TYPE = 0x3033;
constexpr EGLint EGL_NONE = 0x3038;
constexpr EGLint EGL_RENDERABLE_TYPE = 0x3040;
constexpr EGLint EGL_HEIGHT = 0x3056;
constexpr EGLint EGL_WIDTH = 0x3057;
constexpr EGLint EGL_CONTEXT_CLIENT_VERSION = 0x3098;
constexpr EGLint EGL_PBUFFER_BIT = 0x0001;
constexpr EGLint EGL_OPENGL_ES2_BIT = 0x0004;
constexpr EGLenum EGL_PLATFORM_DEVICE_EXT = 0x313F;
constexpr EGLint EGL_D3D11_DEVICE_ANGLE = 0x33A1;
constexpr EGLenum EGL_D3D_TEXTURE_ANGLE = 0x33A3;

using PFN_GetProcAddress = void *(__stdcall *)(const char *);
using PFN_Initialize = EGLBoolean(__stdcall *)(EGLDisplay, EGLint *, EGLint *);
using PFN_ChooseConfig = EGLBoolean(__stdcall *)(EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *);
using PFN_CreateContext = EGLContext(__stdcall *)(EGLDisplay, EGLConfig, EGLContext, const EGLint *);
using PFN_CreatePbufferSurface = EGLSurface(__stdcall *)(EGLDisplay, EGLConfig, const EGLint *);
using PFN_CreatePbufferFromClientBuffer = EGLSurface(__stdcall *)(EGLDisplay, EGLenum, EGLClientBuffer, EGLConfig,
								  const EGLint *);
using PFN_MakeCurrent = EGLBoolean(__stdcall *)(EGLDisplay, EGLSurface, EGLSurface, EGLContext);
using PFN_GetError = EGLint(__stdcall *)();
using PFN_CreateDeviceANGLE = EGLDeviceEXT(__stdcall *)(EGLint, void *, const EGLAttrib *);
using PFN_GetPlatformDisplayEXT = EGLDisplay(__stdcall *)(EGLenum, void *, const EGLint *);
using PFN_Finish = void(__stdcall *)();
using PFN_Flush = void(__stdcall *)();

PFN_GetProcAddress egl_get_proc_address;
PFN_Initialize egl_initialize;
PFN_ChooseConfig egl_choose_config;
PFN_CreateContext egl_create_context;
PFN_CreatePbufferSurface egl_create_pbuffer_surface;
PFN_CreatePbufferFromClientBuffer egl_create_pbuffer_from_client_buffer;
PFN_MakeCurrent egl_make_current;
PFN_GetError egl_get_error;
PFN_CreateDeviceANGLE egl_create_device_angle;
PFN_GetPlatformDisplayEXT egl_get_platform_display;
PFN_Finish gl_finish;
PFN_Flush gl_flush;
bool flush_only;

ComPtr<ID3D11Device> device;
ComPtr<ID3D11DeviceContext> device_context;
ComPtr<ID3D11Texture2D> render_target;
ComPtr<ID3D11Texture2D> published_frame;
EGLDisplay display;
EGLConfig config;
EGLContext render_context;
EGLContext resource_context;
EGLSurface surface;
EGLSurface resource_surface;
void (*present_listener)(double);
LARGE_INTEGER qpc_frequency;

bool fail(const char *operation)
{
	fprintf(stderr, "gpu: %s failed (EGL error 0x%x, Windows error %lu)\n", operation,
		egl_get_error ? egl_get_error() : 0, GetLastError());
	return false;
}

template <typename T> bool load(HMODULE module, T &target, const char *name)
{
	target = reinterpret_cast<T>(GetProcAddress(module, name));
	return target != nullptr || fail(name);
}

template <typename T> bool load_extension(T &target, const char *name)
{
	target = reinterpret_cast<T>(egl_get_proc_address(name));
	return target != nullptr || fail(name);
}

ComPtr<ID3D11Texture2D> create_texture(uint32_t width, uint32_t height)
{
	D3D11_TEXTURE2D_DESC desc = {};
	desc.Width = width;
	desc.Height = height;
	desc.MipLevels = desc.ArraySize = desc.SampleDesc.Count = 1;
	desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	desc.Usage = D3D11_USAGE_DEFAULT;
	desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
	ComPtr<ID3D11Texture2D> texture;
	device->CreateTexture2D(&desc, nullptr, &texture);
	return texture;
}

double now_ms()
{
	LARGE_INTEGER t;
	QueryPerformanceCounter(&t);
	return double(t.QuadPart) * 1000.0 / double(qpc_frequency.QuadPart);
}

bool make_current(void *)
{
	return egl_make_current(display, surface, surface, render_context) != 0;
}

bool clear_current(void *)
{
	return egl_make_current(display, nullptr, nullptr, nullptr) != 0;
}

bool make_resource_current(void *)
{
	return egl_make_current(display, resource_surface, resource_surface, resource_context) != 0;
}

void *resolve(void *, const char *name)
{
	return egl_get_proc_address(name);
}

uint32_t framebuffer(void *, const FlutterFrameInfo *)
{
	return 0; // The imported pbuffer is the default framebuffer.
}

bool present(void *data)
{
	const double begin = now_ms();
	/* Same publication as the plugin: finish GL work, then copy the frame
	 * into a texture another device could open. No CPU readback. */
	if (flush_only)
		gl_flush();
	else
		gl_finish();
	if (!clear_current(data))
		return false;
	device_context->CopyResource(published_frame.Get(), render_target.Get());
	device_context->Flush();
	const bool restored = make_current(data);
	if (present_listener)
		present_listener(now_ms() - begin);
	return restored;
}

} // namespace

extern "C" bool gpu_renderer_init(const wchar_t *angle_dir, uint32_t width, uint32_t height, bool flush,
				  void (*on_present)(double present_ms))
{
	present_listener = on_present;
	flush_only = flush;
	QueryPerformanceFrequency(&qpc_frequency);

	const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_0};
	if (FAILED(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
				     levels, 1, D3D11_SDK_VERSION, &device, nullptr, &device_context)))
		return fail("D3D11CreateDevice");
	ComPtr<ID3D11Multithread> multithread;
	if (FAILED(device_context.As(&multithread)))
		return fail("ID3D11Multithread");
	multithread->SetMultithreadProtected(TRUE);

	std::wstring dir(angle_dir);
	if (!dir.empty() && dir.back() != L'\\' && dir.back() != L'/')
		dir += L'\\';
	const DWORD flags = LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS;
	HMODULE gles = LoadLibraryExW((dir + L"libGLESv2.dll").c_str(), nullptr, flags);
	HMODULE egl = gles ? LoadLibraryExW((dir + L"libEGL.dll").c_str(), nullptr, flags) : nullptr;
	if (!gles || !egl)
		return fail("Load ANGLE");
	if (!load(egl, egl_get_proc_address, "eglGetProcAddress") || !load(egl, egl_initialize, "eglInitialize") ||
	    !load(egl, egl_choose_config, "eglChooseConfig") || !load(egl, egl_create_context, "eglCreateContext") ||
	    !load(egl, egl_create_pbuffer_surface, "eglCreatePbufferSurface") ||
	    !load(egl, egl_create_pbuffer_from_client_buffer, "eglCreatePbufferFromClientBuffer") ||
	    !load(egl, egl_make_current, "eglMakeCurrent") || !load(egl, egl_get_error, "eglGetError") ||
	    !load_extension(egl_create_device_angle, "eglCreateDeviceANGLE") ||
	    !load_extension(egl_get_platform_display, "eglGetPlatformDisplayEXT") ||
	    !load_extension(gl_finish, "glFinish") || !load_extension(gl_flush, "glFlush"))
		return false;

	EGLDeviceEXT egl_device = egl_create_device_angle(EGL_D3D11_DEVICE_ANGLE, device.Get(), nullptr);
	if (!egl_device)
		return fail("eglCreateDeviceANGLE");
	display = egl_get_platform_display(EGL_PLATFORM_DEVICE_EXT, egl_device, nullptr);
	if (!display || !egl_initialize(display, nullptr, nullptr))
		return fail("eglInitialize");
	const EGLint config_attributes[] = {EGL_SURFACE_TYPE,
					    EGL_PBUFFER_BIT,
					    EGL_RENDERABLE_TYPE,
					    EGL_OPENGL_ES2_BIT,
					    EGL_RED_SIZE,
					    8,
					    EGL_GREEN_SIZE,
					    8,
					    EGL_BLUE_SIZE,
					    8,
					    EGL_ALPHA_SIZE,
					    8,
					    EGL_DEPTH_SIZE,
					    0,
					    EGL_STENCIL_SIZE,
					    8,
					    EGL_NONE};
	EGLint count = 0;
	if (!egl_choose_config(display, config_attributes, &config, 1, &count) || count != 1)
		return fail("eglChooseConfig");
	const EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
	render_context = egl_create_context(display, config, nullptr, context_attributes);
	resource_context = egl_create_context(display, config, render_context, context_attributes);
	if (!render_context || !resource_context)
		return fail("eglCreateContext");
	const EGLint resource_attributes[] = {EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE};
	resource_surface = egl_create_pbuffer_surface(display, config, resource_attributes);
	if (!resource_surface)
		return fail("Create resource surface");

	render_target = create_texture(width, height);
	published_frame = create_texture(width, height);
	if (!render_target || !published_frame)
		return fail("Create frame textures");
	const EGLint surface_attributes[] = {EGL_NONE};
	surface = egl_create_pbuffer_from_client_buffer(display, EGL_D3D_TEXTURE_ANGLE, render_target.Get(), config,
							surface_attributes);
	if (!surface)
		return fail("Import D3D11 render target");
	printf("gpu: ANGLE/D3D11 ready, %ux%u, present waits with %s\n", width, height,
	       flush_only ? "glFlush" : "glFinish");
	return true;
}

extern "C" bool gpu_renderer_dump_bmp(const char *path)
{
	D3D11_TEXTURE2D_DESC desc;
	published_frame->GetDesc(&desc);
	desc.Usage = D3D11_USAGE_STAGING;
	desc.BindFlags = 0;
	desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
	ComPtr<ID3D11Texture2D> staging;
	if (FAILED(device->CreateTexture2D(&desc, nullptr, &staging)))
		return fail("Create staging texture");
	device_context->CopyResource(staging.Get(), published_frame.Get());
	D3D11_MAPPED_SUBRESOURCE mapped;
	if (FAILED(device_context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped)))
		return fail("Map staging texture");
	FILE *file = nullptr;
	if (fopen_s(&file, path, "wb") != 0 || !file) {
		device_context->Unmap(staging.Get(), 0);
		return fail("Open dump file");
	}
	const uint32_t row_bytes = desc.Width * 4;
	const uint32_t image_bytes = row_bytes * desc.Height;
	BITMAPFILEHEADER file_header = {};
	BITMAPINFOHEADER info = {};
	file_header.bfType = 0x4D42;
	file_header.bfOffBits = sizeof(file_header) + sizeof(info);
	file_header.bfSize = file_header.bfOffBits + image_bytes;
	info.biSize = sizeof(info);
	info.biWidth = LONG(desc.Width);
	/* GL renders bottom-up, which is exactly the row order of a positive-height BMP. */
	info.biHeight = LONG(desc.Height);
	info.biPlanes = 1;
	info.biBitCount = 32;
	info.biCompression = BI_RGB;
	info.biSizeImage = image_bytes;
	fwrite(&file_header, sizeof(file_header), 1, file);
	fwrite(&info, sizeof(info), 1, file);
	std::string row(row_bytes, '\0');
	for (uint32_t y = 0; y < desc.Height; ++y) {
		const auto *source = static_cast<const uint8_t *>(mapped.pData) + size_t(y) * mapped.RowPitch;
		for (uint32_t x = 0; x < desc.Width; ++x) {
			/* RGBA texture to BGRA bitmap. */
			row[x * 4] = char(source[x * 4 + 2]);
			row[x * 4 + 1] = char(source[x * 4 + 1]);
			row[x * 4 + 2] = char(source[x * 4]);
			row[x * 4 + 3] = char(source[x * 4 + 3]);
		}
		fwrite(row.data(), 1, row_bytes, file);
	}
	fclose(file);
	device_context->Unmap(staging.Get(), 0);
	return true;
}

extern "C" FlutterRendererConfig gpu_renderer_config(void)
{
	FlutterRendererConfig result = {};
	result.type = kOpenGL;
	result.open_gl.struct_size = sizeof(result.open_gl);
	result.open_gl.make_current = make_current;
	result.open_gl.clear_current = clear_current;
	result.open_gl.make_resource_current = make_resource_current;
	result.open_gl.fbo_with_frame_info_callback = framebuffer;
	result.open_gl.fbo_reset_after_present = true;
	result.open_gl.present = present;
	result.open_gl.gl_proc_resolver = resolve;
	return result;
}
