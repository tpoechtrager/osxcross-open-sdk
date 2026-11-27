/*
 * SPDX-License-Identifier: 0BSD
 *
 * xpc/xpc.h -- XPC objects, connections, services and activities.
 *
 * Written for the osxcross open SDK; not taken from any other header.
 * libxpc has no open source release.  Every name and value here has a
 * public source, listed in docs/SOURCES.md and data/symbols/libsystem-xpc.txt
 * of the generator:
 *   - the functions, their parameters and the macOS release that brought
 *     each of them: Apple's documentation of XPC
 *     (developer.apple.com/documentation/xpc, the C declaration of every
 *     function);
 *   - the object and block types, XPC_GLOBAL_OBJECT, XPC_ARRAY_APPEND,
 *     XPC_CONNECTION_MACH_SERVICE_LISTENER, the order of the activity
 *     states and the variables behind XPC_TYPE_*, XPC_ERROR_* and
 *     XPC_ERROR_KEY_DESCRIPTION: WebKit, Source/WTF/wtf/spi/darwin/XPCSPI.h
 *     (BSD-2-Clause), which declares them for builds without this header.
 *   - xpc_session, xpc_listener and xpc_rich_error: the same documentation
 *     (macOS 13.0 and 14.0); the types of the block parameters from the
 *     Swift declarations of the same pages.  The documentation names the
 *     flags (none, inactive, privileged; none, inactive) but gives no
 *     value and no C name that a public source confirms, so the flag types
 *     are plain 64-bit integers (a bit pattern that is wider than the
 *     real one is passed correctly), no flag is declared, and 0 is the
 *     value of "none" only by the convention of such flags: the functions
 *     create a session or listener that is active.
 * A type or value that neither names (the other XPC_TYPE_* macros,
 * XPC_BOOL_TRUE, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED, ...) is left out,
 * and so are the peer requirements and the flags.
 *
 * In Objective-C the objects are Objective-C objects (OS_OBJECT_USE_OBJC),
 * like those of libdispatch; elsewhere xpc_object_t is a void pointer.
 */
#ifndef __XPC_H__
#define __XPC_H__

#include <sys/cdefs.h>
#include <sys/types.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <bsm/audit.h>
#include <mach/port.h>
#include <uuid/uuid.h>
#include <os/availability.h>
#include <os/base.h>
#include <os/object.h>
#include <dispatch/dispatch.h>

__BEGIN_DECLS

/* Objects */

#if OS_OBJECT_USE_OBJC
OS_OBJECT_DECL(xpc_object);
#define XPC_GLOBAL_OBJECT(object) ((OS_OBJECT_BRIDGE xpc_object_t)&(object))
#else
typedef void *xpc_object_t;
#define XPC_GLOBAL_OBJECT(object) (&(object))
#endif

#if OS_OBJECT_USE_OBJC
OS_OBJECT_DECL_SUBCLASS(xpc_session, xpc_object);
OS_OBJECT_DECL_SUBCLASS(xpc_listener, xpc_object);
#else
typedef xpc_object_t xpc_session_t;
typedef xpc_object_t xpc_listener_t;
#endif

typedef xpc_object_t xpc_connection_t;
typedef xpc_object_t xpc_endpoint_t;
typedef xpc_object_t xpc_activity_t;
typedef xpc_object_t xpc_rich_error_t;
typedef const struct _xpc_type_s *xpc_type_t;

typedef void (*xpc_connection_handler_t)(xpc_connection_t connection);
typedef void (*xpc_finalizer_t)(void *value);
typedef uint64_t xpc_session_create_flags_t;
typedef uint64_t xpc_listener_create_flags_t;
#ifdef __BLOCKS__
typedef void (^xpc_handler_t)(xpc_object_t object);
typedef bool (^xpc_array_applier_t)(size_t index, xpc_object_t value);
typedef bool (^xpc_dictionary_applier_t)(const char *key, xpc_object_t value);
typedef void (^xpc_activity_handler_t)(xpc_activity_t activity);
typedef void (^xpc_session_incoming_message_handler_t)(xpc_object_t message);
typedef void (^xpc_session_cancel_handler_t)(xpc_rich_error_t error);
typedef void (^xpc_session_reply_handler_t)(xpc_object_t reply, xpc_rich_error_t error);
typedef void (^xpc_listener_incoming_session_handler_t)(xpc_session_t peer);
#endif

/* the variables behind the type and error macros */
extern const struct _xpc_type_s _xpc_type_array;
extern const struct _xpc_type_s _xpc_type_bool;
extern const struct _xpc_type_s _xpc_type_connection;
extern const struct _xpc_type_s _xpc_type_dictionary;
extern const struct _xpc_type_s _xpc_type_endpoint;
extern const struct _xpc_type_s _xpc_type_error;
extern const struct _xpc_type_s _xpc_type_string;
extern const struct _xpc_dictionary_s _xpc_error_connection_interrupted;
extern const struct _xpc_dictionary_s _xpc_error_connection_invalid;
extern const struct _xpc_dictionary_s _xpc_error_termination_imminent;
extern const char *const _xpc_error_key_description;

#define XPC_TYPE_ARRAY (&_xpc_type_array)
#define XPC_TYPE_BOOL (&_xpc_type_bool)
#define XPC_TYPE_CONNECTION (&_xpc_type_connection)
#define XPC_TYPE_DICTIONARY (&_xpc_type_dictionary)
#define XPC_TYPE_ENDPOINT (&_xpc_type_endpoint)
#define XPC_TYPE_ERROR (&_xpc_type_error)
#define XPC_TYPE_STRING (&_xpc_type_string)
#define XPC_ERROR_CONNECTION_INTERRUPTED XPC_GLOBAL_OBJECT(_xpc_error_connection_interrupted)
#define XPC_ERROR_CONNECTION_INVALID XPC_GLOBAL_OBJECT(_xpc_error_connection_invalid)
#define XPC_ERROR_TERMINATION_IMMINENT XPC_GLOBAL_OBJECT(_xpc_error_termination_imminent)
#define XPC_ERROR_KEY_DESCRIPTION _xpc_error_key_description

#define XPC_ARRAY_APPEND ((size_t)(-1))
#define XPC_CONNECTION_MACH_SERVICE_LISTENER (1 << 0)

/*
 * A function whose name says create or copy, and
 * xpc_connection_send_message_with_reply_sync, return an object that the
 * caller releases (OS_OBJECT_RETURNS_RETAINED, for ARC).
 */

API_AVAILABLE(macos(10.7))
xpc_object_t xpc_retain(xpc_object_t object);
API_AVAILABLE(macos(10.7))
void xpc_release(xpc_object_t object);
#if OS_OBJECT_USE_OBJC_RETAIN_RELEASE
#undef xpc_retain
#define xpc_retain(object) __extension__({ xpc_object_t _xo = (object); (void)[_xo retain]; _xo; })
#undef xpc_release
#define xpc_release(object) __extension__({ xpc_object_t _xo = (object); [_xo release]; })
#endif

API_AVAILABLE(macos(10.7))
xpc_type_t xpc_get_type(xpc_object_t object);
API_AVAILABLE(macos(10.15))
const char *xpc_type_get_name(xpc_type_t type);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_copy(xpc_object_t object);
API_AVAILABLE(macos(10.7))
bool xpc_equal(xpc_object_t object1, xpc_object_t object2);
API_AVAILABLE(macos(10.7))
size_t xpc_hash(xpc_object_t object);
/* the result is freed with free() */
API_AVAILABLE(macos(10.7))
char *xpc_copy_description(xpc_object_t object);

/* Values */

API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_null_create(void);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_bool_create(bool value);
API_AVAILABLE(macos(10.7))
bool xpc_bool_get_value(xpc_object_t xbool);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_int64_create(int64_t value);
API_AVAILABLE(macos(10.7))
int64_t xpc_int64_get_value(xpc_object_t xint);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_uint64_create(uint64_t value);
API_AVAILABLE(macos(10.7))
uint64_t xpc_uint64_get_value(xpc_object_t xuint);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_double_create(double value);
API_AVAILABLE(macos(10.7))
double xpc_double_get_value(xpc_object_t xdouble);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_date_create(int64_t interval);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_date_create_from_current(void);
API_AVAILABLE(macos(10.7))
int64_t xpc_date_get_value(xpc_object_t xdate);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_data_create(const void *bytes, size_t length);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_data_create_with_dispatch_data(dispatch_data_t ddata);
API_AVAILABLE(macos(10.7))
size_t xpc_data_get_length(xpc_object_t xdata);
API_AVAILABLE(macos(10.7))
const void *xpc_data_get_bytes_ptr(xpc_object_t xdata);
API_AVAILABLE(macos(10.7))
size_t xpc_data_get_bytes(xpc_object_t xdata, void *buffer, size_t off, size_t length);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_string_create(const char *string);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED __printflike(1, 2)
xpc_object_t xpc_string_create_with_format(const char *fmt, ...);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED __printflike(1, 0)
xpc_object_t xpc_string_create_with_format_and_arguments(const char *fmt, va_list ap);
API_AVAILABLE(macos(10.7))
size_t xpc_string_get_length(xpc_object_t xstring);
API_AVAILABLE(macos(10.7))
const char *xpc_string_get_string_ptr(xpc_object_t xstring);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_uuid_create(const uuid_t uuid);
API_AVAILABLE(macos(10.7))
const uint8_t *xpc_uuid_get_bytes(xpc_object_t xuuid);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_fd_create(int fd);
API_AVAILABLE(macos(10.7))
int xpc_fd_dup(xpc_object_t xfd);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_shmem_create(void *region, size_t length);
API_AVAILABLE(macos(10.7))
size_t xpc_shmem_map(xpc_object_t xshmem, void **region);

/* Arrays */

API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_array_create(const xpc_object_t *objects, size_t count);
API_AVAILABLE(macos(11.0)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_array_create_empty(void);
API_AVAILABLE(macos(10.7))
size_t xpc_array_get_count(xpc_object_t xarray);
API_AVAILABLE(macos(10.7))
void xpc_array_set_value(xpc_object_t xarray, size_t index, xpc_object_t value);
API_AVAILABLE(macos(10.7))
void xpc_array_append_value(xpc_object_t xarray, xpc_object_t value);
API_AVAILABLE(macos(10.7))
xpc_object_t xpc_array_get_value(xpc_object_t xarray, size_t index);
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.7))
bool xpc_array_apply(xpc_object_t xarray, xpc_array_applier_t applier);
#endif
API_AVAILABLE(macos(10.7))
void xpc_array_set_connection(xpc_object_t xarray, size_t index, xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_array_set_bool(xpc_object_t xarray, size_t index, bool value);
API_AVAILABLE(macos(10.7))
void xpc_array_set_int64(xpc_object_t xarray, size_t index, int64_t value);
API_AVAILABLE(macos(10.7))
void xpc_array_set_uint64(xpc_object_t xarray, size_t index, uint64_t value);
API_AVAILABLE(macos(10.7))
void xpc_array_set_double(xpc_object_t xarray, size_t index, double value);
API_AVAILABLE(macos(10.7))
void xpc_array_set_date(xpc_object_t xarray, size_t index, int64_t value);
API_AVAILABLE(macos(10.7))
void xpc_array_set_data(xpc_object_t xarray, size_t index, const void *bytes, size_t length);
API_AVAILABLE(macos(10.7))
void xpc_array_set_string(xpc_object_t xarray, size_t index, const char *string);
API_AVAILABLE(macos(10.7))
void xpc_array_set_uuid(xpc_object_t xarray, size_t index, const uuid_t uuid);
API_AVAILABLE(macos(10.7))
void xpc_array_set_fd(xpc_object_t xarray, size_t index, int fd);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_connection_t xpc_array_create_connection(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
bool xpc_array_get_bool(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
int64_t xpc_array_get_int64(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
uint64_t xpc_array_get_uint64(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
double xpc_array_get_double(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
int64_t xpc_array_get_date(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
const void *xpc_array_get_data(xpc_object_t xarray, size_t index, size_t *length);
API_AVAILABLE(macos(10.7))
const char *xpc_array_get_string(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
const uint8_t *xpc_array_get_uuid(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.7))
int xpc_array_dup_fd(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.11))
xpc_object_t xpc_array_get_array(xpc_object_t xarray, size_t index);
API_AVAILABLE(macos(10.11))
xpc_object_t xpc_array_get_dictionary(xpc_object_t xarray, size_t index);

/* Dictionaries */

API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_dictionary_create(const char *const *keys, const xpc_object_t *values, size_t count);
API_AVAILABLE(macos(11.0)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_dictionary_create_empty(void);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_dictionary_create_reply(xpc_object_t original);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_value(xpc_object_t xdict, const char *key, xpc_object_t value);
API_AVAILABLE(macos(10.7))
xpc_object_t xpc_dictionary_get_value(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
size_t xpc_dictionary_get_count(xpc_object_t xdict);
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.7))
bool xpc_dictionary_apply(xpc_object_t xdict, xpc_dictionary_applier_t applier);
#endif
API_AVAILABLE(macos(10.7))
xpc_connection_t xpc_dictionary_get_remote_connection(xpc_object_t xdict);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_connection(xpc_object_t xdict, const char *key, xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_bool(xpc_object_t xdict, const char *key, bool value);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_int64(xpc_object_t xdict, const char *key, int64_t value);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_double(xpc_object_t xdict, const char *key, double value);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_date(xpc_object_t xdict, const char *key, int64_t value);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_data(xpc_object_t xdict, const char *key, const void *bytes, size_t length);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_string(xpc_object_t xdict, const char *key, const char *string);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_uuid(xpc_object_t xdict, const char *key, const uuid_t uuid);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_fd(xpc_object_t xdict, const char *key, int fd);
API_AVAILABLE(macos(10.7))
void xpc_dictionary_set_mach_send(xpc_object_t xdict, const char *key, mach_port_t port);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_connection_t xpc_dictionary_create_connection(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
bool xpc_dictionary_get_bool(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
int64_t xpc_dictionary_get_int64(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
uint64_t xpc_dictionary_get_uint64(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
double xpc_dictionary_get_double(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
int64_t xpc_dictionary_get_date(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
const void *xpc_dictionary_get_data(xpc_object_t xdict, const char *key, size_t *length);
API_AVAILABLE(macos(10.7))
const char *xpc_dictionary_get_string(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
const uint8_t *xpc_dictionary_get_uuid(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
int xpc_dictionary_dup_fd(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.7))
mach_port_t xpc_dictionary_copy_mach_send(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.11))
xpc_object_t xpc_dictionary_get_array(xpc_object_t xdict, const char *key);
API_AVAILABLE(macos(10.11))
xpc_object_t xpc_dictionary_get_dictionary(xpc_object_t xdict, const char *key);

/* Connections and endpoints */

API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_connection_t xpc_connection_create(const char *name, dispatch_queue_t targetq);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_connection_t xpc_connection_create_mach_service(const char *name, dispatch_queue_t targetq, uint64_t flags);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_connection_t xpc_connection_create_from_endpoint(xpc_endpoint_t endpoint);
API_AVAILABLE(macos(10.7))
void xpc_connection_set_target_queue(xpc_connection_t connection, dispatch_queue_t targetq);
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.7))
void xpc_connection_set_event_handler(xpc_connection_t connection, xpc_handler_t handler);
#endif
API_AVAILABLE(macos(10.12))
void xpc_connection_activate(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_connection_suspend(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_connection_resume(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_connection_send_message(xpc_connection_t connection, xpc_object_t message);
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.7))
void xpc_connection_send_barrier(xpc_connection_t connection, dispatch_block_t barrier);
API_AVAILABLE(macos(10.7))
void xpc_connection_send_message_with_reply(xpc_connection_t connection, xpc_object_t message,
    dispatch_queue_t replyq, xpc_handler_t handler);
#endif
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_connection_send_message_with_reply_sync(xpc_connection_t connection, xpc_object_t message);
API_AVAILABLE(macos(10.7))
void xpc_connection_cancel(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
const char *xpc_connection_get_name(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
uid_t xpc_connection_get_euid(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
gid_t xpc_connection_get_egid(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
pid_t xpc_connection_get_pid(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
au_asid_t xpc_connection_get_asid(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_connection_set_context(xpc_connection_t connection, void *context);
API_AVAILABLE(macos(10.7))
void *xpc_connection_get_context(xpc_connection_t connection);
API_AVAILABLE(macos(10.7))
void xpc_connection_set_finalizer_f(xpc_connection_t connection, xpc_finalizer_t finalizer);
/* the result is freed with free() */
API_AVAILABLE(macos(12.0))
char *xpc_connection_copy_invalidation_reason(xpc_connection_t connection);
API_AVAILABLE(macos(12.0))
int xpc_connection_set_peer_code_signing_requirement(xpc_connection_t connection, const char *requirement);
API_AVAILABLE(macos(10.7)) OS_OBJECT_RETURNS_RETAINED
xpc_endpoint_t xpc_endpoint_create(xpc_connection_t connection);

/* Services, transactions and events */

API_AVAILABLE(macos(10.7))
void xpc_main(xpc_connection_handler_t handler) __dead2;
API_AVAILABLE(macos(10.7))
void xpc_transaction_begin(void);
API_AVAILABLE(macos(10.7))
void xpc_transaction_end(void);
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.7))
void xpc_set_event_stream_handler(const char *stream, dispatch_queue_t targetq, xpc_handler_t handler);
#endif

/* Activities */

typedef long xpc_activity_state_t;
enum {
	XPC_ACTIVITY_STATE_CHECK_IN = 0,
	XPC_ACTIVITY_STATE_WAIT = 1,
	XPC_ACTIVITY_STATE_RUN = 2,
	XPC_ACTIVITY_STATE_DEFER = 3,
	XPC_ACTIVITY_STATE_CONTINUE = 4,
	XPC_ACTIVITY_STATE_DONE = 5,
};

API_AVAILABLE(macos(10.9)) extern const xpc_object_t XPC_ACTIVITY_CHECK_IN;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_INTERVAL;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_DELAY;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_GRACE_PERIOD;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_1_MIN;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_5_MIN;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_15_MIN;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_30_MIN;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_1_HOUR;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_4_HOURS;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_8_HOURS;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_1_DAY;
API_AVAILABLE(macos(10.9)) extern const int64_t XPC_ACTIVITY_INTERVAL_7_DAYS;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_PRIORITY;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_PRIORITY_MAINTENANCE;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_PRIORITY_UTILITY;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_ALLOW_BATTERY;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_REPEATING;
API_AVAILABLE(macos(10.9)) extern const char *const XPC_ACTIVITY_REQUIRE_SCREEN_SLEEP;
API_AVAILABLE(macos(12.0)) extern const char *const XPC_ACTIVITY_PREVENT_DEVICE_SLEEP;

#ifdef __BLOCKS__
API_AVAILABLE(macos(10.9))
void xpc_activity_register(const char *identifier, xpc_object_t criteria, xpc_activity_handler_t handler);
#endif
API_AVAILABLE(macos(10.9)) OS_OBJECT_RETURNS_RETAINED
xpc_object_t xpc_activity_copy_criteria(xpc_activity_t activity);
API_AVAILABLE(macos(10.9))
void xpc_activity_set_criteria(xpc_activity_t activity, xpc_object_t criteria);
API_AVAILABLE(macos(10.9))
xpc_activity_state_t xpc_activity_get_state(xpc_activity_t activity);
API_AVAILABLE(macos(10.9))
bool xpc_activity_set_state(xpc_activity_t activity, xpc_activity_state_t state);
API_AVAILABLE(macos(10.9))
bool xpc_activity_should_defer(xpc_activity_t activity);
API_AVAILABLE(macos(10.9))
void xpc_activity_unregister(const char *identifier);

/* Sessions, listeners and rich errors */

/* the results of the functions that create are released with xpc_release */
API_AVAILABLE(macos(13.0)) OS_OBJECT_RETURNS_RETAINED
xpc_session_t xpc_session_create_mach_service(const char *mach_service, dispatch_queue_t target_queue,
    xpc_session_create_flags_t flags, xpc_rich_error_t *error_out);
API_AVAILABLE(macos(13.0)) OS_OBJECT_RETURNS_RETAINED
xpc_session_t xpc_session_create_xpc_service(const char *name, dispatch_queue_t target_queue,
    xpc_session_create_flags_t flags, xpc_rich_error_t *error_out);
API_AVAILABLE(macos(13.0))
bool xpc_session_activate(xpc_session_t session, xpc_rich_error_t *error_out);
API_AVAILABLE(macos(13.0))
void xpc_session_cancel(xpc_session_t session);
API_AVAILABLE(macos(13.0))
xpc_rich_error_t xpc_session_send_message(xpc_session_t session, xpc_object_t message);
API_AVAILABLE(macos(13.0))
xpc_object_t xpc_session_send_message_with_reply_sync(xpc_session_t session, xpc_object_t message,
    xpc_rich_error_t *error_out);
#ifdef __BLOCKS__
API_AVAILABLE(macos(13.0))
void xpc_session_send_message_with_reply_async(xpc_session_t session, xpc_object_t message,
    xpc_session_reply_handler_t reply_handler);
API_AVAILABLE(macos(13.0))
void xpc_session_set_incoming_message_handler(xpc_session_t session, xpc_session_incoming_message_handler_t handler);
API_AVAILABLE(macos(13.0))
void xpc_session_set_cancel_handler(xpc_session_t session, xpc_session_cancel_handler_t cancel_handler);
#endif
API_AVAILABLE(macos(14.0))
void xpc_session_set_target_queue(xpc_session_t session, dispatch_queue_t target_queue);
/* the result is freed with free() */
API_AVAILABLE(macos(13.0))
char *xpc_session_copy_description(xpc_session_t session);

#ifdef __BLOCKS__
API_AVAILABLE(macos(14.0)) OS_OBJECT_RETURNS_RETAINED
xpc_listener_t xpc_listener_create(const char *service, dispatch_queue_t target_queue,
    xpc_listener_create_flags_t flags, xpc_listener_incoming_session_handler_t incoming_session_handler,
    xpc_rich_error_t *error_out);
#endif
API_AVAILABLE(macos(14.0))
bool xpc_listener_activate(xpc_listener_t listener, xpc_rich_error_t *error_out);
API_AVAILABLE(macos(14.0))
void xpc_listener_cancel(xpc_listener_t listener);

/* no release is named for these two: the later one, that of XPC_TYPE_RICH_ERROR */
API_AVAILABLE(macos(14.0))
bool xpc_rich_error_can_retry(xpc_rich_error_t error);
API_AVAILABLE(macos(14.0))
char *xpc_rich_error_copy_description(xpc_rich_error_t error);

__END_DECLS

#endif /* __XPC_H__ */
