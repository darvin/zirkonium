//
//  ZKMORLogger.h
//  SycamoreLog
//
//  Created by Chandrasekhar Ramakrishnan on 16.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  A realtime-friendly logger.
//
//  This file defines the C interface to the logger. The actual implementation 
//  is done in C++, but log tokens can be created in pure C. To read and process
//  process log tokens, you need to use C++ or Objective-C++. See ZKMORLoggerCPP.h
//  and ZKMORLoggerTest.h
//

#ifndef __ZKMORLogger_h__
#define __ZKMORLogger_h__
#include <CoreFoundation/CoreFoundation.h>
#include <sys/time.h>
#include <stdarg.h>

#if defined(__cplusplus)
extern "C" {
#endif

///
///  ZKMORLogLevel
/// 
///  Various different levels of logging -- these may be or-ed together:
///
///		--	Use continue to extend logging from previous line (bypasses
///			printing the lead-in time, etc. info)
///		--	There are gaps between the levels to let you define your own
///			intermediate logging levels. Everything less than kZKMORLogLevel_Error
///			is considered an error, etc.
///		--	Error, Warning, Info, and Debug make up the "ordered levels"; continue and
///			debug have no implicit ordering
///
enum 
{
	kZKMORLogLevel_Continue		= (1L << 0),
	kZKMORLogLevel_Error		= (1L << 8),
	kZKMORLogLevel_Warning		= (1L << 16),	
	kZKMORLogLevel_Info			= (1L << 24),
	kZKMORLogLevel_Debug		= (1L << 31)
};

///
///  ZKMORLogSource
/// 
///  Different sources that caused the logging -- you can define your own, too.
///  These can be or-ed together.
///
enum 
{
	kZKMORLogSource_Hardware		= (1L << 0),
	kZKMORLogSource_Conduit			= (1L << 1),
	kZKMORLogSource_AudioUnit		= (1L << 2),
	kZKMORLogSource_Graph			= (1L << 3),
	kZKMORLogSource_Zone			= (1L << 4),
	kZKMORLogSource_GUI				= (1L << 5),
	kZKMORLogSource_Clock			= (1L << 6),
	kZKMORLogSource_Scheduler		= (1L << 7),
	kZKMORLogSource_Panner			= (1L << 8),
	kZKMORLogSource_Irrelevant		= (1L << 31)
};

///
///  ZKMORLogToken
/// 
///  The information to be logged, in struct form.
///
typedef struct ZKMORLogTokenStruct 
{
	CFAbsoluteTime		time;
	unsigned			level;
	unsigned			source;
	unsigned			logStringMaxLength;
	CFMutableStringRef	logString;
} ZKMORLogToken;

///
///  Initialization -- these wipe out any previously logged information
///
///  Sets the number of tokens that can be stored is set (MUST be a power of 2) and
///  all tokens are initialized to accept up to maxLength characters
///
///  If the number of tokens is exceed, new elements are dropped on the floor,
///  until the old ones are read.
///
void ZKMORLogInitLogger(unsigned bufferSize, unsigned maxLength);

///
///  Logger Control (0 is false, 1 is true)
///
int			ZKMORLoggerIsLogging();
void		ZKMORLoggerSetIsLogging(int isLoggerOn);
unsigned	ZKMORLoggerGetLogLevel();
void		ZKMORLoggerSetLogLevel(unsigned level);

///
///  Logging
///  
void ZKMORLog(unsigned level, unsigned source, CFStringRef format, ...);
void ZKMORLogv(unsigned level, unsigned source, CFStringRef format, va_list args);

///  
///  Convenience Functions/Defines
///
void ZKMORLogErrorWithSourceInfo(unsigned source, const char* fileName, int lineNumber, CFStringRef format, ...);
void ZKMORLogDebug(CFStringRef format, ...);

#define ZKMORLogError(source, format, ...) \
do { \
	ZKMORLogErrorWithSourceInfo(source, __FILE__, __LINE__, format, ##__VA_ARGS__); \
} while(0)

#if defined(__cplusplus)
}
#endif

#if defined(__cplusplus)

///
///  Returns the Global Logger used by the log functions
///
class ZKMORLogger;
ZKMORLogger*	GlobalLogger();
//extern ZKMORLogger* __attribute__((visibility ("default"))) gLogger;
//extern ZKMORLogger* gLogger;

#endif

#endif // __ZKMORLogger_h__
