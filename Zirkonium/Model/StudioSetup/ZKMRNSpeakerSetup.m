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

@class ZKMRNZirkoniumSystem;
@implementation ZKMRNSpeakerSetup

-(void)awakeFromInsert
{
	[self setValue:nil forKey:@"speakerRings"];
}

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

-(void)setPrimitiveSpeakerLayout:(ZKMNRSpeakerLayout*)newSpeakerLayout
{
	if(_speakerLayout) {
		[_speakerLayout release];
		_speakerLayout = nil; 
	}
	if(newSpeakerLayout)
		_speakerLayout = [newSpeakerLayout retain]; 
}

-(ZKMNRSpeakerLayout*)primitiveSpeakerLayout {
	return _speakerLayout;
}

- (ZKMNRSpeakerLayout *)speakerLayout
{
	[self willAccessValueForKey: @"speakerLayout"];
	ZKMNRSpeakerLayout* speakerLayout = [self primitiveSpeakerLayout];
	[self didAccessValueForKey: @"speakerLayout"];
	
	if (!speakerLayout) {
		// set the name ...
		speakerLayout = [[ZKMNRSpeakerLayout alloc] init];
		[speakerLayout setSpeakerLayoutName: [self valueForKey: @"name"]];
		
		// add the rings ...
		[speakerLayout beginEditing];
		
		NSSet* rings = [self valueForKey: @"speakerRings"];
		int count = (!rings) ?  0 : [rings count];
		[speakerLayout setNumberOfRings: count];
		
		id speakerRing;
		for(speakerRing in [rings allObjects]) {
			unsigned ringNumber = [[speakerRing valueForKey: @"ringNumber"] unsignedIntValue];
			if(ringNumber>=count) { break; }
			NSMutableArray* ring = [speakerLayout ringAtIndex: ringNumber];
			NSSet* speakers = [speakerRing valueForKey: @"speakers"];
			NSEnumerator* speakerEnumerator = [speakers objectEnumerator];
			id speaker = nil;
			// add the speakers ...
			while (speaker = [speakerEnumerator nextObject]) {
				[ring addObject: [speaker speakerPosition]];				
			}
		}
		[speakerLayout endEditing];
		
		[[[self managedObjectContext] undoManager] disableUndoRegistration];
		[self setPrimitiveSpeakerLayout:speakerLayout];
		[[[self managedObjectContext] undoManager] enableUndoRegistration];

		[speakerLayout autorelease];
	}

	return speakerLayout;
}

- (unsigned)numberOfSpeakers { return [[self speakerLayout] numberOfSpeakers]; }

#pragma mark _____ Notification
- (void)speakerRingsChanged
{
	[[[self managedObjectContext] undoManager] disableUndoRegistration];
	[self willChangeValueForKey: @"speakerLayout"];
	[self willChangeValueForKey: @"numberOfSpeakers"];
	[self setPrimitiveSpeakerLayout:nil];
	[self didChangeValueForKey: @"numberOfSpeakers"];
	[self didChangeValueForKey: @"speakerLayout"];	
	[[[self managedObjectContext] undoManager] enableUndoRegistration];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:self]; 
}

#pragma mark -

-(BOOL)isPreferenceSelected {
	if([self isEqualTo:[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] speakerSetup]]) {
		return YES;
	}
	return NO; 
}

@end
