//
//  ZKMORGraph.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 25.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//


#ifndef __ZKMORGraph_h__
#define __ZKMORGraph_h__

#import "ZKMORConduit.h"
#import "ZKMOROutput.h"

ZKMOR_C_BEGIN

///
///  ZKMORGraphNotificationCallback
///
///  Objects that want to get called back before/after graph rendering should 
///	 implement this function.
///
typedef ZKMORRenderFunction ZKMORGraphNotificationCallback;
	
///
///  ZKMORGraphListening
///
///  The protocol that graph delegates need to conform to.
///
@class ZKMORGraph;
@protocol ZKMORGraphListening

- (void)changedSampleRateOnGraph:(ZKMORGraph *)graph;
- (void)receivedError:(OSStatus)error renderingGraph:(ZKMORGraph *)graph;
- (void)startedGraph:(ZKMORGraph *)graph;
- (void)stoppedGraph:(ZKMORGraph *)graph;

@end


///
///  ZKMORGraphState
///
///  Enums for the volitilie state of the graph.
///
enum
{
	kZKMORGraphState_Free = 0,
	kZKMORGraphState_Rendering = 1,
	kZKMORGraphState_Patching = 2
};



///
///  ZKMORGraph
///
///  A graph of ZKMORConduits
///
///  The way to create and manage a graph of ZKMORConduit objects. The ZKMORGraph is
///  itself a conduit object (with 0 input buses and the same number of output
///  buses as the head of the graph). ZKMORGraph has 0 input buses, because the way
///  to inject input into a graph is to connect a source conduit into the graph.
///
///  See the example programs to see how to use the ZMKORGraph.
///
///  Some notes: 
///		--  The graph will retain and manage the lifecycle of its dependents. This means the
///			graph will initialize, uninitialize, start, and stop dependents as necessary.
///
///		--	Although it is not the only way to envision the graph, the prepositions 
///			(before/after) used in function names are a consequence of thinking of the graph 
///			going left to right, and top to bottom, e.g.:
///
///				FileReader --> AudioUnit --> DAC
///
///			The signal chain starts with the FileReader and the AudioUnit comes "after" 
///			the FileReader.
///
///		--	You should be able to make changes to the graph in any thread.
///			If the graph is not running, there is no problem. If the graph is running, the running thread
///			will not actually pull the graph while the changes are pending. While changes are pending, the
///			graph will return silence, and then continue rendering once the changes go through. This may be
///			improved in the future to keep the graph running while changes are pending and then do make the
///			changes in the render thread when they have been accepted.
///
@class ZKMORAudioUnit;
@interface ZKMORGraph : ZKMORConduit <ZKMORStarting> {
		// graph properties
	BOOL			_isRunning;
	Float64			_graphSampleRate;
	ZKMORConduit*	_head;
		// a set of conduits that are dependent on the graph 
	NSMutableSet*	_dependentConduits;
	NSMutableArray* _renderNotifications;
	id				_delegate;
		// the output the graph is connected to (if there is one)
	ZKMOROutput*	_output;
		// to handle nested invokations to beginPatching / endPatching
	int				_patchingDepth;
		// state during a render
	int				_renderDepth;
	volatile UInt32	_graphState;
}

//  Graph State
	/// the head -- the last object to apply processing to the graph
- (ZKMORConduit *)head;
- (void)setHead:(ZKMORConduit *)head;

- (Float64)graphSampleRate;
- (void)setGraphSampleRate:(Float64)graphSampleRate;

//  Delegate
- (id)delegate;
	/// delegate does *not* get retained by the graph
- (void)setDelegate:(id <ZKMORGraphListening>)delegate;

//  Dependents
- (void)addDependentConduit:(ZKMORConduit *)conduit;
- (void)removeDependentConduit:(ZKMORConduit *)conduit;

//  Render Notifications
	/// don't add or remove render notifications if the graph is running in another thread
- (void)addRenderNotification:(ZKMORGraphNotificationCallback)callback refCon:(id)refCon;
- (void)removeRenderNotification:(ZKMORGraphNotificationCallback)callback refCon:(id)refCon;

//  Queries
- (BOOL)isRunning;

@end

///
///  ZKMORGraphPatching
///
///  Methods for patching objects in a graph. If the graph is running, this will notify the render
///  thread that the graph is being modified and will have that thread return silence until the
///	 changes are complete.
///
@interface ZKMORGraph (ZKMORGraphPatching)

//  Patching Boundry
	/// call before starting to patch. These can be nested each is accompanied by an endPatching.
- (void)beginPatching;
	/// call when finished patching. Makes all the changes happen.
- (void)endPatching;

//  Patching
	/// patchBus:into: will try to make the input accept the
	/// output's format (it doesn't already). This may throw an exception.
	/// N. B. Do not call from the render callback! Use inRenderCallbackPatchBus:into: .
- (void)patchBus:(ZKMOROutputBus *)output into:(ZKMORInputBus *)input;
- (void)disconnectBus:(ZKMOROutputBus *)output from:(ZKMORInputBus *)input;
- (void)disconnectOutputToInputBus:(ZKMORInputBus *)input;

//  Patching within the render callaback
- (void)inRenderCallbackPatchBus:(ZKMOROutputBus *)output into:(ZKMORInputBus *)input;


//  Information
- (ZKMOROutputBus *)sourceForInputBus:(ZKMORInputBus *)input;
- (ZKMORInputBus *)destinationForOutputBus:(ZKMOROutputBus *)output;

@end



///
///  ZKMORGraphPatchingInternal
///
///  Internal functions used by other Sycamore objects for communicating with graph.
///
@interface ZKMORGraph (ZKMORGraphPatchingInternal)

- (void)changedStreamFormatOnConduitBus:(ZKMORConduitBus *)bus;
- (void)changedNumberOfOutputBusesOnHead;
	/// Dispatches to the input bus to accept the output bus. The canonical behavior is to set
	/// the input bus' stream format to the output bus' stream format.
- (BOOL)preparePatchBus:(ZKMOROutputBus *)output into:(ZKMORInputBus *)input error:(NSError **)error;

- (ZKMOROutput *)output;
- (void)setOutput:(ZKMOROutput *)output;

@end

///
///  ZKMORGraphStruct
/// 
///  The struct form of the graph, for digging into the state of the object (used to
///  improve performance)
///
typedef struct { @defs(ZKMORGraph) } ZKMORGraphStruct;

// Internal C Functions 
OSStatus	GraphAudioUnitRenderCallback(	void* inRefCon, AudioUnitRenderActionFlags* ioActionFlags, 
											const AudioTimeStamp* inTimeStamp, UInt32 inOutputBusNumber, 
											UInt32 inNumberFrames, AudioBufferList* ioData);

void GraphConnectInAudioUnit(ZKMORGraph* graph, ZKMORAudioUnit* audioUnit);

void GraphPropertyListener(		void* SELF, AudioUnit ci, AudioUnitPropertyID inID, AudioUnitScope inScope, 
								AudioUnitElement inElement);


OSStatus GraphRenderFromNode(	ZKMORGraphStruct			* graphStruct,
								ZKMOROutputBus				* node,
								AudioUnitRenderActionFlags 	* ioActionFlags,
								const AudioTimeStamp 		* inTimeStamp,
								UInt32						inOutputBusNumber,
								UInt32						inNumberFrames,
								AudioBufferList				* ioData);

OSStatus GraphRenderFunction(	id							SELF,
								AudioUnitRenderActionFlags 	* ioActionFlags,
								const AudioTimeStamp 		* inTimeStamp,
								UInt32						inOutputBusNumber,
								UInt32						inNumberFrames,
								AudioBufferList				* ioData);

ZKMOR_C_END

#endif  __ZKMORGraph_h__