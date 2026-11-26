/*
 * SPDX-License-Identifier: 0BSD
 *
 * libDER/DERItem.h -- minimal file written for the open SDK, used only for the
 * macOS releases whose xnu has no EXTERNAL_HEADERS/libDER.
 *
 * Security.framework's oids.h needs the DERItem type for its OID constants.
 * The types DERByte (uint8_t) and DERSize (size_t) and the struct {data,
 * length} are those of xnu/EXTERNAL_HEADERS/libDER/DERItem.h and libDER_config.h
 * (APSL 2.0, macOS 26.5), which the SDK of that release installs instead of this
 * file.  Nothing else of libDER is provided.
 */
#ifndef _LIB_DER_DERITEM_H_
#define _LIB_DER_DERITEM_H_
#include <stddef.h>
#include <stdint.h>
typedef uint8_t DERByte;
typedef size_t DERSize;
typedef struct {
    DERByte *data;
    DERSize length;
} DERItem;
#endif
