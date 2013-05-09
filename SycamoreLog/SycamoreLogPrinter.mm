//
//  SycamoreLogPrinter.mm
//  SycamoreLog
//
//  Created by Chandrasekhar Ramakrishnan on 16.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "SycamoreLogPrinter.h"
#include "ZKMORLoggerCPP.h"

static void MyLoggerNotifyFunction(void* refCon, ZKMORLogger* logger)
{
	SycamoreLogPrinter* SELF = (SycamoreLogPrinter*)refCon;
	[SELF printAvailableTokens];
}

@implementation SycamoreLogPrinter

- (void)dealloc
{
	ZKMORLogger* logger = GlobalLogger();
	logger->SetNotifier(NULL, NULL);
	CFRelease(tz);
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;
	tz = CFTimeZoneCopyDefault();
	ZKMORLogger* logger = GlobalLogger();
	logger->SetNotifier(self, MyLoggerNotifyFunction);
	return self;
}

- (void)printAvailableTokens
{
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;

	logger->BeginReading();
	while (token = logger->GetReadLogToken()) {
		token->FPrint(stdout, tz);
		logger->ReturnReadLogToken(token);
	}
	logger->EndReading();
}

@end
