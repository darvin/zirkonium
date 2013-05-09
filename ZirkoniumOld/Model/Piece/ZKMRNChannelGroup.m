//
//  ZKMRNChannelGroup.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 04.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNChannelGroup.h"
#import "ZKMRNGraphChannel.h"


@implementation ZKMRNChannelGroup

#pragma mark _____ Accessors
- (void)setName:(NSString *)name
{
	[self willChangeValueForKey: @"name"];
	[self willChangeValueForKey: @"displayString"];	
	[self setPrimitiveValue: name forKey: @"name"];
	[self setPrimitiveValue: nil forKey: @"displayString"];
	[self didChangeValueForKey: @"name"];
	[self didChangeValueForKey: @"displayString"];
}

- (NSString *)displayString
{
	[self willAccessValueForKey: @"displayString"];
	NSString* displayString = [self primitiveValueForKey: @"displayString"];
	[self didAccessValueForKey: @"displayString"];
	
	if (!displayString) {
		displayString = [NSString stringWithFormat: @"%@", [self valueForKey: @"name"]];
		[self setPrimitiveValue: displayString forKey: @"displayString"];
	}

	return displayString;
}

- (NSArray *)pannerSources 
{ 
	NSEnumerator* channels = [[self valueForKey: @"channels"] objectEnumerator];
	ZKMRNGraphChannel* channel;
	NSMutableArray* sources = [NSMutableArray array];
	while (channel = [channels nextObject]) {
		[sources addObject: [channel pannerSource]];
	}
	return sources;
}

@end
