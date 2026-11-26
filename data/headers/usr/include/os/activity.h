/*
 * SPDX-License-Identifier: 0BSD
 *
 * os/activity.h -- activities that do nothing.
 *
 * Written for the osxcross open SDK; not taken from any other header.
 * NOTHING IS TRACED: an activity is never created (os_activity_create
 * returns NULL, which os_release accepts), scopes enter and leave nothing,
 * and os_activity_initiate calls its block at once.  No symbol is imported.
 * The size of the system's scope state and the values of its flags have no
 * public source; the structure and the flag values here are our own and
 * never reach the system.
 *
 * Names and the form of the calls come from open source that uses them
 * (docs/SOURCES.md): Security (OSX/sec/Security/SecTrust.c,
 * SecLogging.c, OSX/include/security_keychain/SecItem.cpp,
 * OSX/utilities/SecAppleAnchor.c, keychain/SecureObjectSync/SOSAccount.m):
 * os_activity_t, os_activity_create(description, parent, flags),
 * OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT,
 * OS_ACTIVITY_FLAG_IF_NONE_PRESENT, os_activity_scope(activity),
 * os_activity_scope_enter(activity, &state), os_activity_scope_leave(&state),
 * struct os_activity_scope_state_s, os_activity_initiate(description, flags,
 * block).
 */
#ifndef __OS_ACTIVITY_H__
#define __OS_ACTIVITY_H__

#include <sys/cdefs.h>
#include <stdint.h>
#include <os/availability.h>
#include <os/base.h>
#include <os/object.h>

__BEGIN_DECLS

OS_OBJECT_DECL_CLASS(os_activity);

/* Our own values. */
OS_ENUM(os_activity_flag, uint32_t,
	OS_ACTIVITY_FLAG_DEFAULT         = 0,
	OS_ACTIVITY_FLAG_IF_NONE_PRESENT = 2);

/* The activity of the caller: none. */
#define OS_ACTIVITY_CURRENT ((os_activity_t)0)

/* What os_activity_scope_enter fills in; ours, and not used by anything. */
struct os_activity_scope_state_s {
	uint64_t opaque[2];
};

static inline os_activity_t
os_activity_create(const char *description, os_activity_t parent,
		os_activity_flag_t flags)
{
	(void)description; (void)parent; (void)flags;
	return (os_activity_t)0;
}

static inline void
os_activity_scope_enter(os_activity_t activity,
		struct os_activity_scope_state_s *state)
{
	(void)activity;
	state->opaque[0] = 0;
	state->opaque[1] = 0;
}

static inline void
os_activity_scope_leave(struct os_activity_scope_state_s *state)
{
	(void)state;
}

#ifdef __BLOCKS__
static inline void
os_activity_initiate(const char *description, os_activity_flag_t flags,
		void (^activity_block)(void))
{
	(void)description; (void)flags;
	activity_block();
}
#endif

__END_DECLS

/* The scope of the activity is the rest of the block: here, nothing. */
#define os_activity_scope(activity) ((void)(activity))

#endif /* __OS_ACTIVITY_H__ */
