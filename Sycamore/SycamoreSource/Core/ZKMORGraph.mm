//
//  ZKMORGraph.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 25.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORGraph.h"
#import "ZKMORLogger.h"
#import "ZKMORException.h"
#import "ZKMORAudioUnit.h"
#import "ZKMORUtilities.h"
#import "CAAudioUnitZKM.h"
#import "CAStreamBasicDescription.h"


// A simple object to keep the notifications in an NSArray
@interface ZKMORGraphNotification : NSObject {
@public
	ZKMORGraphNotificationCallback	_callback;
	id								_refCon;
}

@end

OSStatus	 GraphAudioUnitRenderCallback(	void						* inRefCon, 
											AudioUnitRenderActionFlags	* ioActionFlags, 
											const AudioTimeStamp		* inTimeStamp, 
											UInt32						inOutputBusNumber, 
											UInt32						inNumberFrames, 
											AudioBufferList				* ioData)
{
	OSStatus err;
	
		// render from this node on down
	ZKMORInputBusStruct* inputBusStruct = (ZKMORInputBusStruct *)inRefCon;
	ZKMORGraph* graph = ((ZKMORConduitStruct *)inputBusStruct->_conduit)->_graph;
	ZKMORGraphStruct* graphStruct = (ZKMORGraphStruct*) graph;
	ZKMOROutputBus* outputBus = inputBusStruct->_feederBus;
	if (outputBus) {
		int renderDepth = graphStruct->_renderDepth;
		graphStruct->_renderDepth = renderDepth + 1;
		err = GraphRenderFromNode(graphStruct, outputBus, ioActionFlags, inTimeStamp, ((ZKMOROutputBusStruct*) outputBus)->_busNumber, inNumberFrames, ioData);
		graphStruct->_renderDepth = renderDepth;
	} else {
		// no follow on node -- memset the buffers to 0 and return
		ZKMORMakeBufferListSilent(ioData, ioActionFlags);
		err = noErr;
		
		if (ZKMORIsDebuggingOnBus((ZKMORConduitBus *)inputBusStruct, kZKMORDebugLevel_PreRender | kZKMORDebugLevel_PostRender)) {
			ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Graph, 
				CFSTR("End of graph branch %@:%u -- rendering silent"), 
				inputBusStruct, inOutputBusNumber);
		}	
	}
	
	return err;
}												

void GraphConnectInAudioUnit(ZKMORGraph* graph, ZKMORAudioUnit* audioUnit)
{
	// make sure we are patched into all the buses
	UInt32 busCount, dataSize = sizeof(UInt32);
	AudioUnitGetProperty(	[audioUnit audioUnit], kAudioUnitProperty_BusCount, kAudioUnitScope_Input,	0,
							&busCount, &dataSize);
							
	UInt32 i;
	for (i = 0; i < busCount; i++) {
		ZKMORInputBus* inputBus = [audioUnit inputBusAtIndex: i];
		AURenderCallbackStruct callback = { GraphAudioUnitRenderCallback, inputBus };
		[audioUnit setCallback: &callback busNumber: i];
	}
}

void GraphPropertyListener(		void*						SELF,
								AudioUnit					ci, 
								AudioUnitPropertyID			inID, 
								AudioUnitScope				inScope, 
								AudioUnitElement			inElement)
{
	ZKMORAudioUnit* au = (ZKMORAudioUnit*) SELF;
	ZKMORGraph* graph = (ZKMORGraph*) [au graph];
	ZKMORConduit* head = [graph head];
	
	if (kAudioUnitProperty_BusCount == inID) {
		if (kAudioUnitScope_Input == inScope) {
			GraphConnectInAudioUnit(graph, au);
		} else if (kAudioUnitScope_Output == inScope && (au == head)) {
			[graph changedNumberOfOutputBusesOnHead];
		}
	}
	
	if (kAudioUnitProperty_StreamFormat == inID) {
		if (kAudioUnitScope_Input == inScope)
			[graph changedStreamFormatOnConduitBus: [au inputBusAtIndex: inElement]];
		else if (kAudioUnitScope_Output == inScope)
			[graph changedStreamFormatOnConduitBus: [au outputBusAtIndex: inElement]];
		else 
			ZKMORLogError(kZKMORLogSource_Graph, CFSTR("Got stream format change on global scope of %@"), au);
	}	
}

static void GraphProcessRenderNotifications(	ZKMORGraphStruct			* graphStruct,
												AudioUnitRenderActionFlags 	* ioActionFlags,
												const AudioTimeStamp 		* inTimeStamp,
												UInt32						inOutputBusNumber,
												UInt32						inNumberFrames,
												AudioBufferList				* ioData)
{
	CFArrayRef notifications = (CFArrayRef) graphStruct->_renderNotifications;
	CFIndex i, count = CFArrayGetCount(notifications);
	for (i = count - 1; i >= 0; --i) {
		ZKMORGraphNotification* notification = (ZKMORGraphNotification*) CFArrayGetValueAtIndex(notifications, i);
		OSStatus err = notification->_callback(notification->_refCon, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
		ZKMORLogError(kZKMORLogSource_Graph, CFSTR("Error calling notification on 0x%x : %i"), notification->_refCon, err);
	}
}										

OSStatus GraphRenderFromNode(	ZKMORGraphStruct			* graphStruct,
								ZKMOROutputBus				* node,
								AudioUnitRenderActionFlags 	* ioActionFlags,
								const AudioTimeStamp 		* inTimeStamp,
								UInt32						inOutputBusNumber,
								UInt32						inNumberFrames,
								AudioBufferList				* ioData)
{
	ZKMOROutputBusStruct* outputStruct = (ZKMOROutputBusStruct*) node;
	ZKMORConduitStruct* conduitStruct = (ZKMORConduitStruct*) outputStruct->_conduit;
	OSStatus err = noErr;
	int renderDepth = graphStruct->_renderDepth;
	BOOL providesData = (conduitStruct->_isGraphConnectionOwner) || (conduitStruct->_conduitType & kZKMORConduitType_Source);
	if (!providesData) { 
		// recurse to feeder, assumed to be the input bus with the same index
		ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*) CFArrayGetValueAtIndex((CFArrayRef) conduitStruct->_inputBuses, inOutputBusNumber);
		ZKMOROutputBus* feeder = inputStruct->_feederBus;
		graphStruct->_renderDepth = renderDepth + 1;
		err = GraphRenderFromNode(graphStruct, feeder, ioActionFlags, inTimeStamp, ((ZKMOROutputBusStruct *) feeder)->_busNumber, inNumberFrames, ioData);
		graphStruct->_renderDepth = renderDepth;
		if (err) return err;
	} 
	
	ZKMORRenderFunction func = conduitStruct->_renderFunction;
	if (ZKMORIsDebuggingOnBus((ZKMORConduitBus *) outputStruct, kZKMORDebugLevel_PreRender)) {
		char indentStr[16];
		ZKMORGenerateIndentString(indentStr, 16, renderDepth);
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Graph, CFSTR("\n%sPre-Render  %@ (Depth %i)"), indentStr, outputStruct, renderDepth);
		ZKMORLogBufferList(kZKMORLogLevel_Debug | kZKMORLogLevel_Continue, renderDepth, ioData);
	}

	err = func(outputStruct->_conduit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);

	if (err) {
		switch (err) {
			case paramErr: 
				ZKMORLogError(kZKMORLogSource_Graph, CFSTR("paramErr rendering bus %@ -- conduit is probably uninintialized or the AudioBufferList has the wrong format."), outputStruct);
				break;
			default: 
				ZKMORLogError(kZKMORLogSource_Graph, CFSTR("Error %i rendering bus %@"), err, outputStruct);
		}
	}
	
	if (ZKMORIsDebuggingOnBus((ZKMORConduitBus *) outputStruct, kZKMORDebugLevel_PostRender)) {
		char indentStr[16];
		ZKMORGenerateIndentString(indentStr, 16, renderDepth);
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Graph, CFSTR("\n%sPost-Render %@ (Depth %i)"), indentStr, outputStruct, renderDepth);
		ZKMORLogBufferList(kZKMORLogLevel_Debug | kZKMORLogLevel_Continue, renderDepth, ioData);
	}
		
	return err;
}

OSStatus GraphRenderFunction(	id							SELF,
								AudioUnitRenderActionFlags 	* ioActionFlags,
								const AudioTimeStamp 		* inTimeStamp,
								UInt32						inOutputBusNumber,
								UInt32						inNumberFrames,
								AudioBufferList				* ioData)
{
	ZKMORGraphStruct* graphStruct = (ZKMORGraphStruct*) SELF;
	ZKMORConduitStruct* headStruct = (ZKMORConduitStruct*) graphStruct->_head;
	ZKMOROutputBus* node = (ZKMOROutputBus*) CFArrayGetValueAtIndex((CFArrayRef) headStruct->_outputBuses, inOutputBusNumber);
	
	if (!CompareAndSwap(kZKMORGraphState_Free, kZKMORGraphState_Rendering, (UInt32*)&graphStruct->_graphState)) {
		// someone is doing something to the graph -- just clear the buffer and return noErr
		ZKMORMakeBufferListSilent(ioData, ioActionFlags);
		return noErr;
	}
 
	graphStruct->_renderDepth = 0;
	AudioUnitRenderActionFlags myFlags = *ioActionFlags | kAudioUnitRenderAction_PreRender;
	GraphProcessRenderNotifications(graphStruct, &myFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	
	OSStatus err = GraphRenderFromNode(graphStruct, node, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	
	myFlags = *ioActionFlags | kAudioUnitRenderAction_PostRender;
	GraphProcessRenderNotifications(graphStruct, &myFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	
	if (err && graphStruct->_delegate)
		[graphStruct->_delegate receivedError: err renderingGraph: SELF];
		
	CompareAndSwap(kZKMORGraphState_Rendering, kZKMORGraphState_Free, (UInt32*)&graphStruct->_graphState);

	return err;
}


@implementation ZKMORGraph

- (void)dealloc {
	[_dependentConduits release];
	[_renderNotifications release];
	[super dealloc];
}

- (id)init {
	if (!(self = [super init])) return nil;

	_conduitType = kZKMORConduitType_Source;
	_isRunning = NO;
	_graphSampleRate = ZKMORDefaultSampleRate();
	_dependentConduits = [[NSMutableSet alloc] init];
	_renderNotifications = [[NSMutableArray alloc] init];
	_delegate = nil;
	_patchingDepth = 0;
	_graphState = kZKMORGraphState_Free;
	_output = nil;
	
	return self;
}

#pragma mark _____ Graph State
- (ZKMORConduit *)head { return _head; }
- (void)setHead:(ZKMORConduit *)head 
{
	[self addDependentConduit: head];
	_areBusesInitialized = NO;
		// initialy set the sample rate on the head to the graph's sample rate.
	[head graphSampleRateChanged: _graphSampleRate];
	_head = head;
		// fire the configuration mechanism after a stream format change
	[self changedStreamFormatOnConduitBus: [head outputBusAtIndex: 0]];
	
	if (kZKMORDebugLevel_Connect & _debugLevel) {
		[head logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Graph indent: 0 tag: @"Set Head:"];
		[self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Graph indent: 0 tag: @"Post-SetHead Graph:"];
	}
}

- (Float64)graphSampleRate { return _graphSampleRate; }
- (void)setGraphSampleRate:(Float64)graphSampleRate
{
		// nothing to do
	if (graphSampleRate == _graphSampleRate) return;
	
	if (kZKMORDebugLevel_SRate & _debugLevel) {
		ZKMORLogDebug(CFSTR("Change Graph Srate from %.1f to %.1f"), _graphSampleRate, graphSampleRate);
	}
	
	BOOL isRunning = [self isRunning];
	if (isRunning) [self stop];
	_graphSampleRate = graphSampleRate;
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSEnumerator* setEnumerator = 
			[_dependentConduits objectEnumerator];
		ZKMORConduit* conduit;
		while (conduit = [setEnumerator nextObject]) {
			[conduit graphSampleRateChanged: _graphSampleRate];
		}
    [pool release];
	if (_delegate) [_delegate changedSampleRateOnGraph: self];
	if (isRunning) [self start];
}

#pragma mark _____ Delegate
- (id)delegate { return _delegate; } 
- (void)setDelegate:(id <ZKMORGraphListening>)delegate { _delegate = delegate; }

#pragma mark _____ Dependents
- (void)addDependentConduit:(ZKMORConduit *)conduit
{
	if ([conduit graph] == self) return;
	
	[conduit setGraph: self];
	[_dependentConduits addObject: conduit];
	[conduit graphSampleRateChanged: _graphSampleRate];
	
	if ([conduit isKindOfClass: [ZKMORAudioUnit class]]) {
		ZKMORAudioUnit* audioUnit = (ZKMORAudioUnit*) conduit; 
		GraphConnectInAudioUnit(self, audioUnit);
		CAAudioUnitZKM* au = [audioUnit caAudioUnit];
		au->AddPropertyListener(kAudioUnitProperty_BusCount, GraphPropertyListener, audioUnit);
//		au->AddPropertyListener(kAudioUnitProperty_SampleRate, GraphPropertyListener, audioUnit);	
		au->AddPropertyListener(kAudioUnitProperty_StreamFormat, GraphPropertyListener, audioUnit);
	}
}

- (void)removeDependentConduit:(ZKMORConduit *)conduit
{
	unsigned i, count = [conduit numberOfOutputBuses];
	for (i = 0; i < count; i++) {
		ZKMOROutputBus* outputBus = [conduit outputBusAtIndex: i];
		ZKMORInputBus* inputBus =	[self destinationForOutputBus: outputBus];
		[self disconnectBus: outputBus from: inputBus];
	}

	if ([_dependentConduits containsObject: conduit]) [_dependentConduits removeObject: conduit];
}

#pragma mark _____ Render Notifications
- (void)addRenderNotification:(ZKMORGraphNotificationCallback)callback refCon:(id)refCon 
{
	ZKMORGraphNotification* notification = [[ZKMORGraphNotification alloc] init];
	notification->_callback = callback;
	notification->_refCon = refCon;
	[_renderNotifications addObject: notification];
	[notification release];
}

- (void)removeRenderNotification:(ZKMORGraphNotificationCallback)callback refCon:(id)refCon 
{
	int i, count = [_renderNotifications count];
	for (i = count - 1; i >= 0; --i) {
		ZKMORGraphNotification* notification = [_renderNotifications objectAtIndex: i];
		if ((notification->_callback == callback) && (notification->_refCon == refCon)) {
			[_renderNotifications removeObject: notification];
			break;
		}
	}
}

#pragma mark _____ Queries
- (BOOL)isRunning { return _isRunning; }

#pragma mark _____ ZKMORGraphPatching
- (void)beginPatching 
{ 
	if (_patchingDepth < 1) {
		// take over the graph
		while (!CompareAndSwap(kZKMORGraphState_Free, kZKMORGraphState_Patching, (UInt32*)&_graphState))
			usleep(100);
	}
	++_patchingDepth; 
}
- (void)endPatching 
{ 
	if (_patchingDepth < 1) return;
	
	if (--_patchingDepth < 1) {
			// free control of the graph -- this should only fail if an endPatching was called w/o a beginPatching
		if (!CompareAndSwap(kZKMORGraphState_Patching , kZKMORGraphState_Free, (UInt32*)&_graphState))
			ZKMORThrow(GraphError, @"Called endPatching without a beginPatching");
		_patchingDepth = 0;
	}	
}

- (void)patchBus:(ZKMOROutputBus *)output into:(ZKMORInputBus *)input
{
	if (_patchingDepth < 1)
		ZKMORThrow(GraphError, @"Can not patch on graph without a beginPatching call");
		
	if (!output) {
		ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
		inputStruct->_feederBus = nil;
		return;
	}
			
	// TODO Check that the output isn't already the input
	
	[self addDependentConduit: [output conduit]];
	[self addDependentConduit: [input conduit]];
	
	NSError* error;
	if (![self preparePatchBus: output into: input error: &error])
		ZKMORThrow(GraphError, @"Could not match stream formats %@", error);
		
	ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
	ZKMOROutputBusStruct* outputStruct = (ZKMOROutputBusStruct*)output;	
	inputStruct->_feederBus = output;
	outputStruct->_receiverBus = input;

	if (kZKMORDebugLevel_Connect & _debugLevel)
		[self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Graph indent: 0 tag: @"Patch Bus:"];
}

- (void)disconnectBus:(ZKMOROutputBus *)output from:(ZKMORInputBus *)input
{
	ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
	ZKMOROutputBusStruct* outputStruct = (ZKMOROutputBusStruct*)output;
	if (!inputStruct) return;
	if (inputStruct->_feederBus != output) {
		ZKMORLogError(kZKMORLogSource_Graph, CFSTR("Cannot disconnect a buses that are not connected %@, %@"), output, input);
		return;
	}
	inputStruct->_feederBus = nil;
	if (!outputStruct) return;
	outputStruct->_receiverBus = nil;
}

- (void)disconnectOutputToInputBus:(ZKMORInputBus *)input
{
	ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
	ZKMOROutputBus* output = inputStruct->_feederBus;
	if (!output) return;
	
	[self disconnectBus: output from: input];
}

- (ZKMOROutputBus *)sourceForInputBus:(ZKMORInputBus *)input 
{ 
	ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
	return inputStruct->_feederBus;
}
- (ZKMORInputBus *)destinationForOutputBus:(ZKMOROutputBus *)output 
{ 
	ZKMOROutputBusStruct* outputStruct = (ZKMOROutputBusStruct*)output;
	return outputStruct->_receiverBus;
}

- (void)inRenderCallbackPatchBus:(ZKMOROutputBus *)output into:(ZKMORInputBus *)input
{
	if (!output) {
		ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
		inputStruct->_feederBus = nil;
		return;
	}
			
	ZKMORInputBusStruct* inputStruct = (ZKMORInputBusStruct*)input;
	ZKMOROutputBusStruct* outputStruct = (ZKMOROutputBusStruct*)output;	
	inputStruct->_feederBus = output;
	outputStruct->_receiverBus = input;

	if (kZKMORDebugLevel_Connect & _debugLevel)
		[self logAtLevel: kZKMORLogLevel_Debug source: kZKMORLogSource_Graph indent: 0 tag: @"Patch Bus:"];
}

#pragma mark _____ ZKMORGraphPatchingInternal
- (void)changedStreamFormatOnConduitBus:(ZKMORConduitBus *)bus;
{
	ZKMORConduit* conduit = [bus conduit];
		// in the future I might have to reconfigure the graph if one of the
		// elements in the graph changes its stream format, but at the moment
		// clients of the graph need to manually make any necessary adjustments
	if (conduit != [self head]) return;
	
		// my format is dependent on the head's format, so uninitialize the
		// buses
	_areBusesInitialized = NO;
	if (_output) [_output graphOutputStreamFormatChanged];
}

- (void)changedNumberOfOutputBusesOnHead { _areBusesInitialized = NO; }

- (BOOL)preparePatchBus:(ZKMOROutputBus *)output into:(ZKMORInputBus *)input error:(NSError **)error
{
	CAStreamBasicDescription inputFormat([input streamFormat]);
	CAStreamBasicDescription outputFormat([output streamFormat]);
	if (inputFormat == outputFormat)
		return YES;

	return [input preparePatch: output error: error];
}

- (ZKMOROutput *)output { return _output; }
- (void)setOutput:(ZKMOROutput *)output { _output = output; }

#pragma mark _____ ZKMORConduit Overrides
- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice 
{ 
	[super setMaxFramesPerSlice: maxFramesPerSlice];
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSEnumerator* setEnumerator = [_dependentConduits objectEnumerator];
		ZKMORConduit* conduit;
		while (conduit = [setEnumerator nextObject]) {
			[conduit setMaxFramesPerSlice: maxFramesPerSlice];
		}
    [pool release];
}

- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return [_head numberOfOutputBuses]; }


- (void)graphSampleRateChanged:(Float64)graphSampleRate
{
	// I'm a subgraph of another graph that changed -- change myself to synch with the parent
	[self setGraphSampleRate: graphSampleRate];
}

- (void)initialize
{
	BOOL isRunning = [self isRunning];
	if (isRunning) [self stop];
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSEnumerator* setEnumerator = 
			[_dependentConduits objectEnumerator];
		ZKMORConduit* conduit;
		while (conduit = [setEnumerator nextObject]) {
			[conduit initialize];
		}
    [pool release];
	
	[super initialize];
	if (isRunning) [self start];
}

- (void)uninitialize {
	if ([self isRunning]) 
		[self stop];
	// don't run though and uninitialize everything -- any changes
	// that require an uninitialization will then do an uninitialization.
	[super uninitialize];
}


- (void)preroll 
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSEnumerator* setEnumerator = 
			[_dependentConduits objectEnumerator];
		ZKMORConduit* conduit;
		while (conduit = [setEnumerator nextObject]) {
			if ([conduit isStartable])
				[(id <ZKMORStarting>) conduit preroll];
		}
	[pool release];
	
/*
	// do one call into the graph to make sure all code
	// paths are warmed up.
	ZKMORConduitBus* bus = [self outputBusAtIndex: 0];
	if (!bus) {
		ZKMORLogError(kZKMORLogSource_Graph, "Could not preroll -- Graph 0x%x returned nil for bus 0", self);
		return;
	}	
	
	
	const AudioStreamBasicDescription *streamDesc = [bus streamFormat];
	CAStreamBasicDescription streamFormat(*streamDesc);
	
	unsigned numFrames = 2;
	AUOutputBL aubl(streamFormat, numFrames);
	aubl.Allocate(numFrames);
	aubl.Prepare();
	AudioBufferList* abl = aubl.ABL();
	UInt32 flags = 0;
	CAAudioTimeStamp ts(0.0);
	
	ZKMORRenderFunction RenderFunc = [self renderFunction];
	OSStatus err = RenderFunc(self, &flags, &ts, 0, numFrames, abl);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Graph, "Preroll graph 0x%x returned err %i", err);
		return;
	}		

	// dispose of allocated memory
	aubl.Allocate(0);
*/
}

- (void)start {
	if (![self isInitialized])
		[self initialize];

	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSEnumerator* setEnumerator = 
			[_dependentConduits objectEnumerator];
		ZKMORConduit* head = [self head];		
		ZKMORConduit* conduit;
		while (conduit = [setEnumerator nextObject]) {
				// make sure head gets started last
			if ([conduit isStartable] && conduit != head)
				[(id <ZKMORStarting>) conduit start];
		}
		if ([head isStartable])
			[(id <ZKMORStarting>) head start];
	[pool release];
	
	if (_delegate) [_delegate startedGraph: self];
	_isRunning = YES;
}

- (void)stop 
{
	if ([[self head] isStartable]) {
		[((ZKMORConduit <ZKMORStarting> *) [self head]) stop];
	}
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSEnumerator* setEnumerator = 
			[_dependentConduits objectEnumerator];
		ZKMORConduit* head = [self head];
			// make sure head gets stopped first
		if ([head isStartable])
			[(id <ZKMORStarting>) head stop];			
		ZKMORConduit* conduit;
		while (conduit = [setEnumerator nextObject]) {
			if ([conduit isStartable] && conduit != head)
				[(id <ZKMORStarting>) conduit stop];
		}
	[pool release];
	if (_delegate) [_delegate stoppedGraph: self];
	_isRunning = NO;
}

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus 
{
	ZKMORConduitBusStruct* headBus = 
		(ZKMORConduitBusStruct*) [[self head] outputBusAtIndex: [bus busNumber]];
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct*) bus;		
	busStruct->_streamFormat = headBus->_streamFormat;
}


- (ZKMORRenderFunction)renderFunction {	return GraphRenderFunction; }

#pragma mark _____ ZKMORConduitLogging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	char indentStr[16];
	
	level = level | kZKMORLogLevel_Continue;
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(level, source, CFSTR("\t%sSRate %.2f"), indentStr, _graphSampleRate);
	ZKMORLog(level, source, CFSTR("\t%sHead %@"), indentStr, _head);
}
@end



@implementation ZKMORGraphNotification

@end
