/*
 *  ZKMORLoggerCPP.cpp
 *  SycamoreLog
 *
 *  Created by Chandrasekhar Ramakrishnan on 16.08.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "ZKMORLoggerCPP.h"

//void show(CFStringRef formatString, ...) {
//	CFStringRef resultString;
//	CFDataRef data;
//	va_list argList;
//
//	va_start(argList, formatString);
//	resultString = CFStringCreateWithFormatAndArguments(NULL, NULL, formatString, argList);
//	va_end(argList);
//
//	data = CFStringCreateExternalRepresentation(NULL, resultString, kCFStringEncodingUTF8 , '?');
//
//	if (data != NULL) {
//		printf ("%.*s\n\n", (int)CFDataGetLength(data), CFDataGetBytePtr(data));
//		CFRelease(data);
//	 }
// 
//	CFRelease(resultString);
//}

#include "ZKMORLoggerCPP.h"
#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>

CFGregorianDate		ZKMORReadLogToken::GetGregorianDateInTimeZone(CFTimeZoneRef timeZone) const
{
	return CFAbsoluteTimeGetGregorianDate(time, timeZone);
}

int		ZKMORReadLogToken::SNPrintLogHeader(char * destStr, size_t strLen, CFTimeZoneRef timeZone) const
{
	int numPrinted = 0;
		// don't print a header for continues
	if (level & kZKMORLogLevel_Continue) return numPrinted;
	
	numPrinted += SNPrintLogLevel(&destStr[numPrinted], (strLen - numPrinted));
	numPrinted += SNPrintTimeHeader(&destStr[numPrinted], (strLen - numPrinted), timeZone);
	numPrinted += snprintf(&destStr[numPrinted], (strLen - numPrinted), " [");
	numPrinted += SNPrintLogSource(&destStr[numPrinted], (strLen - numPrinted));
	numPrinted += snprintf(&destStr[numPrinted], (strLen - numPrinted), " ]");	
	numPrinted += snprintf(&destStr[numPrinted], (strLen - numPrinted), ": ");	
	return numPrinted;
}

int		ZKMORReadLogToken::SNPrintTimeHeader(char * destStr, size_t strLen, CFTimeZoneRef timeZone) const
{
	CFGregorianDate	date = GetGregorianDateInTimeZone(timeZone);
	int numWritten = snprintf(destStr, strLen, "%li.%02hi.%02hi %02hi:%02hi:%06.3f", date.year, date.month, date.day, date.hour, date.minute, date.second);
	return numWritten;
}

int		ZKMORReadLogToken::SNPrintLogLevel(char * destStr, size_t strLen) const
{
	int numWritten = 0;
		// the ordered levels
	if (level <= kZKMORLogLevel_Error)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), "ERROR   ");
	else if (level <= kZKMORLogLevel_Warning)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), "Warning ");
	else if (level <= kZKMORLogLevel_Info)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), "Info    ");
			
	if (level & kZKMORLogLevel_Debug)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), "DEBUG   ");
	else if (	!(level & kZKMORLogLevel_Error) &&
				!(level & kZKMORLogLevel_Warning) &&
				!(level & kZKMORLogLevel_Info))
		// if the level doesn't match one of the pre-defined levels, print something to identify it
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), "0x%x ", level);
			
	return numWritten;
}

int		ZKMORReadLogToken::SNPrintLogSource(char * destStr, size_t strLen) const
{
	int numWritten = 0;
	if (source & kZKMORLogSource_Irrelevant) return numWritten;	
	if (source & kZKMORLogSource_Conduit)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " Conduit");
	if (source & kZKMORLogSource_AudioUnit)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " AudioUnit");
	if (source & kZKMORLogSource_Graph)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " Graph");
	if (source & kZKMORLogSource_GUI)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " GUI");
	if (source & kZKMORLogSource_Clock)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " Clock");
	if (source & kZKMORLogSource_Scheduler)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " Sched");
	if (source & kZKMORLogSource_Panner)
		numWritten += snprintf(&destStr[numWritten], (strLen - numWritten), " Panner");	
	return numWritten;
}

int		ZKMORReadLogToken::FPrint(FILE* file, CFTimeZoneRef timeZone) const
{
	int numWritten = 0;
	if (!(level & kZKMORLogLevel_Continue)) {
		char header[255];
		SNPrintLogHeader(header, 255, timeZone);
		numWritten += fprintf(file, "%s", header);
	}
//	numWritten += fprintf(file, logString);
	CFDataRef data = 
		CFStringCreateExternalRepresentation(NULL, logString, kCFStringEncodingUTF8 , '?');
	if (data != NULL) {
		numWritten += fprintf(file, "%.*s\n", (int)CFDataGetLength(data), CFDataGetBytePtr(data));
		CFRelease(data);
	}
	return numWritten;
}

void	ZKMORWriteLogToken::UpdateTimeOfDay()
{
	time = CFAbsoluteTimeGetCurrent();
}

void	ZKMORWriteLogToken::CreateLogString()
{
	logString = CFStringCreateMutable(kCFAllocatorDefault, logStringMaxLength);
}

void	ZKMORWriteLogToken::ReleaseLogString() { CFRelease(logString); }

int		ZKMORWriteLogToken::Log(unsigned level, unsigned source, CFStringRef format, ...)
{
	va_list argList;
	va_start(argList, format);
	int numWritten = Logv(level, source, format, argList);
	va_end(argList);
	return numWritten;
}

int		ZKMORWriteLogToken::Logv(unsigned aLevel, unsigned aSource, CFStringRef format, va_list args)
{
	level = aLevel;
	source = aSource;
	CFStringDelete(logString, CFRangeMake(0, CFStringGetLength(logString)));
	CFStringAppendFormatAndArguments(logString, NULL, format, args);
		// track the buffer position for ContinueLog
	int numWritten = CFStringGetLength(logString);
	mBufferPosition = numWritten;
	
	return numWritten;
}

int		ZKMORWriteLogToken::ContinueLog(CFStringRef format, ...)
{
	va_list argList;
	va_start(argList, format);
	int numWritten = ContinueLogv(format, argList);
	va_end(argList);
	return numWritten;
}

int		ZKMORWriteLogToken::ContinueLogv(CFStringRef format, va_list args)
{
	unsigned bufferPos = mBufferPosition;
	int maxLen = (int) (logStringMaxLength - bufferPos);
	if (maxLen < 1)	return 0;
	
	CFStringAppendFormatAndArguments(logString, NULL, format, args);
	mBufferPosition = CFStringGetLength(logString);
	int numWritten = mBufferPosition - bufferPos;
	return numWritten;
}

void	ZKMORLogger::Logv(unsigned level, unsigned source, CFStringRef format, va_list args)
{
	ZKMORWriteLogToken* item = GetWriteLogToken(level);
	if (item) {
		item->Logv(level, source, format, args);
		ReturnWriteLogToken(item);
	}
}

void					ZKMORLogger::BeginReading() { mTokens.BeginReading(); }
ZKMORReadLogToken*		ZKMORLogger::GetReadLogToken() { return mTokens.GetReadItem(); }
void					ZKMORLogger::ReturnReadLogToken(ZKMORReadLogToken* token)
{
	mTokens.ReturnReadItem(static_cast<ZKMORWriteLogToken*>(token));
}

void					ZKMORLogger::EndReading() { mTokens.EndReading(); }

ZKMORWriteLogToken*		ZKMORLogger::GetWriteLogToken(unsigned level)
{
	// don't return anything if logging is off
	if (!mIsLogging) return NULL;
	// don't return anything if the level is too high
	if (level > GetLogLevel()) return NULL;
	
	ZKMORWriteLogToken* logItem = mTokens.GetWriteItem();
	if (logItem) logItem->UpdateTimeOfDay();
	return logItem;
}

void					ZKMORLogger::ReturnWriteLogToken(ZKMORWriteLogToken* token)
{
	mTokens.ReturnWrittenItem(token);
	if (mNotifyFunction != NULL)
		mNotifyFunction(mNotifyRefCon, this);
}

void	ZKMORLogger::CreateLogStrings()
{
	unsigned i, numTokens = mTokens.BufferSize();
	ZKMORWriteLogToken* tokens = mTokens.AllItemsNA();
	
	for (i = 0; i < numTokens; i++) {
		tokens[i].SetLogStringMaxLength(mLogStringMaxLength);
	}
	mTokens.FinishInitializing();
}
