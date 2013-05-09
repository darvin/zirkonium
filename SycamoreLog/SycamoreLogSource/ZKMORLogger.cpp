//
//  ZKMORLoggerC.m
//  SycamoreLog
//
//  Created by Chandrasekhar Ramakrishnan on 16.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#include "ZKMORLogger.h"
#include "ZKMORLoggerCPP.h"


static ZKMORLogger* gLogger = NULL;

ZKMORLogger *	GlobalLogger() 
{ 
	if (!gLogger) {
		gLogger = new ZKMORLogger(512, 512);
	}
	return gLogger; 
}

void ZKMORLogInitLogger(unsigned bufferSize, unsigned maxLength)
{
	ZKMORLogger* theNewLogger = new ZKMORLogger(bufferSize, maxLength);
	ZKMORLogger* oldLogger = gLogger;
	gLogger = theNewLogger;
	if (oldLogger) {
		gLogger->SetLogLevel(oldLogger->GetLogLevel());
		delete oldLogger;
	}
}

void ZKMORLog(unsigned level, unsigned source, CFStringRef format, ...)
{
	va_list argList;
	va_start(argList, format);
	ZKMORLogv(level, source, format, argList);
	va_end(argList);
}

void ZKMORLogv(unsigned level, unsigned source, CFStringRef format, va_list args)
{
	GlobalLogger()->Logv(level, source, format, args);
}

void ZKMORLogErrorWithSourceInfo(unsigned source, const char* fileName, int lineNumber, CFStringRef format, ...)
{
	ZKMORWriteLogToken* token = GlobalLogger()->GetWriteLogToken(kZKMORLogLevel_Error);
	va_list argList;
	va_start(argList, format);
	if (token) {
		token->Log(kZKMORLogLevel_Error, source, CFSTR("File %s line %i:\n\t"), fileName, lineNumber);
		token->ContinueLogv(format, argList);
		GlobalLogger()->ReturnWriteLogToken(token);
	}
	va_end(argList);
}

void ZKMORLogDebug(CFStringRef format, ...) 
{
	va_list argList;
	va_start(argList, format);
	ZKMORLogv(kZKMORLogLevel_Debug, kZKMORLogSource_Irrelevant, format, argList);
	va_end(argList);	
}

int			ZKMORLoggerIsLogging() { return GlobalLogger()->IsLogging(); }
void		ZKMORLoggerSetIsLogging(int isLogging) { GlobalLogger()->SetIsLogging(isLogging); }
unsigned	ZKMORLoggerGetLogLevel() { return GlobalLogger()->GetLogLevel(); }
void		ZKMORLoggerSetLogLevel(unsigned level) { GlobalLogger()->SetLogLevel(level); }
