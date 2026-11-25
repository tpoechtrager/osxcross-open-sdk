/*
 * SPDX-License-Identifier: 0BSD
 *
 * os/log.h -- unified logging: os_log and its relatives.
 *
 * Written for the osxcross open SDK; not taken from any other header.
 * Where every name and value comes from is listed in docs/SOURCES.md of
 * the generator.  In short:
 *   - __builtin_os_log_format and __builtin_os_log_format_buffer_size are
 *     Clang builtins (LLVM, clang/include/clang/Basic/Builtins.td); the
 *     compiler writes the argument buffer.
 *   - _os_log_impl and its six arguments: the call in the Swift overlay of
 *     the os module (swift, stdlib/public/Darwin/os/os.m); the type of the
 *     last argument is that of ob_len in os_trace_blob.h of the same
 *     directory (uint32_t).
 *   - os_log_t, os_log_create, os_log_type_t with its values, the default
 *     log object and __dso_handle: xnu, libkern/os/log.h.
 *   - os_log_type_enabled: the call in configd (SystemConfiguration.fproj/
 *     SCD.c).
 *
 * Without the Clang builtin (GCC, old Clang) the macros check their
 * arguments and log nothing.
 */
#ifndef __OS_LOG_H__
#define __OS_LOG_H__

#include <sys/cdefs.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <os/availability.h>
#include <os/base.h>
#include <os/object.h>

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif

__BEGIN_DECLS

/*
 * os_log_t is an object type (a class under Objective-C, a pointer to an
 * opaque structure in C and C++).
 */
OS_OBJECT_DECL_CLASS(os_log);

/* The kinds of message.  The values are those of xnu's libkern/os/log.h. */
OS_ENUM(os_log_type, uint8_t,
	OS_LOG_TYPE_DEFAULT = 0x00,
	OS_LOG_TYPE_INFO    = 0x01,
	OS_LOG_TYPE_DEBUG   = 0x02,
	OS_LOG_TYPE_ERROR   = 0x10,
	OS_LOG_TYPE_FAULT   = 0x11);

/*
 * A log object that logs nothing.  xnu's libkern/os/log.h defines it as NULL
 * (for the kernel); os_log_type_enabled and the macros accept it in a process
 * (tested: nothing is logged, nothing crashes).
 */
#define OS_LOG_DISABLED NULL

/* The log object of the process. */
extern struct os_log_s _os_log_default;
#define OS_LOG_DEFAULT OS_OBJECT_GLOBAL_OBJECT(os_log_t, _os_log_default)

/* The handle of the image that the call is compiled into (set by the linker). */
extern void *__dso_handle;

/*
 * Makes a log object for a subsystem (for example "com.example.app") and a
 * category inside it.  Both strings are copied.
 */
API_AVAILABLE(macos(10.12))
OS_EXPORT OS_NOTHROW OS_WARN_RESULT OS_OBJECT_RETURNS_RETAINED OS_NONNULL_ALL
os_log_t
os_log_create(const char *subsystem, const char *category);

/* Whether a message of this type for this log object would be kept. */
API_AVAILABLE(macos(10.12))
OS_EXPORT OS_NOTHROW OS_WARN_RESULT
bool
os_log_type_enabled(os_log_t log, os_log_type_t type);

/* The function that the macros call; do not call it yourself. */
API_AVAILABLE(macos(10.12))
OS_EXPORT OS_NOTHROW
void
_os_log_impl(void *dso, os_log_t log, os_log_type_t type, const char *format,
		uint8_t *buf, uint32_t size);

__END_DECLS

#if __has_builtin(__builtin_os_log_format) && \
	__has_builtin(__builtin_os_log_format_buffer_size)

/*
 * The format must be a string literal.  The compiler checks it and encodes
 * the arguments into a buffer of the size that it computes; the system
 * reads the buffer together with the format.  The arguments are evaluated
 * only if the message is kept.
 */
#define os_log_with_type(log, type, format, ...) \
	__extension__({ \
		os_log_t _oslog_object = (log); \
		os_log_type_t _oslog_type = (type); \
		if (os_log_type_enabled(_oslog_object, _oslog_type)) { \
			uint8_t _oslog_buf[__builtin_os_log_format_buffer_size( \
					format, ##__VA_ARGS__)]; \
			_os_log_impl(&__dso_handle, _oslog_object, _oslog_type, format, \
					(uint8_t *)__builtin_os_log_format(_oslog_buf, format, \
					##__VA_ARGS__), (uint32_t)sizeof(_oslog_buf)); \
		} \
	})

#else /* no os_log builtin in this compiler */

/*
 * Nothing is logged.  The arguments are looked at by the compiler (types,
 * unused variables) and never evaluated.
 */
__BEGIN_DECLS
static inline int
_os_log_ignored(os_log_t log, os_log_type_t type, const char *format, ...)
{
	(void)log; (void)type; (void)format;
	return 0;
}
__END_DECLS

#define os_log_with_type(log, type, format, ...) \
	((void)(0 && _os_log_ignored((log), (type), (format), ##__VA_ARGS__)))

#endif /* __builtin_os_log_format */

#define os_log(log, format, ...) \
	os_log_with_type(log, OS_LOG_TYPE_DEFAULT, format, ##__VA_ARGS__)
#define os_log_info(log, format, ...) \
	os_log_with_type(log, OS_LOG_TYPE_INFO, format, ##__VA_ARGS__)
#define os_log_debug(log, format, ...) \
	os_log_with_type(log, OS_LOG_TYPE_DEBUG, format, ##__VA_ARGS__)
#define os_log_error(log, format, ...) \
	os_log_with_type(log, OS_LOG_TYPE_ERROR, format, ##__VA_ARGS__)
#define os_log_fault(log, format, ...) \
	os_log_with_type(log, OS_LOG_TYPE_FAULT, format, ##__VA_ARGS__)

#endif /* __OS_LOG_H__ */
