//
//  ZKMNREventScheduler.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 09.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMNREventScheduler_h__
#define __ZKMNREventScheduler_h__

#import <Cocoa/Cocoa.h>
#import "ZKMORClock.h"
#import "ZKMORGraph.h"

///
///  ZKMNREventTaskTimeRange
///
///  Description of the time range for event execution.
///
typedef struct {
	Float64			start;
	Float64			end;
	Float64			duration;
	UInt32			numberOfSamples;
} ZKMNREventTaskTimeRange;




/// 
///  ZKMNREventDebugLevel
///
///  Way to turn on/off logging when specific events happen. This can be on the
///  scheduler for all events, or on the individual events themselves.
///
enum 
{ 
	kZKMNREventDebugLevel_None		= 0,
	kZKMNREventDebugLevel_Task		= (1L << 1),
	kZKMNREventDebugLevel_Activate	= (1L << 2),
	kZKMNREventDebugLevel_Cleanup	= (1L << 3)
};




///
///  ZKMNRTimeDependent
///
///  Things that follow time.
///
@class ZKMNREvent, ZKMNREventScheduler;
@protocol ZKMNRTimeDependent
- (void)acceptEvent:(ZKMNREvent *)event time:(Float64)now;
- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler;
- (void)scrub:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler;
@end



///
///  ZKMNREventScheduler
///
///  A scheduler for events based on audio time.
///
///  NOTE: The scheduler is currently designed to run in the UI thread, not the audio thread. This obviously
///  impacts the accuracy of the scheduling. In the future, the scheduler will be modified to run in the audio thread
///  and accept events from other threads.
///
@interface ZKMNREventScheduler : NSObject <ZKMORGraphListening> {
	ZKMORClock*			_clock;
	ZKMORGraph*			_graph;
	Float64				_sampleRate;
		/// _timeDependents get tasked when the scheduler gets tasked
	NSMutableArray*		_timeDependents;
		/// the events to schedule, stored in a priority queue
	CFBinaryHeapRef		_eventsQueue;
	
	unsigned			_debugLevel;
}
//  Accessors
- (CFIndex)numberOfEvents;
	/// event is retained by the scheduler
- (void)scheduleEvent:(ZKMNREvent *)event;
- (void)unscheduleAllEvents;

	/// Time dependents get tasked when the scheduler gets tasked. They are *not* retained by the scheduler.
- (void)addTimeDependent:(id <ZKMNRTimeDependent>)timeDependent;
- (void)removeTimeDependent:(id <ZKMNRTimeDependent>)timeDependent;

- (ZKMORClock *)clock;
- (void)setClock:(ZKMORClock *)clock;

//  Actions
	/// Run the scheduler from now to now + seconds
- (void)task:(Float64)duration;

@end

@interface ZKMNREventScheduler (ZKMNREventSchedulerDebugging)
- (unsigned)debugLevel;
	/// ZKMNREventDebugLevels may be or'd together for debugLevel
- (void)setDebugLevel:(unsigned)debugLevel;
@end



///
///  ZKMNREvent
///
///  An event.
///
@interface ZKMNREvent : NSObject {
	Float64					_startTime;
	Float64					_duration;
	id <ZKMNRTimeDependent> _target;
	
	unsigned				_debugLevel;
}

//  Accessors
- (Float64)startTime;
- (void)setStartTime:(Float64)startTime;

- (Float64)duration;
- (void)setDuration:(Float64)duration;

- (id <ZKMNRTimeDependent>)target;
- (void)setTarget:(id <ZKMNRTimeDependent>)target;

//  Actions
	/// The default implementation asks my target to accept me.
- (void)activate:(ZKMNREventTaskTimeRange *)timeRange;
- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler;
- (void)cleanup:(Float64)now;

//  Queries
- (BOOL)fallsBeforeTime:(Float64)time;

@end

@interface ZKMNREvent (ZKMNREventDebugging)
- (unsigned)debugLevel;
	/// ZKMNREventDebugLevels may be or'd together for debugLevel
- (void)setDebugLevel:(unsigned)debugLevel;
@end

///
///  Utility Functions
///
ZKMOR_C_BEGIN

float	ZKMNRPercentDone(Float64 startTime, Float64 duration, Float64 now);
float	ZKMNRInterpolateValue(float startValue, float endValue, float percent);

ZKMOR_C_END

#endif
