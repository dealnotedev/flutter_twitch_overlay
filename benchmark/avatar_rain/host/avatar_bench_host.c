/*
 * Minimal benchmark host for the avatar pixel rain.
 *
 * Runs a Flutter AOT bundle through the OBS plugin's flutter_engine.dll with
 * the same setup as flutter_obs_source: kSoftware renderer, one merged
 * platform/UI task runner and a full-frame copy in the present callback.
 *
 * Usage:
 *   avatar_bench_host.exe <flutter_engine.dll> <bundle dir> [width height] [--coarse-timer]
 *                         [--affinity <hex mask>]
 *
 * --affinity restricts the process to the given logical processors, e.g.
 * 0x0FFF0000 for the E-cores of an i7-14700F to approximate a Ryzen 7 3700X.
 *
 * The bundle dir contains app.so, icudtl.dat and flutter_assets. Dart prints
 * BENCH_PHASE_BEGIN <name> / BENCH_PHASE_STOP and the host reports how many
 * frames reached the present callback in between.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <timeapi.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "embedder.h"

#pragma comment(lib, "winmm.lib")

typedef FlutterEngineResult (*PFN_CreateAOTData)(const FlutterEngineAOTDataSource *, FlutterEngineAOTData *);
typedef FlutterEngineResult (*PFN_CollectAOTData)(FlutterEngineAOTData);
typedef FlutterEngineResult (*PFN_Initialize)(size_t, const FlutterRendererConfig *, const FlutterProjectArgs *,
					      void *, FLUTTER_API_SYMBOL(FlutterEngine) *);
typedef FlutterEngineResult (*PFN_RunInitialized)(FLUTTER_API_SYMBOL(FlutterEngine));
typedef FlutterEngineResult (*PFN_Shutdown)(FLUTTER_API_SYMBOL(FlutterEngine));
typedef FlutterEngineResult (*PFN_SendWindowMetricsEvent)(FLUTTER_API_SYMBOL(FlutterEngine),
							  const FlutterWindowMetricsEvent *);
typedef FlutterEngineResult (*PFN_ScheduleFrame)(FLUTTER_API_SYMBOL(FlutterEngine));
typedef FlutterEngineResult (*PFN_RunTask)(FLUTTER_API_SYMBOL(FlutterEngine), const FlutterTask *);
typedef uint64_t (*PFN_GetCurrentTime)(void);
typedef FlutterEngineResult (*PFN_SendPlatformMessage)(FLUTTER_API_SYMBOL(FlutterEngine),
						       const FlutterPlatformMessage *);
typedef FlutterEngineResult (*PFN_SendPlatformMessageResponse)(FLUTTER_API_SYMBOL(FlutterEngine),
							       const FlutterPlatformMessageResponseHandle *,
							       const uint8_t *, size_t);

static PFN_CreateAOTData pCreateAOTData;
static PFN_CollectAOTData pCollectAOTData;
static PFN_Initialize pInitialize;
static PFN_RunInitialized pRunInitialized;
static PFN_Shutdown pShutdown;
static PFN_SendWindowMetricsEvent pSendWindowMetricsEvent;
static PFN_ScheduleFrame pScheduleFrame;
static PFN_RunTask pRunTask;
static PFN_GetCurrentTime pGetCurrentTime;
static PFN_SendPlatformMessage pSendPlatformMessage;
static PFN_SendPlatformMessageResponse pSendPlatformMessageResponse;

static FLUTTER_API_SYMBOL(FlutterEngine) g_engine;
static uint32_t g_width = 1920;
static uint32_t g_height = 1080;

/* ---- merged platform/UI task runner, mirrors worker_queue_wait_pop ---- */

#define TASK_CAPACITY 16384

typedef struct {
	FlutterTask task;
	uint64_t target;
} pending_task;

static pending_task g_tasks[TASK_CAPACITY];
static int g_task_count;
static CRITICAL_SECTION g_task_cs;
static CONDITION_VARIABLE g_task_cv;
static DWORD g_engine_tid;
static volatile LONG g_done;

static void post_task(FlutterTask task, uint64_t target, void *user_data)
{
	(void)user_data;
	EnterCriticalSection(&g_task_cs);
	if (g_task_count >= TASK_CAPACITY) {
		fprintf(stderr, "task queue overflow\n");
		abort();
	}
	int i = g_task_count;
	while (i > 0 && g_tasks[i - 1].target > target) {
		g_tasks[i] = g_tasks[i - 1];
		--i;
	}
	g_tasks[i].task = task;
	g_tasks[i].target = target;
	++g_task_count;
	WakeConditionVariable(&g_task_cv);
	LeaveCriticalSection(&g_task_cs);
}

static bool runs_on_engine_thread(void *user_data)
{
	(void)user_data;
	return GetCurrentThreadId() == g_engine_tid;
}

/* ---- frame statistics ---- */

#define MAX_INTERVALS 8192

static CRITICAL_SECTION g_stats_cs;
static LARGE_INTEGER g_qpc_freq;
static bool g_phase_active;
static char g_phase_name[256];
static double g_phase_begin;
static double g_last_present;
static int g_phase_frames;
static double g_intervals[MAX_INTERVALS];
static int g_interval_count;
static double g_present_copy_total;

static double now_ms(void)
{
	LARGE_INTEGER t;
	QueryPerformanceCounter(&t);
	return (double)t.QuadPart * 1000.0 / (double)g_qpc_freq.QuadPart;
}

static uint8_t *g_slot;
static size_t g_slot_capacity;

static bool surface_present(void *user_data, const void *allocation, size_t row_bytes, size_t height)
{
	(void)user_data;
	const double copy_begin = now_ms();
	const size_t tight = (size_t)g_width * 4;
	const size_t required = tight * height;
	if (g_slot_capacity < required) {
		g_slot = realloc(g_slot, required);
		g_slot_capacity = required;
	}
	const uint8_t *source = allocation;
	for (size_t row = 0; row < height; ++row)
		memcpy(g_slot + row * tight, source + row * row_bytes, tight);
	const double t = now_ms();

	EnterCriticalSection(&g_stats_cs);
	if (g_phase_active) {
		if (g_phase_frames > 0 && g_interval_count < MAX_INTERVALS)
			g_intervals[g_interval_count++] = t - g_last_present;
		++g_phase_frames;
		g_present_copy_total += t - copy_begin;
	}
	g_last_present = t;
	LeaveCriticalSection(&g_stats_cs);
	return true;
}

static int compare_double(const void *a, const void *b)
{
	const double x = *(const double *)a, y = *(const double *)b;
	return (x > y) - (x < y);
}

static void phase_begin(const char *name)
{
	EnterCriticalSection(&g_stats_cs);
	strncpy_s(g_phase_name, sizeof(g_phase_name), name, _TRUNCATE);
	g_phase_begin = now_ms();
	g_phase_frames = 0;
	g_interval_count = 0;
	g_present_copy_total = 0;
	g_phase_active = true;
	LeaveCriticalSection(&g_stats_cs);
}

static void phase_stop(void)
{
	EnterCriticalSection(&g_stats_cs);
	g_phase_active = false;
	const double length = now_ms() - g_phase_begin;
	const int frames = g_phase_frames;
	const int n = g_interval_count;
	qsort(g_intervals, n, sizeof(double), compare_double);
	int janky = 0;
	for (int i = 0; i < n; ++i)
		if (g_intervals[i] > 25.0)
			++janky;
	printf("HOST_RESULT %-22s presented %4d frames in %6.0f ms = %5.1f fps | interval p50 %5.1f p95 %5.1f max %6.1f ms | >25ms: %d | copy %.2f ms/frame\n",
	       g_phase_name, frames, length, frames * 1000.0 / length, n ? g_intervals[n / 2] : 0.0,
	       n ? g_intervals[(int)(n * 0.95)] : 0.0, n ? g_intervals[n - 1] : 0.0, janky,
	       frames ? g_present_copy_total / frames : 0.0);
	fflush(stdout);
	LeaveCriticalSection(&g_stats_cs);
}

/* ---- engine callbacks ---- */

static void wake_loop(void)
{
	EnterCriticalSection(&g_task_cs);
	WakeConditionVariable(&g_task_cv);
	LeaveCriticalSection(&g_task_cs);
}

static void log_message(const char *tag, const char *message, void *user_data)
{
	(void)tag;
	(void)user_data;
	if (!message)
		return;
	if (strncmp(message, "BENCH_PHASE_BEGIN ", 18) == 0) {
		phase_begin(message + 18);
	} else if (strcmp(message, "BENCH_PHASE_STOP") == 0) {
		phase_stop();
	} else if (strcmp(message, "BENCH_DONE") == 0) {
		InterlockedExchange(&g_done, 1);
		wake_loop();
	} else {
		printf("%s\n", message);
		fflush(stdout);
	}
}

static void platform_message(const FlutterPlatformMessage *message, void *user_data)
{
	(void)user_data;
	if (message->response_handle)
		pSendPlatformMessageResponse(g_engine, message->response_handle, NULL, 0);
}

static FARPROC require_proc(HMODULE module, const char *name)
{
	FARPROC proc = GetProcAddress(module, name);
	if (!proc) {
		fprintf(stderr, "missing export %s\n", name);
		exit(2);
	}
	return proc;
}

int main(int argc, char **argv)
{
	if (argc < 3) {
		fprintf(stderr, "usage: %s <flutter_engine.dll> <bundle dir> [width height] [--coarse-timer]\n",
			argv[0]);
		return 1;
	}
	bool coarse_timer = false;
	DWORD_PTR affinity = 0;
	int positional = 0;
	const char *dll = NULL, *bundle = NULL;
	for (int i = 1; i < argc; ++i) {
		if (strcmp(argv[i], "--coarse-timer") == 0) {
			coarse_timer = true;
			continue;
		}
		if (strcmp(argv[i], "--affinity") == 0 && i + 1 < argc) {
			affinity = (DWORD_PTR)strtoull(argv[++i], NULL, 16);
			continue;
		}
		switch (positional++) {
		case 0:
			dll = argv[i];
			break;
		case 1:
			bundle = argv[i];
			break;
		case 2:
			g_width = (uint32_t)atoi(argv[i]);
			break;
		case 3:
			g_height = (uint32_t)atoi(argv[i]);
			break;
		}
	}
	if (!coarse_timer)
		timeBeginPeriod(1);
	if (affinity && !SetProcessAffinityMask(GetCurrentProcess(), affinity)) {
		fprintf(stderr, "SetProcessAffinityMask failed (%lu)\n", GetLastError());
		return 1;
	}
	printf("host: %ux%u, %s timer, affinity 0x%llx\n", g_width, g_height, coarse_timer ? "default" : "1 ms",
	       (unsigned long long)affinity);

	QueryPerformanceFrequency(&g_qpc_freq);
	InitializeCriticalSection(&g_task_cs);
	InitializeCriticalSection(&g_stats_cs);
	InitializeConditionVariable(&g_task_cv);
	g_engine_tid = GetCurrentThreadId();

	HMODULE module = LoadLibraryA(dll);
	if (!module) {
		fprintf(stderr, "cannot load %s (%lu)\n", dll, GetLastError());
		return 2;
	}
	pCreateAOTData = (PFN_CreateAOTData)require_proc(module, "FlutterEngineCreateAOTData");
	pCollectAOTData = (PFN_CollectAOTData)require_proc(module, "FlutterEngineCollectAOTData");
	pInitialize = (PFN_Initialize)require_proc(module, "FlutterEngineInitialize");
	pRunInitialized = (PFN_RunInitialized)require_proc(module, "FlutterEngineRunInitialized");
	pShutdown = (PFN_Shutdown)require_proc(module, "FlutterEngineShutdown");
	pSendWindowMetricsEvent = (PFN_SendWindowMetricsEvent)require_proc(module, "FlutterEngineSendWindowMetricsEvent");
	pScheduleFrame = (PFN_ScheduleFrame)require_proc(module, "FlutterEngineScheduleFrame");
	pRunTask = (PFN_RunTask)require_proc(module, "FlutterEngineRunTask");
	pGetCurrentTime = (PFN_GetCurrentTime)require_proc(module, "FlutterEngineGetCurrentTime");
	pSendPlatformMessage = (PFN_SendPlatformMessage)require_proc(module, "FlutterEngineSendPlatformMessage");
	pSendPlatformMessageResponse =
		(PFN_SendPlatformMessageResponse)require_proc(module, "FlutterEngineSendPlatformMessageResponse");

	char assets[MAX_PATH], icu[MAX_PATH], aot[MAX_PATH];
	snprintf(assets, sizeof(assets), "%s\\flutter_assets", bundle);
	snprintf(icu, sizeof(icu), "%s\\icudtl.dat", bundle);
	snprintf(aot, sizeof(aot), "%s\\app.so", bundle);

	FlutterRendererConfig renderer = {0};
	renderer.type = kSoftware;
	renderer.software.struct_size = sizeof(FlutterSoftwareRendererConfig);
	renderer.software.surface_present_callback = surface_present;

	FlutterTaskRunnerDescription runner = {0};
	runner.struct_size = sizeof(runner);
	runner.runs_task_on_current_thread_callback = runs_on_engine_thread;
	runner.post_task_callback = post_task;
	runner.identifier = 1;

	FlutterCustomTaskRunners runners = {0};
	runners.struct_size = sizeof(runners);
	runners.platform_task_runner = &runner;
	runners.ui_task_runner = &runner;

	FlutterEngineAOTDataSource aot_source = {0};
	aot_source.type = kFlutterEngineAOTDataSourceTypeElfPath;
	aot_source.elf_path = aot;
	FlutterEngineAOTData aot_data = NULL;
	if (pCreateAOTData(&aot_source, &aot_data) != kSuccess) {
		fprintf(stderr, "FlutterEngineCreateAOTData failed for %s\n", aot);
		return 3;
	}

	static const char *engine_args[] = {"avatar_bench_host"};
	FlutterProjectArgs project = {0};
	project.struct_size = sizeof(project);
	project.assets_path = assets;
	project.icu_data_path = icu;
	project.command_line_argc = 1;
	project.command_line_argv = engine_args;
	project.platform_message_callback = platform_message;
	project.custom_task_runners = &runners;
	project.shutdown_dart_vm_when_done = true;
	project.aot_data = aot_data;
	project.log_message_callback = log_message;

	FlutterEngineResult result = pInitialize(FLUTTER_ENGINE_VERSION, &renderer, &project, NULL, &g_engine);
	if (result != kSuccess) {
		fprintf(stderr, "FlutterEngineInitialize failed: %d\n", result);
		return 4;
	}
	result = pRunInitialized(g_engine);
	if (result != kSuccess) {
		fprintf(stderr, "FlutterEngineRunInitialized failed: %d\n", result);
		return 5;
	}

	FlutterWindowMetricsEvent metrics = {0};
	metrics.struct_size = sizeof(metrics);
	metrics.width = g_width;
	metrics.height = g_height;
	metrics.pixel_ratio = 1.0;
	pSendWindowMetricsEvent(g_engine, &metrics);

	static const char resumed[] = "AppLifecycleState.resumed";
	FlutterPlatformMessage lifecycle = {0};
	lifecycle.struct_size = sizeof(lifecycle);
	lifecycle.channel = "flutter/lifecycle";
	lifecycle.message = (const uint8_t *)resumed;
	lifecycle.message_size = sizeof(resumed) - 1;
	pSendPlatformMessage(g_engine, &lifecycle);
	pScheduleFrame(g_engine);

	EnterCriticalSection(&g_task_cs);
	while (!InterlockedCompareExchange(&g_done, 0, 0)) {
		if (g_task_count == 0) {
			SleepConditionVariableCS(&g_task_cv, &g_task_cs, INFINITE);
			continue;
		}
		const uint64_t now = pGetCurrentTime();
		if (g_tasks[0].target > now) {
			const uint64_t wait_ms = (g_tasks[0].target - now + 999999ULL) / 1000000ULL;
			SleepConditionVariableCS(&g_task_cv, &g_task_cs, (DWORD)wait_ms);
			continue;
		}
		const FlutterTask task = g_tasks[0].task;
		memmove(&g_tasks[0], &g_tasks[1], sizeof(pending_task) * (size_t)(g_task_count - 1));
		--g_task_count;
		LeaveCriticalSection(&g_task_cs);
		pRunTask(g_engine, &task);
		EnterCriticalSection(&g_task_cs);
	}
	LeaveCriticalSection(&g_task_cs);

	/* The benchmark is over; skip the engine teardown handshake. */
	fflush(stdout);
	if (!coarse_timer)
		timeEndPeriod(1);
	ExitProcess(0);
}
