//
//  ZKMRNCartesianEvent.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 11.02.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNCartesianEvent.h"
#import "ZKMRNGraphChannel.h"
#import <Syncretism/Syncretism.h>



@implementation ZKMRNCartesianEvent

#pragma mark _____ NSManagedObject Overrides
+ (void)initialize
{
	[self setKeys: [NSArray arrayWithObjects: @"deltaAzimuth", @"deltaZenith", @"width", @"height", nil] triggerChangeNotificationsForDependentKey: @"summary"];
}

+ (NSArray *)copyKeys 
{ 
	static NSArray* copyKeys = nil;
	if (!copyKeys) {
		copyKeys = [[NSArray alloc] initWithObjects: @"startTime", @"duration", @"x", @"y", @"width", @"height", @"gain", @"continueMode", @"eventType", nil];
	}
	
	return copyKeys;
}

- (void)scheduleEvents:(ZKMNREventScheduler *)scheduler
{
	NSArray* sources = [[self valueForKey: @"container"] pannerSources];
	unsigned i, count = [sources count];
	for (i = 0; i < count; i++) {
		ZKMNRPannerEventXY* pannerEvent = [[ZKMNRPannerEventXY alloc] init];
		[pannerEvent setStartTime: [[self valueForKey: @"startTime"] doubleValue]];
		[pannerEvent setDuration: [[self valueForKey: @"duration"] doubleValue]];
		[pannerEvent setX: [[self valueForKey: @"x"] floatValue]];
		[pannerEvent setY: [[self valueForKey: @"y"] floatValue]];
		[pannerEvent setXSpan: [[self valueForKey: @"width"] floatValue]];
		[pannerEvent setYSpan: [[self valueForKey: @"height"] floatValue]];
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
		[NSString stringWithFormat: @"XY {%.2f %.2f} {%.2f %.2f}", 
			[[self valueForKey: @"x"] floatValue],	
			[[self valueForKey: @"y"] floatValue],
			[[self valueForKey: @"width"] floatValue],
			[[self valueForKey: @"height"] floatValue]];
}

- (BOOL)isCartesian { return YES; }
- (NSString *)eventType { return @"ZKMRNCartesianEvent"; }

@end
