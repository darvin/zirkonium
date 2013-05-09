//
//  ZKMORCore.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORCore.h"
#include "ZKMORLogger.h"


@implementation NSObject (ZKMORLogging)

- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(level, source, CFSTR("%@%s%@"), tag, indentStr, self);
}

- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent
{
	[self logAtLevel: level source: source indent: indent tag: @""];
}

- (void)logDebug
{
	[self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Irrelevant indent: 0 tag: @""];
}

@end
