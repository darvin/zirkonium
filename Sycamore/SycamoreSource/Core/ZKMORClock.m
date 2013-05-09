//
//  ZKMORClock.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 10.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORClock.h"
#import "ZKMORException.h"
#import "ZKMORLogger.h"
#import "ZKMORDeviceOutput.h"
#import "ZKMORAudioUnit.h"


@implementation ZKMORClock
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if(_clockRef) CAClockDispose(_clockRef), _clockRef = NULL;
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	OSStatus err;
	err = CAClockNew(0, &_clockRef);
	if (err) {
		[self autorelease];
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(ClockError, @"init>>error : %@", error);
	}
	_isRunning = NO;
	_isScrubbing = NO;
	
	return self;
}

#pragma mark _____ Accessors
- (CAClockRef)clockRef { return _clockRef; }
- (Float64)currentTimeSeconds
{
	CAClockTime now;
	OSStatus err;
	if ([self isRunning]) {
		err = CAClockGetCurrentTime(_clockRef, kCAClockTimeFormat_Seconds, &now);
		//NSLog(@"Now Running: Get Current Time");
	}
	else {
		err = CAClockGetStartTime(_clockRef, kCAClockTimeFormat_Seconds, &now);
		//NSLog(@"Still Stopped: Get Start Time");
	}
	
	if (err) {
		ZKMORLogError(kZKMORLogSource_Clock, CFSTR("CAClockGetStartTime failed %u"), err);
		return 0.f;
	}	
	
	Float64 cts = 0.0; 
	
	if(prevTimeSeconds > now.time.seconds) {
		cts = (prevTimeSeconds - now.time.seconds) + prevTimeSeconds;
	} else {
		cts = now.time.seconds;
	}
	
	//NSLog(@"Current: %f, Previous: %f, TIME: %f", now.time.seconds, prevTimeSeconds, cts);
	 

	return cts; //JB: Use absolute value (Jack runs negative time!!!)
}
- (void)setCurrentTimeSeconds:(Float64)currentTimeSeconds
{
	//NSLog(@"Set Current Time Seconds: %f", currentTimeSeconds);
	prevTimeSeconds = currentTimeSeconds;
	CAClockTime time;
	time.format = kCAClockTimeFormat_Seconds; time.time.seconds = currentTimeSeconds;
	OSStatus err = CAClockSetCurrentTime(_clockRef, &time);
	if (err) ZKMORLogError(kZKMORLogSource_Clock, CFSTR("CAClockSetCurrentTime failed %u"), err);
}

- (void)setTimebaseDeviceOutput:(ZKMORDeviceOutput *)deviceOutput
{
	CAClockTimebase timebase = (deviceOutput) ? kCAClockTimebase_AudioOutputUnit : kCAClockTimebase_HostTime;
	UInt32 size = sizeof(timebase);
	OSStatus err = CAClockSetProperty(_clockRef, kCAClockProperty_InternalTimebase, size, &timebase);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Clock, CFSTR("attachToDeviceOutput>>error %u"), err);
		return;
	}
	if (!deviceOutput) return;

	AudioUnit au = [[deviceOutput outputUnit] audioUnit];
	size = sizeof(au);
	err = CAClockSetProperty(_clockRef, kCAClockProperty_TimebaseSource, size, &au);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Clock, CFSTR("attachToDeviceOutput>>error %u"), err);
		return;
	}
}

#pragma mark _____ Actions
- (void)start { CAClockStart(_clockRef); _isRunning = YES; }
- (void)stop { _isRunning = NO; CAClockStop(_clockRef); }
- (void)beginScrubbing
{
	_wasRunning = [self isRunning];
	_isScrubbing = YES;
	if (_wasRunning) [self stop];
}

- (void)endScrubbing
{
	_isScrubbing = NO;
	if (_wasRunning) [self start];
}

#pragma mark _____ Queries
- (BOOL)isRunning { return _isRunning; }
- (BOOL)isScrubbing { return _isScrubbing; }
@end
