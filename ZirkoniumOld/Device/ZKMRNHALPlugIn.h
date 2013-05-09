/*
 *  ZKMRNHALPlugIn.h
 *  Zirkonium
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __ZKMRNPlugIn_H__
#define __ZKMRNPlugIn_H__

#include "ZKMORHALPlugIn.h"

#ifdef __cplusplus
extern "C" {
#endif

// Forward declaration for the IUnknown implementation.
void				ZKMRNDeallocPlugIn(ZKMORHALPlugIn *obj);
ZKMORHALPlugIn*		ZKMRNAllocPlugIn(CFUUIDRef factoryID);
	// the function declared in Info.plist
void*				ZKMRNPlugInFactory(CFAllocatorRef allocator, CFUUIDRef typeID);

Boolean				HasBundleID();
Boolean				IsRunningInZirkonium();
Boolean				IsZirkoniumReachable();

#ifdef __cplusplus
}
#endif

#endif