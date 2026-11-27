/*
 * SPDX-License-Identifier: 0BSD
 *
 * CoreServices/FSEvents.h -- file system event streams.
 *
 * Written for the osxcross open SDK; not taken from any other header.
 * CoreServices has no open source release.  Every name and value here has
 * a public source, listed in docs/SOURCES.md and
 * data/symbols/CoreServices-fsevents.txt of the generator:
 *   - the functions, types, the fields of FSEventStreamContext, the
 *     constants and the macOS release that brought each of them: Apple's
 *     documentation of File System Events
 *     (developer.apple.com/documentation/coreservices/file_system_events,
 *     the C declaration of every name);
 *   - the values of the flags and of kFSEventStreamEventIdSinceNow, the
 *     order of the fields of FSEventStreamContext and the flags that the
 *     documentation does not list (kFSEventStreamCreateFlagUseExtendedData,
 *     kFSEventStreamCreateFlagFullHistory, kFSEventStreamEventFlagItemCloned):
 *     fsevent-sys of github.com/octplane/fsevent-rust, src/fsevent.rs
 *     (MIT), and dotnet/macios, src/CoreServices/FSEvents.cs (MIT); libuv,
 *     src/unix/darwin-stub.h (MIT), has part of them;
 *   - the strings of the keys of the extended data: dotnet/macios.
 * A flag that has no C name in these sources is left out.
 */
#ifndef _CORESERVICES_FSEVENTS_H_
#define _CORESERVICES_FSEVENTS_H_

#include <sys/cdefs.h>
#include <sys/types.h>
#include <stddef.h>
#include <os/availability.h>
#include <dispatch/dispatch.h>
#include <CoreFoundation/CoreFoundation.h>

__BEGIN_DECLS

typedef struct __FSEventStream *FSEventStreamRef;
typedef const struct __FSEventStream *ConstFSEventStreamRef;

typedef UInt32 FSEventStreamCreateFlags;
typedef UInt32 FSEventStreamEventFlags;
typedef UInt64 FSEventStreamEventId;

typedef struct FSEventStreamContext {
  CFIndex version;
  void *info;
  CFAllocatorRetainCallBack retain;
  CFAllocatorReleaseCallBack release;
  CFAllocatorCopyDescriptionCallBack copyDescription;
} FSEventStreamContext;

typedef void (*FSEventStreamCallback)(ConstFSEventStreamRef streamRef, void *clientCallBackInfo,
                                      size_t numEvents, void *eventPaths,
                                      const FSEventStreamEventFlags *eventFlags,
                                      const FSEventStreamEventId *eventIds);

/* flags of FSEventStreamCreate */
enum {
  kFSEventStreamCreateFlagNone            = 0x00000000,
  kFSEventStreamCreateFlagUseCFTypes      = 0x00000001,
  kFSEventStreamCreateFlagNoDefer         = 0x00000002,
  kFSEventStreamCreateFlagWatchRoot       = 0x00000004,
  kFSEventStreamCreateFlagIgnoreSelf      = 0x00000008,  /* macOS 10.6 */
  kFSEventStreamCreateFlagFileEvents      = 0x00000010,  /* macOS 10.7 */
  kFSEventStreamCreateFlagMarkSelf        = 0x00000020,  /* macOS 10.9 */
  kFSEventStreamCreateFlagUseExtendedData = 0x00000040,
  kFSEventStreamCreateFlagFullHistory     = 0x00000080
};

/* flags of an event */
enum {
  kFSEventStreamEventFlagNone               = 0x00000000,
  kFSEventStreamEventFlagMustScanSubDirs    = 0x00000001,
  kFSEventStreamEventFlagUserDropped        = 0x00000002,
  kFSEventStreamEventFlagKernelDropped      = 0x00000004,
  kFSEventStreamEventFlagEventIdsWrapped    = 0x00000008,
  kFSEventStreamEventFlagHistoryDone        = 0x00000010,
  kFSEventStreamEventFlagRootChanged        = 0x00000020,
  kFSEventStreamEventFlagMount              = 0x00000040,
  kFSEventStreamEventFlagUnmount            = 0x00000080,
  kFSEventStreamEventFlagItemCreated        = 0x00000100,  /* the Item flags: macOS 10.7 */
  kFSEventStreamEventFlagItemRemoved        = 0x00000200,
  kFSEventStreamEventFlagItemInodeMetaMod   = 0x00000400,
  kFSEventStreamEventFlagItemRenamed        = 0x00000800,
  kFSEventStreamEventFlagItemModified       = 0x00001000,
  kFSEventStreamEventFlagItemFinderInfoMod  = 0x00002000,
  kFSEventStreamEventFlagItemChangeOwner    = 0x00004000,
  kFSEventStreamEventFlagItemXattrMod       = 0x00008000,
  kFSEventStreamEventFlagItemIsFile         = 0x00010000,
  kFSEventStreamEventFlagItemIsDir          = 0x00020000,
  kFSEventStreamEventFlagItemIsSymlink      = 0x00040000,
  kFSEventStreamEventFlagOwnEvent           = 0x00080000,  /* macOS 10.9 */
  kFSEventStreamEventFlagItemIsHardlink     = 0x00100000,  /* macOS 10.10 */
  kFSEventStreamEventFlagItemIsLastHardlink = 0x00200000,  /* macOS 10.10 */
  kFSEventStreamEventFlagItemCloned         = 0x00400000
};

/* sinceWhen of FSEventStreamCreate: only events from now on */
enum {
  kFSEventStreamEventIdSinceNow = 0xFFFFFFFFFFFFFFFFULL
};

/* the keys of the dictionary of an event (kFSEventStreamCreateFlagUseExtendedData), macOS 10.13 */
#define kFSEventStreamEventExtendedDataPathKey CFSTR("path")
#define kFSEventStreamEventExtendedFileIDKey   CFSTR("fileID")

/* Streams */

FSEventStreamRef FSEventStreamCreate(CFAllocatorRef allocator, FSEventStreamCallback callback,
    FSEventStreamContext *context, CFArrayRef pathsToWatch, FSEventStreamEventId sinceWhen,
    CFTimeInterval latency, FSEventStreamCreateFlags flags) API_AVAILABLE(macos(10.5));
FSEventStreamRef FSEventStreamCreateRelativeToDevice(CFAllocatorRef allocator, FSEventStreamCallback callback,
    FSEventStreamContext *context, dev_t deviceToWatch, CFArrayRef pathsToWatchRelativeToDevice,
    FSEventStreamEventId sinceWhen, CFTimeInterval latency, FSEventStreamCreateFlags flags) API_AVAILABLE(macos(10.5));
void FSEventStreamRetain(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
void FSEventStreamRelease(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));

FSEventStreamEventId FSEventStreamGetLatestEventId(ConstFSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
dev_t FSEventStreamGetDeviceBeingWatched(ConstFSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
CFArrayRef FSEventStreamCopyPathsBeingWatched(ConstFSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
CFStringRef FSEventStreamCopyDescription(ConstFSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
void FSEventStreamShow(ConstFSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));

void FSEventStreamScheduleWithRunLoop(FSEventStreamRef streamRef, CFRunLoopRef runLoop, CFStringRef runLoopMode)
    API_DEPRECATED("use FSEventStreamSetDispatchQueue", macos(10.5, 13.0));
void FSEventStreamUnscheduleFromRunLoop(FSEventStreamRef streamRef, CFRunLoopRef runLoop, CFStringRef runLoopMode)
    API_DEPRECATED("use FSEventStreamSetDispatchQueue", macos(10.5, 13.0));
void FSEventStreamSetDispatchQueue(FSEventStreamRef streamRef, dispatch_queue_t q) API_AVAILABLE(macos(10.6));
Boolean FSEventStreamSetExclusionPaths(FSEventStreamRef streamRef, CFArrayRef pathsToExclude) API_AVAILABLE(macos(10.9));

Boolean FSEventStreamStart(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
FSEventStreamEventId FSEventStreamFlushAsync(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
void FSEventStreamFlushSync(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
void FSEventStreamStop(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));
void FSEventStreamInvalidate(FSEventStreamRef streamRef) API_AVAILABLE(macos(10.5));

/* Event ids and devices */

FSEventStreamEventId FSEventsGetCurrentEventId(void) API_AVAILABLE(macos(10.5));
FSEventStreamEventId FSEventsGetLastEventIdForDeviceBeforeTime(dev_t dev, CFAbsoluteTime time) API_AVAILABLE(macos(10.5));
Boolean FSEventsPurgeEventsForDeviceUpToEventId(dev_t dev, FSEventStreamEventId eventId) API_AVAILABLE(macos(10.5));
CFUUIDRef FSEventsCopyUUIDForDevice(dev_t dev) API_AVAILABLE(macos(10.5));

__END_DECLS

#endif /* _CORESERVICES_FSEVENTS_H_ */
