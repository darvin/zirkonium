//
//  ZKMOROutput.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 10.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMOROutput_h__
#define __ZKMOROutput_h__

#import "ZKMORCore.h"


///
///  ZKMORStarting
/// 
///  The protocol for conduits that implement start and stop
///
@protocol ZKMORStarting
	// these may throw exceptions (especially start)
- (void)preroll;
- (void)start;
- (void)stop;

@end



///
///  ZKMOROutput
/// 
///  Calls a graph for data.
///
@class ZKMORGraph, ZKMORClock;
@interface ZKMOROutput : NSObject <ZKMORStarting> {
	ZKMORGraph*		_graph;
	ZKMORClock*		_clock;
	BOOL			_isRunning;
}

//  Accessors
- (ZKMORGraph *)graph;
- (void)setGraph:(ZKMORGraph *)graph;

- (ZKMORClock *)clock;

//  Queries
- (BOOL)isRunning;

@end



///
///  ZKMOROutputTransport
///
///  Functions to control the transport.
///
@interface ZKMOROutput (ZKMOROutputTransport)

- (void)preroll;
- (void)start;
- (void)stop;
	/// puts the output into scrubbing mode and stops the clock if ncessary
- (void)beginScrubbing;
	/// restarts the clock if necessary
- (void)endScrubbing;

@end



///
///  ZKMOROutputInternal
///
///  Methods used by Sycamore objects to communicate with the output.
///
@interface ZKMOROutput (ZKMOROutputInternal)

- (void)graphOutputStreamFormatChanged;

@end

#endif __ZKMOROutput_h__
