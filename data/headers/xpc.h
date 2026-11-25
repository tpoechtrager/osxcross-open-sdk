/*
 * SPDX-License-Identifier: 0BSD
 *
 * xpc/xpc.h -- minimal file written for the open SDK.
 *
 * libxpc is not part of any open source release.  Security.framework's
 * SecCode.h only needs the object type for one prototype.  The typedef is
 * the line that xnu's libkern/os/trace.h (line 36) writes for the case that
 * <xpc/xpc.h> does not exist.  Nothing else of XPC is declared here and no
 * libxpc stub is provided.
 */
#ifndef __XPC_H__
#define __XPC_H__
typedef void *xpc_object_t;
#endif
