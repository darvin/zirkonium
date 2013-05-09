//
//  ZKMNREventScheduler.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 09.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNREventScheduler.h"
#import "ZKMORLogger.h"
#import "ZKMORUtilities.h"


typedef struct {
	unsigned		currentElement;
	unsigned		level;
	unsigned		source;
	unsigned		indent;
} LoggerStateStruct;

static void ZKMNREventQLogger(const void *val, void *context)
{
	ZKMNREvent* event = (ZKMNREvent*) val;
	LoggerStateStruct* state = (LoggerStateStruct*) context;
	[event logAtLevel: state->level source: state->source indent: (state->indent + 1) tag: [NSString stringWithFormat: @"%4.3f", [event startTime]]];
	state->currentElement++;
}

static const void* ZKMNREventQRetain(CFAllocatorRef allocator, const void *ptr)
{
	ZKMNREvent* event = (ZKMNREvent*) ptr;
	return [event retain];
}

static void ZKMNREventQRelease(CFAllocatorRef allocator, const void *ptr)
{
	ZKMNREvent* event = (ZKMNREvent*) ptr;
	[event release];
}

static CFStringRef ZKMNREventCopyDescription(const void* ptr) 
{
	ZKMNREvent* event = (ZKMNREvent*) ptr;
	CFStringRef desc = (CFStringRef) [event description];
	return desc;
}

static CFComparisonResult ZKMNREventCompare(const void* ptr1, const void* ptr2, void* context)
{
	ZKMNREvent* event1 = (ZKMNREvent*) ptr1;
	ZKMNREvent* event2 = (ZKMNREvent*) ptr2;
	Float64 elt1StartTime = [event1 startTime];
	Float64 elt2StartTime = [event2 startTime];
	
	if (elt1StartTime < elt2StartTime) return kCFCompareLessThan;
	if (elt1StartTime == elt2StartTime) return kCFCompareEqualTo;
	return kCFCompareGreaterThan;		
}

@implementation ZKMNREventScheduler
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (_eventsQueue) CFRelease(_eventsQueue);
	if (_timeDependents) [_timeDependents release];
	[super dealloc];
}

- (id)init 
{
	if (!(self = [super init])) return nil;

	// create a priority queue
	CFBinaryHeapCallBacks callbacks;
	callbacks.version = 0;
	callbacks.retain = ZKMNREventQRetain;
	callbacks.release = ZKMNREventQRelease;
	callbacks.copyDescription = ZKMNREventCopyDescription;
	callbacks.compare = ZKMNREventCompare;

	// allocator, max num events, callbacks, compare context -- not used
	_eventsQueue = CFBinaryHeapCreate(kCFAllocatorDefault, 0, &callbacks, NULL);
	
	_timeDependents = [[NSMutableArray alloc] init];
	_clock = nil;
	_debugLevel = 0;
	
	return self;
}

#pragma mark _____ Accessors
- (CFIndex)numberOfEvents { return CFBinaryHeapGetCount(_eventsQueue); }
- (void)scheduleEvent:(ZKMNREvent *)event { CFBinaryHeapAddValue(_eventsQueue, event); }
- (void)unscheduleAllEvents { CFBinaryHeapRemoveAllValues(_eventsQueue); }

- (void)addTimeDependent:(id <ZKMNRTimeDependent>)timeDependent { [_timeDependents addObject: timeDependent]; }
- (void)removeTimeDependent:(id <ZKMNRTimeDependent>)timeDependent { [_timeDependents removeObject: timeDependent]; }

- (ZKMORClock *)clock { return _clock; }
- (void)setClock:(ZKMORClock *)clock { _clock = clock; }

- (ZKMORGraph *)graph { return _graph; }
- (void)setGraph:(ZKMORGraph *)graph 
{ 
	if (_graph) [_graph setDelegate: nil];
	_graph = graph;
	if (_graph) [_graph setDelegate: self];
}

#pragma mark _____ Actions
- (void)task:(Float64)duration 
{  
	// set up the time info
	Float64 start = [_clock currentTimeSeconds], end = start + duration;
	if (_debugLevel & kZKMNREventDebugLevel_Task) [self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Scheduler indent: 0 tag: [NSString stringWithFormat: @"\nTask Start at %4.3f->%4.3f", start, end]];

		// create a range to represent the range being scheduled
	ZKMNREventTaskTimeRange range = { start, end, duration, duration * _sampleRate };
	
	// pull the next event out of the queue
	ZKMNREvent* event = (ZKMNREvent *) CFBinaryHeapGetMinimum(_eventsQueue);
	
	while ((event != NULL) && [event fallsBeforeTime: end]) {
		if (_debugLevel & kZKMNREventDebugLevel_Activate) [event logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Scheduler indent: 0 tag: @"Activate"];
			// activate the event
		[event activate: &range];
			// dequeue the event
		CFBinaryHeapRemoveMinimumValue(_eventsQueue);
			// pull the next event out of the queue
		event = (ZKMNREvent *) CFBinaryHeapGetMinimum(_eventsQueue);
	}

	// task the dependents from now to now + duration
	NSEnumerator* deps = [_timeDependents objectEnumerator];
	id <ZKMNRTimeDependent> dep;
	BOOL isScrubbing = [_clock isScrubbing];
	while (dep = [deps nextObject]) (isScrubbing) ? [dep scrub: &range scheduler: self] : [dep task: &range scheduler: self];

	if (_debugLevel & kZKMNREventDebugLevel_Task) [self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Scheduler indent: 0 tag: [NSString stringWithFormat: @"\nTask End at %4.3f->%4.3f", start, end]];
}

#pragma mark _____ ZKMNREventSchedulerDebugging
- (unsigned)debugLevel { return _debugLevel; }
- (void)setDebugLevel:(unsigned)debugLevel { _debugLevel = debugLevel; }

#pragma mark _____ ZKMORGraphListening
- (void)changedSampleRateOnGraph:(ZKMORGraph *)graph { }
- (void)receivedError:(OSStatus)error renderingGraph:(ZKMORGraph *)graph { }
- (void)startedGraph:(ZKMORGraph *)graph { }
- (void)stoppedGraph:(ZKMORGraph *)graph { }

#pragma mark _____ ZKMORConduitLogging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	
	unsigned myLevel = level | kZKMORLogLevel_Continue;

	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(myLevel, source, CFSTR("%s%u Events"), indentStr, CFBinaryHeapGetCount(_eventsQueue));
	LoggerStateStruct loggerState = { 0, myLevel, source, indent};
	CFBinaryHeapApplyFunction(_eventsQueue, ZKMNREventQLogger, &loggerState);
}

@end

@implementation ZKMNREvent
#pragma mark _____ NSObject Overrides
- (id)init 
{
	if (!(self = [super init])) return nil;

	_startTime = _duration = 0.;
	_target = nil;
	
	return self;
}

#pragma mark _____ Accessors
- (Float64)startTime { return _startTime; }
- (void)setStartTime:(Float64)startTime { _startTime = startTime; }
- (Float64)duration { return _duration; }
- (void)setDuration:(Float64)duration { _duration = duration; }
- (id <ZKMNRTimeDependent>)target { return _target; }
- (void)setTarget:(id <ZKMNRTimeDependent>)target { _target = target; }

#pragma mark _____ Actions
- (void)activate:(ZKMNREventTaskTimeRange *)timeRange
{ 
	if (_debugLevel & kZKMNREventDebugLevel_Activate) [self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Scheduler indent: 0 tag: @"Activate"];
	// TODO -- make acceptEvent:time: take a range instead of just a time
	Float64 now = timeRange->end;
	[_target acceptEvent: self time: now]; 
}
- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler { }
- (void)cleanup:(Float64)now { }

#pragma mark _____ Queries
- (BOOL)fallsBeforeTime:(Float64)time { return _startTime < time; }

#pragma mark _____ ZKMNREventDebugging
- (unsigned)debugLevel { return _debugLevel; }
- (void)setDebugLevel:(unsigned)debugLevel { _debugLevel = debugLevel; }

@end

float	ZKMNRPercentDone(Float64 startTime, Float64 duration, Float64 now) { return (float) ((now - startTime) / duration); }

float	ZKMNRInterpolateValue(float startValue, float endValue, float percent)
{
//	return (1.f - percent) * startValue + (percent * endValue);
	return ZKMORInterpolateValue(startValue, endValue, percent);
}
