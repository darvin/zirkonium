//
//  ZKMRNSpeakerRing.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 31.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNSpeakerRing.h"
#import "ZKMRNSpeakerSetup.h"
#import "ZKMRNManagedObjectExtensions.h"


@implementation ZKMRNSpeakerRing
#pragma mark _____ NSManagedObject Overrides
+ (void)initialize
{
	[self setKeys: [NSArray arrayWithObject: @"ringNumber"] triggerChangeNotificationsForDependentKey: @"displayString"];
}

#pragma mark _____ Accessors
- (NSString *)displayString { return [NSString stringWithFormat: @"%u", [[self valueForKey: @"ringNumber"] intValue] + 1]; }
#pragma mark _____ Queries
- (NSComparisonResult)compare:(ZKMRNSpeakerRing *)otherRing
{
	int myRingNum = [[self valueForKey: @"ringNumber"] intValue];
	int otherRingNum = [[otherRing valueForKey: @"ringNumber"] intValue]; 
	if (myRingNum < otherRingNum) return NSOrderedAscending;
	if (otherRingNum < myRingNum) return NSOrderedDescending;
	return NSOrderedSame;
}

#pragma mark _____ Notification
- (void)speakerRingChanged
{
	[[self valueForKey: @"speakerSetup"] speakerRingsChanged];
}

#pragma mark _____ ZKMRNManagedObjectExtensions
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableArray* speakersDicts = [NSMutableArray array];
	NSEnumerator* speakers = [[self valueForKey: @"speakers"] objectEnumerator];
	NSManagedObject* speaker;
	while (speaker = [speakers nextObject]) {
		[speakersDicts addObject: [speaker dictionaryRepresentation]];
	}
	return [NSDictionary dictionaryWithObject: speakersDicts forKey: @"speakers"];
}

- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation
{
	NSEnumerator* speakerDicts = [[dictionaryRepresentation valueForKey: @"speakers"] objectEnumerator];
	NSMutableSet* speakers = [self mutableSetValueForKey: @"speakers"];
	NSManagedObject* speaker;
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSDictionary* speakerDict;
	while (speakerDict = [speakerDicts nextObject]) {
		speaker = [NSEntityDescription insertNewObjectForEntityForName: @"Speaker" inManagedObjectContext: moc];
		[speaker setFromDictionaryRepresentation: speakerDict];
		[speakers addObject: speaker];
	}
	[self speakerRingChanged];
}

@end
