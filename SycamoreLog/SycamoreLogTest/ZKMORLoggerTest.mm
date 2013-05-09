//
//  ZKMORLoggerTest.m
//  SycamoreLog
//
//  Created by Chandrasekhar Ramakrishnan on 16.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORLoggerTest.h"
#import "ZKMORLoggerCPP.h"


@implementation ZKMORLoggerTest

- (void)setUp
{
	tz = CFTimeZoneCopyDefault();
}

- (void)tearDown
{
	CFRelease(tz);
}

- (void)clearLogger
{
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;
	
	while (token = logger->GetReadLogToken()) {
		token->FPrint(stdout, tz);
		logger->ReturnReadLogToken(token);
	}
}

- (void)testLogging
{
	// set up
	[self clearLogger];
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Error);
	
	// log something
	ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_Irrelevant, (CFStringRef) @"Test of the logger");

	// read from the logger
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;
	BOOL hasToken = NO;
	unsigned numberOfTokens = 0;
	CFIndex length;

	logger->BeginReading();
	while (token = logger->GetReadLogToken()) {
		hasToken = YES;
		numberOfTokens++;
		length = CFStringGetLength(token->logString);
		logger->ReturnReadLogToken(token);
	}
	logger->EndReading();
	
	STAssertTrue(hasToken, @"Loging should create a token");
	STAssertTrue(1 == numberOfTokens, @"Loging once should create exactly one token, not %u tokens", numberOfTokens);
	STAssertTrue(18 == length, @"Length was %i", length);
	
	// tear down
	ZKMORLoggerSetIsLogging(NO);
}


- (void)testNotLogging
{
	// set up
	[self clearLogger];
	ZKMORLoggerSetIsLogging(NO);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Error);
	
	// log something
//	ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_Irrelevant, "Test of the logger");
	
	// read from the logger
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;
	BOOL hasToken = NO;
	unsigned numberOfTokens = 0;

	logger->BeginReading();
	while (token = logger->GetReadLogToken()) {
		hasToken = YES;
		numberOfTokens++;
		logger->ReturnReadLogToken(token);
	}
	logger->EndReading();
	
	STAssertFalse(hasToken, @"Loging with logger off should not create any token");
	
	// tear down
	ZKMORLoggerSetIsLogging(NO);
}

- (void)testWraparound
{
	// set up
	[self clearLogger];
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Error);

	ZKMORLogger* logger = GlobalLogger();	
	unsigned i;
	for (i = 0; i < 128; i++) {
		// log something
		CFStringRef string = CFStringCreateWithFormat(NULL, NULL, CFSTR("Test %u"), i);
		ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_Irrelevant, string);

		// read from the logger
		ZKMORReadLogToken* token;
		BOOL hasToken = NO;
		unsigned numberOfTokens = 0;
		CFIndex length;

		logger->BeginReading();
		while (token = logger->GetReadLogToken()) {
			hasToken = YES;
			numberOfTokens++;
			length = CFStringGetLength(token->logString);
			logger->ReturnReadLogToken(token);
		}
		logger->EndReading();
	
		STAssertTrue(hasToken, @"Loging should create a token in iteration %u", i);
		STAssertTrue(1 == numberOfTokens, @"Loging once should create exactly one token in iteration %u", i);
		STAssertTrue(CFStringGetLength(string) == length, @"Length was %i", length);
		CFRelease(string);
	}
	
	// tear down
	ZKMORLoggerSetIsLogging(NO);
}


@end
