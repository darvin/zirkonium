//
//  ZKMORRenderSimulator.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 28.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORRenderSimulator.h"
#import "ZKMORLogger.h"
#import "ZKMORGraph.h"
#import "ZKMORClock.h"

#include "CAStreamBasicDescription.h"
#include "AUOutputBL.h"
#include "CAAudioTimeStamp.h"

#include <unistd.h>


@implementation ZKMORRenderSimulator
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (_error) [_error release];
	[super dealloc];
}

#pragma mark _____ Accessing
- (ZKMORConduit *)conduit { return _conduit; }
- (void)setConduit:(ZKMORConduit *)conduit { _conduit = conduit; }
- (NSError *)error { return _error; }

#pragma mark _____ Actions
- (void)simulateNumCalls:(unsigned)numCalls numFrames:(unsigned)numFrames bus:(unsigned)busNumber 
{
	if (_error) [_error release];
	_error = nil;
	if (!_conduit) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Render simulator needs a conduit to simulate"));
		return;
	}
	
	ZKMORConduitBus* bus = [_conduit outputBusAtIndex: busNumber];
	if (!bus) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Conduit 0x%x returned nil for bus %u in simulator"), _conduit, busNumber);
		return;
	}	
	
	
	AudioStreamBasicDescription streamDesc = [bus streamFormat];
	CAStreamBasicDescription streamFormat(streamDesc);
	
	AUOutputBL aubl(streamFormat, numFrames);
	aubl.Allocate(numFrames);
	UInt32 flags = 0;
	CAAudioTimeStamp ts(0.0);
	
	ZKMORRenderFunction RenderFunc = [_conduit renderFunction];
	
	for (unsigned counter = 0; counter < numCalls; counter++) {
		aubl.Prepare();
		AudioBufferList* abl = aubl.ABL();
		OSStatus err = RenderFunc(_conduit, &flags, &ts, 0, numFrames, abl);
		if (err) {
			_error = [[NSError alloc] initWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
			break;
		}
		ts.mSampleTime += numFrames;
		// sleep briefly to let other threads run, if they need to
		usleep(1000);
	}
	
	// dispose of allocated memory
	aubl.Allocate(0);
}

@end

@implementation ZKMOROutputSimulator
#pragma mark _____ ZKMOROutput Overrides
- (void)dealloc
{
	if (_error) [_error release];
	[super dealloc];
}

- (void)setGraph:(ZKMORGraph *)graph
{
	[super setGraph: graph];
}

- (void)start 
{
	[super start];
	if (_error) [_error release];
	CAStreamBasicDescription format([[_graph outputBusAtIndex: 0] streamFormat]);
	mBufferList = new AUOutputBL(format, [_graph maxFramesPerSlice]);
	mBufferList->Allocate([_graph maxFramesPerSlice]);
	mTimeStamp = new CAAudioTimeStamp(0.0);
}

- (void)stop 
{
	mBufferList->Allocate(0);
	delete mBufferList; mBufferList = NULL;
	delete mTimeStamp; mTimeStamp = NULL;
	
	[super stop];
}

#pragma mark _____ Accessing
- (NSError *)error { return _error; }

#pragma mark _____ Actions
- (void)simulateNumCalls:(unsigned)numCalls numFrames:(unsigned)numFrames
{
	_error = nil;
	if (!_graph) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Render simulator needs a conduit to simulate"));
		return;
	}
	
	for (unsigned counter = 0; counter < numCalls; counter++) {
		AudioUnitRenderActionFlags ioActionFlags = 0;
		mBufferList->Prepare();
		OSStatus err = GraphRenderFunction(_graph, &ioActionFlags, mTimeStamp, 0, numFrames, mBufferList->ABL());
		if (err) {
			_error = [[NSError alloc] initWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
			break;
		}
		mTimeStamp->mSampleTime = mTimeStamp->mSampleTime += numFrames;
		[_clock setCurrentTimeSeconds: mTimeStamp->mSampleTime / [_graph graphSampleRate]];
		// sleep briefly to let other threads run, if they need to
		usleep(1000);
	}
}

@end
