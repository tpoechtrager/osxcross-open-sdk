/*
 * SPDX-License-Identifier: 0BSD
 *
 * TargetConditionals.h -- target description macros for macOS.
 *
 * Written for the osxcross open SDK.  CarbonHeaders-18.1 has an old
 * TargetConditionals.h without the macros of the current systems, and the
 * one in CF is for Linux only.  This one only describes macOS targets and
 * derives the CPU from compiler predefined macros.  The names are those of
 * CarbonHeaders/TargetConditionals.h (TARGET_CPU_*, TARGET_RT_*,
 * TARGET_OS_MAC, ...) and of macros that open source projects use
 * (TARGET_OS_OSX, TARGET_OS_IOS, TARGET_OS_SIMULATOR, TARGET_OS_MACCATALYST,
 * TARGET_OS_XR, TARGET_OS_DRIVERKIT, TARGET_OS_LINUX in dyld, CF, Security,
 * libmalloc, xnu, mDNSResponder, objc4); a macro that no open source file
 * names is not defined.
 */
#ifndef __TARGETCONDITIONALS__
#define __TARGETCONDITIONALS__

/* operating system */
#define TARGET_OS_MAC            1
#define TARGET_OS_WIN32          0
#define TARGET_OS_UNIX           0
#define TARGET_OS_LINUX          0
#define TARGET_OS_OSX            1
#define TARGET_OS_IPHONE         0
#define TARGET_OS_IOS            0
#define TARGET_OS_WATCH          0
#define TARGET_OS_TV             0
#define TARGET_OS_MACCATALYST    0
#define TARGET_OS_SIMULATOR      0
#define TARGET_OS_VISION         0
#define TARGET_OS_XR             0
#define TARGET_OS_DRIVERKIT      0
#define TARGET_OS_EXCLAVEKIT     0
#define TARGET_OS_BRIDGE         0
#define TARGET_OS_EMBEDDED       0
#define TARGET_IPHONE_SIMULATOR  TARGET_OS_SIMULATOR

/* CPU */
#define TARGET_CPU_PPC           0
#define TARGET_CPU_PPC64         0
#define TARGET_CPU_68K           0
#define TARGET_CPU_MIPS          0
#define TARGET_CPU_SPARC         0
#define TARGET_CPU_ALPHA         0
#if defined(__x86_64__)
#define TARGET_CPU_X86           0
#define TARGET_CPU_X86_64        1
#define TARGET_CPU_ARM           0
#define TARGET_CPU_ARM64         0
#define TARGET_RT_64_BIT         1
#elif defined(__i386__)
#define TARGET_CPU_X86           1
#define TARGET_CPU_X86_64        0
#define TARGET_CPU_ARM           0
#define TARGET_CPU_ARM64         0
#define TARGET_RT_64_BIT         0
#elif defined(__arm64__) || defined(__aarch64__)
#define TARGET_CPU_X86           0
#define TARGET_CPU_X86_64        0
#define TARGET_CPU_ARM           0
#define TARGET_CPU_ARM64         1
#define TARGET_RT_64_BIT         1
#elif defined(__arm__)
#define TARGET_CPU_X86           0
#define TARGET_CPU_X86_64        0
#define TARGET_CPU_ARM           1
#define TARGET_CPU_ARM64         0
#define TARGET_RT_64_BIT         0
#else
#error unsupported target CPU
#endif

/* runtime */
#define TARGET_RT_LITTLE_ENDIAN  1
#define TARGET_RT_BIG_ENDIAN     0
#define TARGET_RT_MAC_CFM        0
#define TARGET_RT_MAC_MACHO      1

#endif /* __TARGETCONDITIONALS__ */
