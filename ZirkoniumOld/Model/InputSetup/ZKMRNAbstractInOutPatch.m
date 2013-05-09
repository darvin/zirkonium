//
//  ZKMRNAbstractInOutPatch.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 13.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNAbstractInOutPatch.h"

@interface ZKMRNAbstractInOutPatch (ZKMRNAbstractInOutPatchPrivate)
- (void)increasePatchChannelsTo:(unsigned)numberOfChannels;
- (void)decreasePatchChannelsTo:(unsigned)numberOfChannels;
@end


@implementation ZKMRNAbstractInOutPatch

#pragma mark _____ NSManagedObject overrides
- (void)awakeFromInsert
{
	[self increasePatchChannelsTo: [[self valueForKey: @"numberOfChannels"] unsignedIntValue]];
	[self setValue: [self patchDefaultName] forKey: @"name"];
}

#pragma mark _____ Accessors
- (void)setNumberOfChannels:(NSNumber *)numberOfChannels
{
	[self willChangeValueForKey: @"numberOfChannels"];
	[self setPrimitiveValue: numberOfChannels forKey: @"numberOfChannels"];
	[self didChangeValueForKey: @"numberOfChannels"];
	
	// add or remove channels to match the number of channels
	unsigned count = [[self valueForKey: @"channels"] count];
	if (count < [numberOfChannels unsignedIntValue])
		[self increasePatchChannelsTo: [numberOfChannels unsignedIntValue]];
	else
		[self decreasePatchChannelsTo: [numberOfChannels unsignedIntValue]];
}

- (NSArray *)channelDescriptions
{

	[self willAccessValueForKey: @"channelDescriptions"];
	NSArray* channelDescriptions = [self primitiveValueForKey: @"channelDescriptions"];
	[self didAccessValueForKey: @"channelDescriptions"];

	if (channelDescriptions == nil) {
		channelDescriptions = [self channelDescriptionsArray];
		[self setPrimitiveValue: channelDescriptions forKey: @"channelDescriptions"];
	}
	return channelDescriptions;
}

#pragma mark _____ ZKMRNAbstractInOutPatchInternal
- (NSString *)patchChannelEntityName { return nil; }
- (NSArray *)channelDescriptionsArray { return nil; }
- (NSString *)patchDefaultName { return @"Patch"; }

#pragma mark _____ ZKMRNAbstractInOutPatch
- (void)increasePatchChannelsTo:(unsigned)numberOfChannels
{
	NSMutableSet* channels = [self mutableSetValueForKey: @"channels"];
	unsigned i, count = [channels count];
	
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;
	
	for (i = count; i < numberOfChannels; i++) {
		channel = [NSEntityDescription insertNewObjectForEntityForName: [self patchChannelEntityName] inManagedObjectContext: moc];
		[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"patchChannel"];
		[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"sourceChannel"];
		[channels addObject: channel];		
	}
}

- (void)decreasePatchChannelsTo:(unsigned)numberOfChannels
{
	NSManagedObject* channel;

	NSEnumerator* channels = [[self valueForKey: @"channels"] objectEnumerator];
	NSMutableSet* toKeep = [[NSMutableSet alloc] init];
	while (channel = [channels nextObject]) {
		unsigned int patchChannel = [[channel valueForKey: @"patchChannel"] unsignedIntValue];
		if (patchChannel < numberOfChannels) [toKeep addObject: channel];
	}
	[self setValue: toKeep forKey: @"channels"];
}

@end
