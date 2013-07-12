//
//  ZKMRNOutputPatch.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOutputPatch.h"
#import "ZKMRNZirkoniumSystem.h"
@class ZKMRNZirkoniumSystem;
@implementation ZKMRNOutputPatch
#pragma mark _____ ZKMRNAbstractInOutPatchInternal

-(BOOL)isPreferenceSelected {
	if([[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] outputPatch] isEqualTo:self]) {
		return YES; 
	}
	return NO; 
}

- (NSString *)patchChannelEntityName { return @"OutputPatchChannel"; } 
- (NSString *)directOutChannelEntityName { return @"DirectOutPatchChannel"; }
- (NSString *)bassOutChannelEntityName { return @"BassOutPatchChannel"; }
- (NSArray *)channelDescriptionsArray { return [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice] outputChannelNames]; }
- (NSString *)patchDefaultName { return @"Output Patch"; }

/*
-(unsigned)numberOfDirectOuts
{
	// count in output patch
	unsigned count = 0;
	NSEnumerator* outputs = [[self valueForKey: @"channels"] objectEnumerator];
	NSManagedObject* outputChannel;
	while (outputChannel = [outputs nextObject]) {
		if([[outputChannel valueForKey: @"isDirectOut"] boolValue])  count++; 
	}
	
	return count;
}
*/

#pragma mark _____ Accessors
//Jens
- (void)setNumberOfDirectOuts:(NSNumber *)numberOfChannels
{
	[self willChangeValueForKey: @"numberOfDirectOuts"];
	[self setPrimitiveValue: numberOfChannels forKey: @"numberOfDirectOuts"];
	[self didChangeValueForKey: @"numberOfDirectOuts"];
	
	// add or remove channels to match the number of channels
	unsigned count = [[self valueForKey: @"directOutChannels"] count];
	if (count < [numberOfChannels unsignedIntValue])
		[self increaseDirectOutChannelsTo: [numberOfChannels unsignedIntValue]];
	else
		[self decreaseDirectOutChannelsTo: [numberOfChannels unsignedIntValue]];
		
	[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object:nil];	
}

-(void)setApplicable:(BOOL)isApplicable
{
	
	[self willChangeValueForKey: @"isApplicable"];
	[self setPrimitiveValue: [NSNumber numberWithBool:isApplicable] forKey: @"isApplicable"];
	[self didChangeValueForKey: @"isApplicable"];
	//[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
}


-(BOOL)isApplicable
{
	unsigned numberOfSpeakers = [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] speakerSetup] numberOfSpeakers];
	
	if(numberOfSpeakers!=0 && numberOfSpeakers == [[self valueForKey:@"numberOfChannels"] intValue] )
		return YES;
		
	 return NO; 
}


#pragma mark - Add / Remove DirectOut
//Jens
- (void)increaseDirectOutChannelsTo:(unsigned)numberOfChannels
{
	NSMutableSet* directOutChannels = [self mutableSetValueForKey: @"directOutChannels"];
	unsigned i, count = [directOutChannels count];
	
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;
	
	for (i = count; i < numberOfChannels; i++) {
		channel = [NSEntityDescription insertNewObjectForEntityForName: [self directOutChannelEntityName] inManagedObjectContext: moc];
		[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"patchChannel"];
		//[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"sourceChannel"]; //initialy not defined
		[directOutChannels addObject: channel];		
	}
}

- (void)decreaseDirectOutChannelsTo:(unsigned)numberOfChannels
{
	NSManagedObject* channel;

	NSEnumerator* channels = [[self valueForKey: @"directOutChannels"] objectEnumerator];
	NSMutableSet* toKeep = [[NSMutableSet alloc] init];
	while (channel = [channels nextObject]) {
		unsigned int patchChannel = [[channel valueForKey: @"patchChannel"] unsignedIntValue];
		if (patchChannel < numberOfChannels) [toKeep addObject: channel];
	}
	[self setValue: toKeep forKey: @"directOutChannels"];
}

-(void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation 
{
	[self setValue:[dictionaryRepresentation valueForKey:@"name"] forKey:@"name"];
	[self setNumberOfChannels:[dictionaryRepresentation valueForKey:@"numberOfChannels"]];
	
	NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"patchChannel" ascending:YES];
	NSArray* descriptorArray = [NSArray arrayWithObject:sortDescriptor];
	NSArray* channels = [[dictionaryRepresentation valueForKey: @"channels"] sortedArrayUsingDescriptors:descriptorArray];	
	NSArray* myChannels = [[[self valueForKey:@"channels"] allObjects] sortedArrayUsingDescriptors:descriptorArray];

	int i = 0;
	id aChannel; 
	for(aChannel in myChannels) {
		[aChannel setPrimitiveValue:[[channels objectAtIndex:i] valueForKey:@"sourceChannel"] forKey:@"sourceChannel"];
		i++;
	}
}

- (NSUInteger)numberOfBassOuts
{
	return [[self primitiveValueForKey: @"numberOfBassOuts"] intValue];
}

- (void)setNumberOfBassOuts:(NSNumber *)numberOfChannels
{
	[self willChangeValueForKey: @"numberOfBassOuts"];
	[self setPrimitiveValue: numberOfChannels forKey: @"numberOfBassOuts"];
	[self didChangeValueForKey: @"numberOfBassOuts"];
	
	// add or remove channels to match the number of channels
	unsigned count = [[self valueForKey: @"bassOutChannels"] count];
	if (count < [numberOfChannels unsignedIntValue])
		[self increaseBassOutChannelsTo: [numberOfChannels unsignedIntValue]];
	else
		[self decreaseBassOutChannelsTo: [numberOfChannels unsignedIntValue]];
		
	[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object:nil];	
}

- (void)increaseBassOutChannelsTo:(unsigned)numberOfChannels
{
	NSMutableSet* bassOutChannels = [self mutableSetValueForKey: @"bassOutChannels"];
	unsigned i, count = [bassOutChannels count];
	
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;
	
	for (i = count; i < numberOfChannels; i++) {
		channel = [NSEntityDescription insertNewObjectForEntityForName: [self bassOutChannelEntityName] inManagedObjectContext: moc];
		[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"patchChannel"];
		//[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"sourceChannel"]; //initialy not defined
		[bassOutChannels addObject: channel];		
	}
}

- (void)decreaseBassOutChannelsTo:(unsigned)numberOfChannels
{
	NSManagedObject* channel;

	NSEnumerator* channels = [[self valueForKey: @"bassOutChannels"] objectEnumerator];
	NSMutableSet* toKeep = [[NSMutableSet alloc] init];
	while (channel = [channels nextObject]) {
		unsigned int patchChannel = [[channel valueForKey: @"patchChannel"] unsignedIntValue];
		if (patchChannel < numberOfChannels) [toKeep addObject: channel];
	}
	[self setValue: toKeep forKey: @"bassOutChannels"];
}

@end
