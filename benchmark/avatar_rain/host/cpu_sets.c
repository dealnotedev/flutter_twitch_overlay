/* Prints the efficiency class of every logical processor (P vs E cores). */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
	ULONG length = 0;
	GetSystemCpuSetInformation(NULL, 0, &length, GetCurrentProcess(), 0);
	SYSTEM_CPU_SET_INFORMATION *info = malloc(length);
	if (!GetSystemCpuSetInformation(info, length, &length, GetCurrentProcess(), 0))
		return 1;
	for (BYTE *p = (BYTE *)info; p < (BYTE *)info + length;) {
		SYSTEM_CPU_SET_INFORMATION *entry = (SYSTEM_CPU_SET_INFORMATION *)p;
		printf("logical %2u core %2u efficiency %u\n", entry->CpuSet.LogicalProcessorIndex,
		       entry->CpuSet.CoreIndex, entry->CpuSet.EfficiencyClass);
		p += entry->Size;
	}
	return 0;
}
