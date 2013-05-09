//
//  ZKMOROutput.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 10.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMOROutput.h"
#import "ZKMORGraph.h"
#import "ZKMORClock.h"


@implementation ZKMOROutput
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (_graph) [_graph release];
	if (_clock) [_clock release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	_graph = nil;
	_clock = [[ZKMORClock alloc] init];
	return self;
}

- (ZKMORGraph *)graph { return _graph; }
- (void)setGraph:(ZKMORGraph *)graph 
{ 
	if (graph == _graph) return;
	if (_graph) [_graph release], _graph = nil;
	if (nil == graph) return;
	_graph = [graph retain];
	[_graph setOutput: self];
}

- (ZKMORClock *)clock { return _clock; }

#pragma mark _____ Queries
- (BOOL)isRunning { return _isRunning; }

- (void)graphOutputStreamFormatChanged { }

#pragma mark _____ ZKMOROutputTransport
	// subclass responsibility
- (void)preroll { }

- (void)start 
{ 
	_isRunning = YES; 
	if (_graph) [_graph start]; 
}

- (void)stop 
{ 
	_isRunning = NO;
	if (_graph) [_graph stop];
}

- (void)beginScrubbing { [_clock beginScrubbing]; }
- (void)endScrubbing { [_clock endScrubbing]; }

@end

