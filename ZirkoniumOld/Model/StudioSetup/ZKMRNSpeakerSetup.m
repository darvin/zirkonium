//
//  ZKMRNSpeakerSetup.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 27.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNSpeakerSetup.h"
#import "ZKMRNSpeaker.h"
#import "ZKMRNManagedObjectExtensions.h"


@implementation ZKMRNSpeakerSetup

#pragma mark _____ NSManagedObject Overrides

#pragma mark _____ ZKMRNManagedObjectExtensions
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableArray* speakerRingDicts = [NSMutableArray array];
	NSArray* sortedRings = [[[self valueForKey: @"speakerRings"] allObjects] sortedArrayUsingSelector: @selector(compare:)];
	NSEnumerator* speakerRings = [sortedRings objectEnumerator];
	NSManagedObject* speakerRing;
	while (speakerRing = [speakerRings nextObject]) {
		[speakerRingDicts addObject: [speakerRing dictionaryRepresentation]];
	}
	return [NSDictionary dictionaryWithObject: speakerRingDicts forKey: @"speakerRings"];
}

- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation
{
	NSEnumerator* speakerRingDicts = [[dictionaryRepresentation valueForKey: @"speakerRings"] objectEnumerator];
	NSMutableSet* speakerRings = [self mutableSetValueForKey: @"speakerRings"];
	NSManagedObject* speakerRing;
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSDictionary* speakerRingDict;
	unsigned i;
	for (i = 0; speakerRingDict = [speakerRingDicts nextObject]; i++) {
		speakerRing = [NSEntityDescription insertNewObjectForEntityForName: @"SpeakerRing" inManagedObjectContext: moc];
		[speakerRing setFromDictionaryRepresentation: speakerRingDict];
		[speakerRing setValue: [NSNumber numberWithInt: i] forKey: @"ringNumber"];
		[speakerRings addObject: speakerRing];
	}
}

#pragma mark _____ Accessors
- (ZKMNRSpeakerLayout *)speakerLayout
{
	[self willAccessValueForKey: @"speakerLayout"];
	ZKMNRSpeakerLayout* speakerLayout = [self primitiveValueForKey: @"speakerLayout"];
	[self didAccessValueForKey: @"speakerLayout"];
	
	if (!speakerLayout) {
			// set the name
		speakerLayout = [[ZKMNRSpeakerLayout alloc] init];
		[speakerLayout setSpeakerLayoutName: [self valueForKey: @"name"]];
		
			// add the rings
		[speakerLayout beginEditing];
		NSSet* rings = [self valueForKey: @"speakerRings"];
		[speakerLayout setNumberOfRings: [rings count]];
		
		NSEnumerator* ringEnumerator = [rings objectEnumerator];
		id speakerRing = nil; unsigned i;
		for (i = 0; speakerRing = [ringEnumerator nextObject]; ++i) {
			unsigned ringNumber = [[speakerRing valueForKey: @"ringNumber"] unsignedIntValue];
			NSMutableArray* ring = [speakerLayout ringAtIndex: ringNumber];
			NSSet* speakers = [speakerRing valueForKey: @"speakers"];
			NSEnumerator* speakerEnumerator = [speakers objectEnumerator];
			id speaker = nil;
				// add the speakers
			while (speaker = [speakerEnumerator nextObject]) {
				[ring addObject: [speaker speakerPosition]];				
			}
		}
		[speakerLayout endEditing];
		[self setPrimitiveValue: speakerLayout forKey: @"speakerLayout"];
		[speakerLayout release];
	}

	return speakerLayout;
}

- (unsigned)numberOfSpeakers { return [[self speakerLayout] numberOfSpeakers]; }

#pragma mark _____ Notification
- (void)speakerRingsChanged
{
	[self willChangeValueForKey: @"speakerLayout"];
	[self willChangeValueForKey: @"numberOfSpeakers"];
	[self setPrimitiveValue: nil forKey: @"speakerLayout"];
	[self didChangeValueForKey: @"speakerLayout"];
	[self didChangeValueForKey: @"numberOfSpeakers"];
}

@end
