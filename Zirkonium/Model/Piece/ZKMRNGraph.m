//
//  ZKMRNGraph.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 05.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNGraph.h"

NSString* ZKMRNGraphNumberOfDirectOutsChanged = @"ZKMRNGraphNumberOfDirectOutsChanged";

@interface ZKMRNGraph (ZKMRNGraphPrivate)
- (void)privateSetDuration:(NSNumber *)duration;
- (void)increaseGraphChannelsTo:(unsigned)numberOfChannels;
- (void)decreaseGraphChannelsTo:(unsigned)numberOfChannels;

- (void)increaseDirectOutChannelsTo:(unsigned)numberOfDirectOuts;
- (void)decreaseDirectOutChannelsTo:(unsigned)numberOfDirectOuts;

- (NSArray *)sources;
@end


@implementation ZKMRNGraph
#pragma mark _____ NSManagedObject overrides
+ (void)initialize
{
	[self setKeys: [NSArray arrayWithObject: @"duration"] triggerChangeNotificationsForDependentKey: @"durationHH"];
	[self setKeys: [NSArray arrayWithObject: @"duration"] triggerChangeNotificationsForDependentKey: @"durationMM"];
	[self setKeys: [NSArray arrayWithObject: @"duration"] triggerChangeNotificationsForDependentKey: @"durationSS"];
	[self setKeys: [NSArray arrayWithObject: @"duration"] triggerChangeNotificationsForDependentKey: @"durationMS"];	
}

- (void)awakeFromInsert
{
//	[self increaseGraphChannelsTo: [[self valueForKey: @"numberOfChannels"] unsignedIntValue]];
}

#pragma mark _____ Accessors
- (void)setNumberOfChannels:(NSNumber *)numberOfChannels
{
	[self willChangeValueForKey: @"numberOfChannels"];
	[self setPrimitiveValue: numberOfChannels forKey: @"numberOfChannels"];
	[self didChangeValueForKey: @"numberOfChannels"];
	
	// add or remove channels to match the number of channels (got rid of (JB))
	/*
	unsigned count = [[self valueForKey: @"graphChannels"] count];
	if (count < [numberOfChannels unsignedIntValue])
		[self increaseGraphChannelsTo: [numberOfChannels unsignedIntValue]];
	else
		[self decreaseGraphChannelsTo: [numberOfChannels unsignedIntValue]];
	*/
}

- (void)setNumberOfDirectOuts:(NSNumber *)numberOfDirectOuts
{
	[self willChangeValueForKey: @"numberOfDirectOuts"];
	[self setPrimitiveValue: numberOfDirectOuts forKey: @"numberOfDirectOuts"];
	[self didChangeValueForKey: @"numberOfDirectOuts"];
	
	// add or remove channels to match the number of channels
	unsigned count = [[self valueForKey: @"directOutChannels"] count];
	if (count < [numberOfDirectOuts unsignedIntValue])
		[self increaseDirectOutChannelsTo: [numberOfDirectOuts unsignedIntValue]];
	else
		[self decreaseDirectOutChannelsTo: [numberOfDirectOuts unsignedIntValue]];
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMRNGraphNumberOfDirectOutsChanged object: self];

}

- (void)setDuration:(NSNumber *)duration
{
	[self setPrimitiveValue: nil forKey: @"durationHH"];
	[self setPrimitiveValue: nil forKey: @"durationMM"];
	[self setPrimitiveValue: nil forKey: @"durationSS"];
	[self setPrimitiveValue: nil forKey: @"durationMS"];
	[self privateSetDuration: duration];
}

#pragma mark _____ Duration Accessors
- (NSNumber *)durationHH
{
	[self willAccessValueForKey: @"durationHH"];
	NSNumber* durationHH = [self primitiveValueForKey: @"durationHH"];
	[self didAccessValueForKey: @"durationHH"];
	
	NSNumber* duration = [self valueForKey: @"duration"];
	if (nil == duration) return nil;

	if (durationHH == nil) {
		Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
		durationHH = [NSNumber numberWithUnsignedInt: hh];
		[self setPrimitiveValue: durationHH forKey: @"durationHH"];
	}
	return durationHH;
}

- (void)setDurationHH:(NSNumber *)anUnsigned
{
	NSNumber* duration = [self valueForKey: @"duration"];
	Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
	
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
	Float64 newDurationSecs; HHMMSSMSToSeconds([anUnsigned unsignedIntValue], mm, ss, ms, &newDurationSecs);
	
	[self willChangeValueForKey: @"durationHH"];
	[self setPrimitiveValue: anUnsigned forKey: @"durationHH"];
	[self didChangeValueForKey: @"durationHH"];
	[self privateSetDuration: [NSNumber numberWithDouble: newDurationSecs]];
}

- (NSNumber *)durationMM
{
	[self willAccessValueForKey: @"durationMM"];
	NSNumber* durationMM = [self primitiveValueForKey: @"durationMM"];
	[self didAccessValueForKey: @"durationMM"];
	
	NSNumber* duration = [self valueForKey: @"duration"];
	if (nil == duration) return nil;

	if (durationMM == nil) {
		Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
		durationMM = [NSNumber numberWithUnsignedInt: mm];
		[self setPrimitiveValue: durationMM forKey: @"durationMM"];
	}
	return durationMM;
}

- (void)setDurationMM:(NSNumber *)anUnsigned
{
	NSNumber* duration = [self valueForKey: @"duration"];
	Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
	
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
	Float64 newDurationSecs; HHMMSSMSToSeconds(hh, [anUnsigned unsignedIntValue], ss, ms, &newDurationSecs);
	
	[self willChangeValueForKey: @"durationMM"];
	[self setPrimitiveValue: anUnsigned forKey: @"durationMM"];
	[self didChangeValueForKey: @"durationMM"];
	[self privateSetDuration: [NSNumber numberWithDouble: newDurationSecs]];
}

- (NSNumber *)durationSS
{
	[self willAccessValueForKey: @"durationSS"];
	NSNumber* durationSS = [self primitiveValueForKey: @"durationSS"];
	[self didAccessValueForKey: @"durationSS"];
	
	NSNumber* duration = [self valueForKey: @"duration"];
	if (nil == duration) return nil;

	if (durationSS == nil) {
		Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
		durationSS = [NSNumber numberWithUnsignedInt: ss];
		[self setPrimitiveValue: durationSS forKey: @"durationSS"];
	}
	return durationSS;
}

- (void)setDurationSS:(NSNumber *)anUnsigned
{
	NSNumber* duration = [self valueForKey: @"duration"];
	Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
	
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
	Float64 newDurationSecs; HHMMSSMSToSeconds(hh, mm, [anUnsigned unsignedIntValue], ms, &newDurationSecs);
	
	[self willChangeValueForKey: @"durationSS"];
	[self setPrimitiveValue: anUnsigned forKey: @"durationSS"];
	[self didChangeValueForKey: @"durationSS"];
	[self privateSetDuration: [NSNumber numberWithDouble: newDurationSecs]];
}

- (NSNumber *)durationMS
{
	[self willAccessValueForKey: @"durationMS"];
	NSNumber* durationMS = [self primitiveValueForKey: @"durationMS"];
	[self didAccessValueForKey: @"durationMS"];
	
	NSNumber* duration = [self valueForKey: @"duration"];
	if (nil == duration) return nil;

	if (durationMS == nil) {
		Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
		unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
		durationMS = [NSNumber numberWithUnsignedInt: ms];
		[self setPrimitiveValue: durationMS forKey: @"durationMS"];
	}
	return durationMS;
}

- (void)setDurationMS:(NSNumber *)anUnsigned
{
	NSNumber* duration = [self valueForKey: @"duration"];
	Float64 durSecs = (duration) ? [duration doubleValue] : 0.;
	
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(durSecs, &hh, &mm, &ss, &ms);
	Float64 newDurationSecs; HHMMSSMSToSeconds(hh, mm, ss, [anUnsigned unsignedIntValue], &newDurationSecs);
	
	[self willChangeValueForKey: @"durationMS"];
	[self setPrimitiveValue: anUnsigned forKey: @"durationMS"];
	[self didChangeValueForKey: @"durationMS"];
	[self privateSetDuration: [NSNumber numberWithDouble: newDurationSecs]];
}

#pragma mark _____ ZKMRNGraphPrivate
- (void)privateSetDuration:(NSNumber *)duration
{
	[self willChangeValueForKey: @"duration"];
	[self setPrimitiveValue: duration forKey: @"duration"];
	[self didChangeValueForKey: @"duration"];
}

- (void)increaseGraphChannelsTo:(unsigned)numberOfChannels
{
	/*
	NSMutableSet* channels = [self mutableSetValueForKey: @"graphChannels"];
	unsigned i, count = [channels count];
	
	NSManagedObject* defaultSource = [[self sources] lastObject];
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;
	
	for (i = count; i < numberOfChannels; i++) {
		channel = [NSEntityDescription insertNewObjectForEntityForName: @"GraphChannel" inManagedObjectContext: moc];
		[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"graphChannelNumber"];
		if (defaultSource) {
			[channel setValue: self forKey: @"graph"];
			[channel setValue: defaultSource forKey: @"source"];
			[channel setValue: [NSNumber numberWithUnsignedInt: 0] forKey: @"sourceChannelNumber"];
		} else {
			[channel setValue: [NSNumber numberWithUnsignedInt: 0] forKey: @"sourceChannelNumber"];
		}
		[channels addObject: channel];		
	}
	*/
}

- (void)decreaseGraphChannelsTo:(unsigned)numberOfChannels
{
	/*
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;

	NSEnumerator* channels = [[self valueForKey: @"graphChannels"] objectEnumerator];
	NSMutableSet* toKeep = [[NSMutableSet alloc] init];
	while (channel = [channels nextObject]) {
		unsigned int patchChannel = [[channel valueForKey: @"graphChannelNumber"] unsignedIntValue];
		if (patchChannel < numberOfChannels) 
			[toKeep addObject: channel];
		else
			[moc deleteObject: channel];
	}
	[self setValue: toKeep forKey: @"graphChannels"];
	*/
}

- (void)increaseDirectOutChannelsTo:(unsigned)numberOfDirectOuts
{
	NSMutableSet* channels = [self mutableSetValueForKey: @"directOutChannels"];
	unsigned i, count = [channels count];
	
	NSManagedObject* defaultSource = [[self sources] lastObject];
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;
	
	for (i = count; i < numberOfDirectOuts; i++) {
		channel = [NSEntityDescription insertNewObjectForEntityForName: @"DirectOutChannel" inManagedObjectContext: moc];
		[channel setValue: [NSNumber numberWithUnsignedInt: i] forKey: @"directOutNumber"];
		[channel setValue: defaultSource forKey: @"source"];
		[channel setValue: self forKey: @"graph"];
		[channels addObject: channel];		
	}
}

- (void)decreaseDirectOutChannelsTo:(unsigned)numberOfDirectOuts
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSManagedObject* channel;

	NSEnumerator* channels = [[self valueForKey: @"directOutChannels"] objectEnumerator];
	NSMutableSet* toKeep = [[NSMutableSet alloc] init];
	while (channel = [channels nextObject]) {
		unsigned int patchChannel = [[channel valueForKey: @"directOutNumber"] unsignedIntValue];
		if (patchChannel < numberOfDirectOuts) 
			[toKeep addObject: channel];
		else
			[moc deleteObject: channel];
	}
	[self setValue: toKeep forKey: @"directOutChannels"];
}

- (NSArray *)sources
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"AudioSource" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) return nil;
	return array;
}

#pragma mark -


// (JB)
-(void)addChannel
{
	NSMutableSet* channels = [self mutableSetValueForKey: @"graphChannels"];
	
	unsigned count = [[self valueForKey: @"graphChannels"] count];

	//find maximum channel id ...
	id aChannel;
	int maxChannelNumber = 0; 
	for (aChannel in channels) {
		unsigned int idN = [[aChannel valueForKey:@"graphChannelNumber"] unsignedIntValue];
		if(idN+1 > maxChannelNumber) maxChannelNumber = idN+1;
	}
	unsigned int newChannelNumber = maxChannelNumber; 
	 
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel = [NSEntityDescription insertNewObjectForEntityForName: @"GraphChannel" inManagedObjectContext: moc];
	
	[channel setValue: [NSNumber numberWithUnsignedInt: newChannelNumber] forKey: @"graphChannelNumber"];
	[channel setValue: [NSNumber numberWithUnsignedInt: count] forKey: @"graphChannelIndex"];
	
	//NSManagedObject* likelySource = ([[self sources] count] < count) ? [[self sources] objectAtIndex:count] : [[self sources] lastObject];
	/*
	NSManagedObject* defaultSource = [[self sources] lastObject];
	
	if (defaultSource) {
		[channel setValue: self forKey: @"graph"];
		[channel setValue: defaultSource forKey: @"source"];
		[channel setValue: [NSNumber numberWithUnsignedInt: 0] forKey: @"sourceChannelNumber"];
	} else {
		[channel setValue: [NSNumber numberWithUnsignedInt: 0] forKey: @"sourceChannelNumber"];
	}
	*/
	[channel setValue: [NSNumber numberWithUnsignedInt: 0] forKey: @"sourceChannelNumber"];
	[self setNumberOfChannels:[NSNumber numberWithUnsignedInt:count+1]]; 
	
	[channels addObject: channel];
}

-(void)removeChannelWithNumber:(NSNumber*)number
{
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* channel;

	//find index of object to delete ...
	NSEnumerator* channels = [[self valueForKey: @"graphChannels"] objectEnumerator];
	unsigned int indexToDelete = 0;
	while (channel = [channels nextObject]) {
		unsigned int n = [[channel valueForKey: @"graphChannelNumber"] unsignedIntValue];
		if(n == [number unsignedIntValue]) {
			indexToDelete = [[channel valueForKey: @"graphChannelIndex"] unsignedIntValue];
			break;
		}
	}
	
	channels = [[self valueForKey: @"graphChannels"] objectEnumerator];
	
	NSMutableSet* toKeep = [[NSMutableSet alloc] init];
	while (channel = [channels nextObject]) {
		unsigned int patchChannelNumber = [[channel valueForKey: @"graphChannelNumber"] unsignedIntValue];
		if (patchChannelNumber != [number unsignedIntValue]) {
			unsigned int patchChannelIndex = [[channel valueForKey: @"graphChannelIndex"] unsignedIntValue];
			
			if(patchChannelIndex > indexToDelete)
			[channel setValue:[NSNumber numberWithUnsignedInt:patchChannelIndex-1] forKey:@"graphChannelIndex"];
			
			[toKeep addObject: channel];
		}
		else
			[moc deleteObject: channel];
	}
	[self setValue: toKeep forKey: @"graphChannels"];
	
	[self setNumberOfChannels:[NSNumber numberWithUnsignedInt:[toKeep count]]];
}



@end
