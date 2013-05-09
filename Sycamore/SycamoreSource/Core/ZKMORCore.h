//
//  ZKMORCore.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  Things used everywhere in Sycamore.
//

#ifndef __ZKMORCore_h__
#define __ZKMORCore_h__

#ifdef __cplusplus
#  define ZKMOR_C_BEGIN extern "C" {
#  define ZKMOR_C_END   }
#  define ZKMCPPT(objtype) objtype*
#  define ZKMDECLCPPT(decl) class decl;
#else
#  define ZKMOR_C_BEGIN
#  define ZKMOR_C_END
#  define ZKMCPPT(objtype) void*
#  define ZKMDECLCPPT(decl) 
#endif


#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
	
///
///  ZKMORLogging
///
///  Logging functions that use the ZKMORLogger
///
@interface NSObject (ZKMORLogging)

- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag;
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent;
- (void)logDebug;

@end
#endif

#endif __ZKMORCore_h__