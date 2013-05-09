//
//  ZKMORClock.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 10.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORClock_h__
#define __ZKMORClock_h__

#import "ZKMORCore.h"
#import <AudioToolbox/AudioToolbox.h>

///
///  ZKMORClock
/// 
///  Keeps track of time.
///
@class ZKMORDeviceOutput;
@interface ZKMORClock : NSObject {
	CAClockRef	_clockRef;
	BOOL		_isRunning;
	BOOL		_isScrubbing, _wasRunning;
	
	Float64 prevTimeSeconds;
}

//  Accessors
- (CAClockRef)clockRef;

- (Float64)currentTimeSeconds;
	/// Can set time only if the clock is not running
- (void)setCurrentTimeSeconds:(Float64)currentTimeSeconds;

- (void)setTimebaseDeviceOutput:(ZKMORDeviceOutput *)deviceOutput;

//  Actions
	/// start slaves the clock to a timebase. If you want to manually advance the clock, do not call start.
- (void)start;
	/// see start
- (void)stop;

	/// put the clock into a mode where the user controls the position
- (void)beginScrubbing;
	/// exit scrubbing mode
- (void)endScrubbing;

//  Queries
- (BOOL)isRunning;
- (BOOL)isScrubbing;

@end

#endif __ZKMORClock_h__