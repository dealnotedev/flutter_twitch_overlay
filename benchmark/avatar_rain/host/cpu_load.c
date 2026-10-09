/*
 * Keeps N threads busy for the given number of seconds to emulate a game and
 * a software encoder competing with the overlay for CPU time.
 *
 * Usage: cpu_load.exe <threads> <seconds> [hex affinity mask]
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

static volatile LONG g_stop;

static DWORD WINAPI spin(LPVOID parameter)
{
	(void)parameter;
	volatile double x = 1.0;
	while (!g_stop) {
		for (int i = 0; i < 100000; ++i)
			x = x * 1.0000001 + 0.0000001;
	}
	return 0;
}

int main(int argc, char **argv)
{
	const int threads = argc > 1 ? atoi(argv[1]) : 8;
	const int seconds = argc > 2 ? atoi(argv[2]) : 60;
	if (argc > 3)
		SetProcessAffinityMask(GetCurrentProcess(), (DWORD_PTR)strtoull(argv[3], NULL, 16));
	HANDLE *handles = calloc((size_t)threads, sizeof(HANDLE));
	for (int i = 0; i < threads; ++i)
		handles[i] = CreateThread(NULL, 0, spin, NULL, 0, NULL);
	Sleep((DWORD)seconds * 1000);
	InterlockedExchange(&g_stop, 1);
	WaitForMultipleObjects((DWORD)threads, handles, TRUE, INFINITE);
	return 0;
}
