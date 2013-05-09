//
//  ZKMRMUserWatchdog.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 03.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMUserWatchdog.h"

@interface ZKMRMUserWatchdog (ZKMRMUserWatchdogPrivate)
- (void)receivedMouseEvent:(CGEventRef)event type:(CGEventType)type;
- (void)receivedKeyDownEvent:(CGEventRef)event;
@end

static CGEventRef ZKMRMEventTapCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
	ZKMRMUserWatchdog* mySelf = (ZKMRMUserWatchdog *) refcon;
	[mySelf receivedMouseEvent: event type: type];
	return event;
}


@implementation ZKMRMUserWatchdog

- (id)init
{
	if (!(self = [super init])) return nil;
	
	lastEventDate = [[NSDate date] retain];

	CGEventMask mask = 
		CGEventMaskBit(kCGEventMouseMoved)
		| CGEventMaskBit(kCGEventLeftMouseDown)
		| CGEventMaskBit(kCGEventLeftMouseUp)
		| CGEventMaskBit(kCGEventRightMouseDown)
		| CGEventMaskBit(kCGEventRightMouseUp)
		| CGEventMaskBit(kCGEventScrollWheel);
	eventTap = 
		CGEventTapCreate(kCGAnnotatedSessionEventTap,
			kCGTailAppendEventTap,
			kCGEventTapOptionListenOnly,
			mask,
			ZKMRMEventTapCallBack,
			self);
			
	[[NSRunLoop currentRunLoop] addPort: (NSPort*)eventTap forMode: NSRunLoopCommonModes];
	
	return self;
}

#pragma mark ZKMRMUserWatchdogPrivate
- (void)receivedMouseEvent:(CGEventRef)event type:(CGEventType)type
{
	NSDate* previousDate = lastEventDate;
	lastEventDate = [[NSDate date] retain];
	[previousDate release];
}

@end
