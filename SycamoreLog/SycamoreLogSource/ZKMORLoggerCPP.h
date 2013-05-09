/*
 *  ZKMORLoggerCPP.h
 *  SycamoreLog
 *
 *  Created by Chandrasekhar Ramakrishnan on 16.08.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 *  Implementation of the logger defined in ZKMORLogger.h
 *
 *  The CPP interface provides some additional niceties, so some
 *  clients may want to use the CPP interface directly (which is allowed).
 *
 */

#ifndef __ZKMORLoggerCPP_h__
#define __ZKMORLoggerCPP_h__

#include "ZKMORLogger.h"
//#include "CAAtomicStack.h"
#include "ZKMMPQueue.h"
#include <stdlib.h>

// Logger Objects should be globally visible
#pragma GCC visibility push(default)
///
///  Notifications
///
///  When the logger receives a new token, the notification function is called.
///  The implementation of the notification should be realtime safe (e.g., take no
///  locks, etc.).
///
typedef void (*ZKMORLoggerNotifyFunction)(void* refCon, ZKMORLogger* logger);

///
///  ZKMORReadLogToken
/// 
///  ZKMORLogToken with some convenience functions for reading data from it
///
struct ZKMORReadLogToken : ZKMORLogToken
{

// Queries	
	bool IsContinue() const { return (kZKMORLogLevel_Continue & level); }
	
// Accessors
		// return the logged time as a CFGregorianDate
	CFGregorianDate		GetGregorianDateInTimeZone(CFTimeZoneRef timeZone) const;
	
// Printing
	int		SNPrintLogHeader(	char* destStr, size_t strLen, CFTimeZoneRef timeZone ) const;
	int		SNPrintTimeHeader(	char* destStr, size_t strLen, CFTimeZoneRef timeZone ) const;
	int		SNPrintLogLevel(	char* destStr, size_t strLen ) const;
	int		SNPrintLogSource(	char* destStr, size_t strLen ) const;
	
		///  To get a time zone (but don't forget to release it): 
		///		CFTimeZoneRef tz = CFTimeZoneCopyDefault();
		///		...
		///		CFRelease(tz);
	int		FPrint(FILE* file, CFTimeZoneRef timeZone) const;
};

///
///  ZKMORWriteLogToken
/// 
///  ZKMORLogToken with some convenience functions.
///
struct ZKMORWriteLogToken : ZKMORReadLogToken
{
	ZKMORWriteLogToken() : ZKMORReadLogToken() { logString = NULL; }
	~ZKMORWriteLogToken() { ReleaseLogString(); }

// Initialization	
	void	SetLogStringMaxLength(unsigned maxLength)
	{
		if (logString) ReleaseLogString();
		
		logStringMaxLength = maxLength;
		CreateLogString();
	}

// Logging -- these return the number of characters written to the buffer
	int		Log(unsigned aLevel, unsigned aSource, CFStringRef format, ...);	
	int		Logv(unsigned aLevel, unsigned aSource, CFStringRef format, va_list args);

	int		ContinueLog(CFStringRef format, ...);				///< for continuing previous log calls
	int		ContinueLogv(CFStringRef format, va_list args); 	///< for continuing previous log calls

// Actions		
	void	UpdateTimeOfDay();
	
// For TAtomicStack
	void					set_next(ZKMORWriteLogToken* next) { mNext = next; }
	ZKMORWriteLogToken*		get_next() { return mNext; }

protected:
	void	CreateLogString();
	void	ReleaseLogString();

// State for ContinueLog
	unsigned mBufferPosition;
	
// State for TAtomicStack
	ZKMORWriteLogToken*		mNext;
};

///
///  ZKMORLogger
/// 
///  A realtime-friendly (lock-free), thread-safe logger.
///
///  The C interface defined in ZKMORLogger is one way to interact with the logger,
///  but clients may use the C++ interface directly (accessed through GlobalLogger())
///  in certain situtations. This is particularily the case when logging info that may be expensive
///  to compute and should not be done if logging is off. For those cases, use the logger
///  in the following way:
///
///		ZKMORLogger* logger = GlobalLogger();
///		ZKMORWriteLogToken* token = (logger->GetWriteLogToken(kZKMORLogLevel_Warning))
///		if (token) {
///			token->Log(kZKMORLogLevel_Warning, kZKMORLogSource_Conduit,
///				CFSTR("There was this problem %i\n"), err);
///			token->ContinueLog(CFSTR("I don't know what to do about it"));
///			logger->ReturnWriteLogToken(token);
///		}
///
///  Reading logged tokens from the logger is similar:
///
///		ZKMORLogger* logger = GlobalLogger();
///		std::list<ZKMORReadLogToken *> allTokens;
///		ZKMORReadLogToken* token = logger->GetAllReadLogTokens()
///		if (!token) return; 
///		// re-sort the tokens
///		do {
///			allTokens.push_front(token);
///		} while (token = static_cast<ZKMORWriteLogToken*>(token)->get_next())
///		
///		// process the tokens
///		while (allTokens.size() > 0) {
///			token = allTokens.front();
///			allTokens.pop_front();
///			token->FPrint(stdout, tz);
///			logger->ReturnReadLogToken(token);
///		}
///
class ZKMORLogger
{
public:
	typedef TManagedQueue<ZKMORWriteLogToken>	TokenQueue;
	
	~ZKMORLogger() { }

	ZKMORLogger(unsigned bufferSize, unsigned maxLength) :
		mIsLogging(false),
		mBufferSize(bufferSize),
		mLogStringMaxLength(maxLength),
		mLogLevel(kZKMORLogLevel_Error),
		mTokens(bufferSize),
		mNotifyRefCon(NULL),
		mNotifyFunction(NULL)
	{
		CreateLogStrings();
	}
	
//  Accessors
	bool	IsLogging() { return mIsLogging; }
	void	SetIsLogging(bool isLogging) { mIsLogging = isLogging; }

		// always let continues through
	unsigned	GetLogLevel() { return mLogLevel | kZKMORLogLevel_Continue; }
	void		SetLogLevel(unsigned level) { mLogLevel = level; }

	// Notification
	void				SetNotifier(void* refCon, ZKMORLoggerNotifyFunction notifyFunc)
						{ 
							mNotifyRefCon = refCon;
							mNotifyFunction = notifyFunc; 
						}

//  Reading from the log
		/// To read from the log, you ask for all the read tokens, process them (in reverse
		/// order, since they are maintained in a stack) and return them as you are done with them.
	void					BeginReading();
	ZKMORReadLogToken*		GetReadLogToken();
	void					ReturnReadLogToken(ZKMORReadLogToken* token);
	void					EndReading();
	
//  Writing to the log
	void	Logv(unsigned level, unsigned source, CFStringRef format, va_list args);

		/// Can be used for expensive logging -- this function will return NULL if logging is off
		/// o.w., the expensive logging can be done (see above)
	ZKMORWriteLogToken*		GetWriteLogToken(unsigned level);
	void					ReturnWriteLogToken(ZKMORWriteLogToken* token);

protected:
// State
	bool				mIsLogging;
	unsigned			mBufferSize;
	unsigned			mLogStringMaxLength;
	unsigned			mLogLevel;
	
	TokenQueue			mTokens;
	
	void*						mNotifyRefCon;
	ZKMORLoggerNotifyFunction	mNotifyFunction;
	
// Internal Functions
	void	CreateLogStrings();
};
// Return to normal visibility
#pragma GCC visibility pop

#endif // __ZKMORLoggerCPP_h__
