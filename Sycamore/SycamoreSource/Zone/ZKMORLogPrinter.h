//
//  ZKMORLogPrinter.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 05.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORLogPrinter_h__
#define __ZKMORLogPrinter_h__

#include "ZKMORLogger.h"

#ifdef __cplusplus
extern "C" {
#endif

	/// Print all current tokens to stdout/stderr in the thread that calls this method.
void	ZKMORLogPrinterFlush();

	/// Discards all current tokens in the thread that calls this method
void	ZKMORLogPrinterClear();

	/// Start logging to stdout/stderr
void	ZKMORLogPrinterStart();

	/// Stop logging to stdout/stderr
void	ZKMORLogPrinterStop();

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

#include "ZKMORZone.h"

///
///  ZKMORLogPrinter
///
///  Prints ZKMORLog log messages to stdout/stderr. 
/// 
class ZKMORLogPrinter : public ZKMORFileZoneObject {
public:

//  Accessors
		/// Get the singleton log printer
	static ZKMORLogPrinter*	GetLogPrinter();

//  Control	
		/// Start logging to stdout/stderr
	void	StartLogging();
		/// Stop logging to stdout/stderr
	void	StopLogging();
		/// Print all current tokens to stdout/stderr
	void	Flush();
		/// Discards all current tokens
	void	Clear();

//  Internal	
	static void	LogPrinterNotifyFunction(void* refCon, ZKMORLogger* logger);
	
protected:
		/// Called by the worker thread -- runs one iteration in the worker thread
	void	RunIteration();

private:
	//  CTOR
		/// Don't construct this object, use the GetLogPrinter method to get the singleton printer.
	ZKMORLogPrinter();
	~ZKMORLogPrinter();
	
	static ZKMORLogPrinter*	sLogPrinter;
	
	CFTimeZoneRef	mTimeZone;
	CAGuard			mMutex;	
};
#endif

#endif // __ZKMORLogPrinter_h__
