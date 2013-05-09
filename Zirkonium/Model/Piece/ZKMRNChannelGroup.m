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

-(void)awakeFromInsert
{
	[super awakeFromInsert];
	_newGroup = true; 
}

#pragma mark _____ Accessors
- (void)setName:(NSString *)name
{
	if(_newGroup || ![name isEqualToString:@"-"]) {
		[self willChangeValueForKey: @"name"];
		[self willChangeValueForKey: @"displayString"];	
		[self setPrimitiveValue: name forKey: @"name"];
		[self setPrimitiveValue: nil forKey: @"displayString"];
		[self didChangeValueForKey: @"name"];
		[self didChangeValueForKey: @"displayString"];
		_newGroup = false; 
	}
}

- (NSString *)displayString
{
	_newGroup = false; 
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
	if([[self valueForKey:@"name"] isEqualToString:@"-"]) return nil; 
	
	NSEnumerator* channels = [[self valueForKey: @"channels"] objectEnumerator];
	ZKMRNGraphChannel* channel;
	NSMutableArray* sources = [NSMutableArray array];
	while (channel = [channels nextObject]) {
		[sources addObject: [channel pannerSource]];
	}
	return sources;
}

@end
