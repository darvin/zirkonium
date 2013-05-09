//
//  ZKMORException.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 23.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORException_h__
#define __ZKMORException_h__

#import "ZKMORCore.h"

ZKMOR_C_BEGIN

///
///  Exception Names
/// 
///  Sycamore Exception names
///  
extern NSString* const ConduitError;
extern NSString* const GraphError;
extern NSString* const AudioUnitError;
extern NSString* const ClockError;

@interface NSException (ZKMORException)

- (NSString *)filename;
- (NSNumber *)lineNumber;

@end

NSException* ZKMORExceptionWithSourceInfo(	NSString*		name,
											id				thrower,
											const char*		fileName,
											int				lineNumber,
											NSString*		format,
											...);

#define ZKMORThrow(name, format, ...) \
do { \
	NSException* __myException = ZKMORExceptionWithSourceInfo(name, self, __FILE__, __LINE__, format, ##__VA_ARGS__); \
	@throw __myException; \
} while(0)

ZKMOR_C_END

#endif __ZKMORException_h__