//
//  ZKMRNPositionEvent.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 04.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNPositionEvent.h"
#import "ZKMRNGraphChannel.h"
#import <Syncretism/Syncretism.h>

@implementation ZKMRNPositionEvent

#pragma mark _____ NSManagedObject Overrides
+ (void)initialize
{
	[self setKeys: [NSArray arrayWithObjects: @"deltaAzimuth", @"deltaZenith", @"width", @"height", nil] triggerChangeNotificationsForDependentKey: @"summary"];
}

+ (NSArray *)copyKeys 
{ 
	static NSArray* copyKeys = nil;
	if (!copyKeys) {
		copyKeys = [[NSArray alloc] initWithObjects: @"startTime", @"duration", @"deltaAzimuth", @"deltaZenith", @"width", @"height", @"gain", @"continueMode",  @"eventType", nil];
	}
	
	return copyKeys;
}

- (void)scheduleEvents:(ZKMNREventScheduler *)scheduler
{
	NSArray* sources = [[self valueForKey: @"container"] pannerSources];
	unsigned i, count = [sources count];
	for (i = 0; i < count; i++) {
		ZKMNRPannerEvent* pannerEvent = [[ZKMNRPannerEvent alloc] init];
		[pannerEvent setStartTime: [[self valueForKey: @"startTime"] doubleValue]];
		[pannerEvent setDuration: [[self valueForKey: @"duration"] doubleValue]];
		[pannerEvent setDeltaAzimuth: [[self valueForKey: @"deltaAzimuth"] floatValue]];
		[pannerEvent setDeltaZenith: [[self valueForKey: @"deltaZenith"] floatValue]];
		[pannerEvent setAzimuthSpan: [[self valueForKey: @"width"] floatValue]];
		[pannerEvent setZenithSpan: [[self valueForKey: @"height"] floatValue]];
		[pannerEvent setGain: [[self valueForKey: @"gain"] floatValue]];
		[pannerEvent setContinuationMode: [[self valueForKey: @"continueMode"] intValue]];
		[pannerEvent setTarget: [sources objectAtIndex: i]];
		[scheduler scheduleEvent: pannerEvent];
		[pannerEvent release];
	}
}

- (NSString *)computeSummary
{
	return 
		[NSString stringWithFormat: @"AZ {%.2f %.2f} {%.2f %.2f}", 
			[[self valueForKey: @"deltaAzimuth"] floatValue],	
			[[self valueForKey: @"deltaZenith"] floatValue],
			[[self valueForKey: @"width"] floatValue],
			[[self valueForKey: @"height"] floatValue]];
}

- (BOOL)isSpherical { return YES; }
- (NSString *)eventType { return @"ZKMRNPositionEvent"; }

@end
