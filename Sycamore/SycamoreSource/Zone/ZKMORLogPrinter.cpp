//
//  ZKMORLogPrinter.cpp
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 05.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORLogPrinter.h"
#include "ZKMORLoggerCPP.h"

ZKMORLogPrinter* ZKMORLogPrinter::sLogPrinter = NULL;

void	ZKMORLogPrinterFlush()
{
	ZKMORLogPrinter* logPrinter = ZKMORLogPrinter::GetLogPrinter();
	logPrinter->Flush();
}

void ZKMORLogPrinterClear()
{
	ZKMORLogPrinter* logPrinter = ZKMORLogPrinter::GetLogPrinter();
	logPrinter->Clear();
}

void	ZKMORLogPrinterStart()
{
	ZKMORLogPrinter* logPrinter = ZKMORLogPrinter::GetLogPrinter();
	logPrinter->StartLogging();
}

void	ZKMORLogPrinterStop()
{
	ZKMORLogPrinter* logPrinter = ZKMORLogPrinter::GetLogPrinter();
	logPrinter->StopLogging();
}

ZKMORLogPrinter*	ZKMORLogPrinter::GetLogPrinter()
{
	if (sLogPrinter == NULL)
		sLogPrinter = new ZKMORLogPrinter();
	return sLogPrinter;
}

void	ZKMORLogPrinter::StartLogging()
{
	ZKMORLogger* logger = GlobalLogger();
	logger->SetNotifier(this, LogPrinterNotifyFunction);
}

void	ZKMORLogPrinter::StopLogging()
{
	ZKMORLogger* logger = GlobalLogger();
	logger->SetNotifier(NULL, NULL);
}
	
void	ZKMORLogPrinter::LogPrinterNotifyFunction(void* refCon, ZKMORLogger* logger)
{
	reinterpret_cast<ZKMORLogPrinter*>(refCon)->MarkNeedsToRun();
}

void	ZKMORLogPrinter::Flush()
{
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;

		// take the lock
	CAGuard::Locker lock(mMutex);
	logger->BeginReading();
	while (token = logger->GetReadLogToken()) {
		if (token->level <= kZKMORLogLevel_Warning)
			token->FPrint(stderr, mTimeZone);
		else
			token->FPrint(stdout, mTimeZone);
		logger->ReturnReadLogToken(token);
	}
	logger->EndReading();
	fflush(stdout); fflush(stderr);
	
		// CAGuard::Locker's destructor automatically releases the mutex
}

void	ZKMORLogPrinter::Clear()
{
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;
	
	logger->BeginReading();
	while (token = logger->GetReadLogToken()) {
		logger->ReturnReadLogToken(token);
	}
	logger->EndReading();
}
	
void	ZKMORLogPrinter::RunIteration()
{
	Flush();
}

ZKMORLogPrinter::ZKMORLogPrinter() : ZKMORFileZoneObject(), mMutex("Log Printer Guard")
{
	mTimeZone = CFTimeZoneCopyDefault();
}

ZKMORLogPrinter::~ZKMORLogPrinter()
{
	CFRelease(mTimeZone);
}
	
