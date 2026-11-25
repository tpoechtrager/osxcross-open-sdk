/*
 * SPDX-License-Identifier: 0BSD
 *
 * os/trace.h -- the older os_trace macros, which do nothing.
 *
 * Written for the osxcross open SDK; not taken from any other header.
 * NOTHING IS TRACED: the macros check their arguments (the compiler sees
 * them, nothing evaluates them) and import no symbol.  Use os/log.h to log.
 *
 * The names and the form (a format string and its arguments) are those of
 * xnu's libkern/os/trace.h (APSL 2.0; names only, no text): os_trace,
 * os_trace_info, os_trace_debug, os_trace_error, os_trace_fault,
 * os_trace_info_enabled, os_trace_debug_enabled.  The variants with a
 * payload block are not provided.
 */
#ifndef __OS_TRACE_H__
#define __OS_TRACE_H__

#include <sys/cdefs.h>
#include <stdbool.h>
#include <os/availability.h>
#include <os/base.h>

__BEGIN_DECLS

static inline int
_os_trace_ignored(const char *format, ...)
{
	(void)format;
	return 0;
}

static inline bool
os_trace_info_enabled(void)
{
	return false;
}

static inline bool
os_trace_debug_enabled(void)
{
	return false;
}

__END_DECLS

#define os_trace(format, ...) \
	((void)(0 && _os_trace_ignored((format), ##__VA_ARGS__)))
#define os_trace_info(format, ...) \
	((void)(0 && _os_trace_ignored((format), ##__VA_ARGS__)))
#define os_trace_debug(format, ...) \
	((void)(0 && _os_trace_ignored((format), ##__VA_ARGS__)))
#define os_trace_error(format, ...) \
	((void)(0 && _os_trace_ignored((format), ##__VA_ARGS__)))
#define os_trace_fault(format, ...) \
	((void)(0 && _os_trace_ignored((format), ##__VA_ARGS__)))

#endif /* __OS_TRACE_H__ */
