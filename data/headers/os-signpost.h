/*
 * SPDX-License-Identifier: 0BSD
 *
 * os/signpost.h -- signposts that do nothing.
 *
 * Written for the osxcross open SDK; not taken from any other header.
 * NOTHING IS TRACED: the functions and macros below let a program that uses
 * signposts compile, link and run.  They emit no signpost, they evaluate
 * none of their arguments (except the log object and the id of
 * os_signpost_id_make_with_pointer), and they import no symbol.  The
 * runtime interface of signposts (the values of the signpost types, the
 * functions of the system library) has no public source, so none of it is
 * used.
 *
 * Names and the values that are named in public sources (docs/SOURCES.md):
 *   - OS_SIGNPOST_ID_NULL, OS_SIGNPOST_ID_INVALID, OS_SIGNPOST_ID_EXCLUSIVE,
 *     OS_LOG_CATEGORY_POINTS_OF_INTEREST: swift stdlib/public/SwiftShims/
 *     OSOverlayShims.h (os_signpost_id_t is a 64-bit unsigned type there).
 *   - OS_SIGNPOST_EVENT, OS_SIGNPOST_INTERVAL_BEGIN, OS_SIGNPOST_INTERVAL_END
 *     (names only): swift stdlib/public/Darwin/os/os_signpost.swift.
 *   - os_signpost_enabled, os_signpost_id_generate,
 *     os_signpost_id_make_with_pointer (names): the same file.
 *   - os_signpost_event_emit, os_signpost_interval_begin,
 *     os_signpost_interval_end, os_signpost_emit_with_type,
 *     OS_SIGNPOST_ENABLE_TELEMETRY (names and the form of the calls):
 *     Security (keychain/SigninMetrics/OctagonSignPosts.h,
 *     OSX/utilities/SecDbStats.c).
 * The values of os_signpost_type_t and of OS_SIGNPOST_ENABLE_TELEMETRY are
 * our own: no public source names them, and they are used only here.
 */
#ifndef __OS_SIGNPOST_H__
#define __OS_SIGNPOST_H__

#include <sys/cdefs.h>
#include <stdbool.h>
#include <stdint.h>
#include <os/availability.h>
#include <os/base.h>
#include <os/log.h>

__BEGIN_DECLS

typedef uint64_t os_signpost_id_t;

#define OS_SIGNPOST_ID_NULL      ((os_signpost_id_t)0)
#define OS_SIGNPOST_ID_INVALID   ((os_signpost_id_t)~0)
#define OS_SIGNPOST_ID_EXCLUSIVE ((os_signpost_id_t)0xEEEEB0B5B2B2EEEE)

#define OS_LOG_CATEGORY_POINTS_OF_INTEREST "PointsOfInterest"

/* Our own numbering; nothing reads it. */
OS_ENUM(os_signpost_type, uint8_t,
	OS_SIGNPOST_EVENT          = 0x01,
	OS_SIGNPOST_INTERVAL_BEGIN = 0x02,
	OS_SIGNPOST_INTERVAL_END   = 0x03);

/* The text that Security appends to a signpost format; here it adds nothing. */
#define OS_SIGNPOST_ENABLE_TELEMETRY ""

/* Signposts are never on. */
static inline bool
os_signpost_enabled(os_log_t log)
{
	(void)log;
	return false;
}

static inline os_signpost_id_t
os_signpost_id_generate(os_log_t log)
{
	(void)log;
	return OS_SIGNPOST_ID_EXCLUSIVE;
}

static inline os_signpost_id_t
os_signpost_id_make_with_pointer(os_log_t log, const void *ptr)
{
	(void)log;
	return ptr ? (os_signpost_id_t)(uintptr_t)ptr : OS_SIGNPOST_ID_NULL;
}

/* Only for the compiler to look at the arguments of the macros. */
static inline int
_os_signpost_ignored(os_log_t log, os_signpost_id_t id, const char *name, ...)
{
	(void)log; (void)id; (void)name;
	return 0;
}

__END_DECLS

/* The arguments are checked by the compiler and never evaluated. */
#define os_signpost_emit_with_type(log, type, id, name, ...) \
	((void)(0 && _os_signpost_ignored((log), (id), (name), (type), ##__VA_ARGS__)))
#define os_signpost_event_emit(log, id, name, ...) \
	((void)(0 && _os_signpost_ignored((log), (id), (name), ##__VA_ARGS__)))
#define os_signpost_interval_begin(log, id, name, ...) \
	((void)(0 && _os_signpost_ignored((log), (id), (name), ##__VA_ARGS__)))
#define os_signpost_interval_end(log, id, name, ...) \
	((void)(0 && _os_signpost_ignored((log), (id), (name), ##__VA_ARGS__)))

#endif /* __OS_SIGNPOST_H__ */
