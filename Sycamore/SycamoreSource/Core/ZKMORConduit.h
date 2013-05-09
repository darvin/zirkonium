//
//  ZKMORConduit.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 23.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  A Conduit is something which generates, process, or accepts audio.
//
//  For performance purposes, certain functions on Conduits are defined as
//  C functions which can be called directly, bypassing the Obj-C method look-up
//  mechanism.
//
//  The functions which fall into this catagory are:
// 
//		1. The render function -- generates / processes / consumes audio samples
//		2. The parameter get function -- returns the value of a parameter on the conduit
//		3. The parameter schedule functions -- schedules a change to a parameter within
//		   the next buffer to be rendered (i.e., for the best precision, this function
//		   should be called within the same thread as the render function executes in).
//

#ifndef __ZKMORConduit_h__
#define __ZKMORConduit_h__

#import <AudioUnit/AudioUnit.h>
#import "ZKMORCore.h"

ZKMOR_C_BEGIN

///
///  ZKMORRenderFunction
///
///  The function that gets called to generate samples. The same as an aduio unit render function, except
///  the first param is an id instead of a void*
///
typedef OSStatus (*ZKMORRenderFunction)(	id								SELF, 
											AudioUnitRenderActionFlags		* ioActionFlags,
											const AudioTimeStamp			* inTimeStamp,
											UInt32							inOutputBusNumber,
											UInt32							inNumberFrames,
											AudioBufferList					* ioData);



/// 
///  ZKMORConduitType
///
///  The different types of conduits -- each has some different properties.
///
enum 
{ 
	kZKMORConduitType_Source		= (1L << 0),
	kZKMORConduitType_Processor		= (1L << 1), 
	kZKMORConduitType_Sink			= (1L << 2)
};



/// 
///  ZKMORDebugLevel
///
///  Way to turn on/off logging when specific events happen on conduits.
///
enum 
{ 
	kZKMORDebugLevel_None			= 0,
	kZKMORDebugLevel_PreRender		= (1L << 1),
	kZKMORDebugLevel_PostRender		= (1L << 2),
	kZKMORDebugLevel_Connect		= (1L << 3),
	kZKMORDebugLevel_SRate			= (1L << 4),
	kZKMORDebugLevel_All			= ((1L << 30) - 1)
};



///
///  ZKMORConduit
/// 
///  A Conduit is something which generates, processes, or accepts frames of audioaudio.
///
///  By default conduits
///		-- have only one input bus and one output bus
///		-- input and output the same stream format (de-interleaved N-channel audio) 
///  Subclasses may override.
///
///  Rendering is done in-place -- classes get a buffer containing the samples from
///  the downstream caller, which they consume and overwrite.
///
///  For performance purposes, certain functions on Conduits are defined as
///  C functions which can be called directly, bypassing the Obj-C method look-up
///  mechanism.
///
///  When an Conduit is copied, it is in the uninitialized state.
///
///  The functions which fall into this catagory are:
/// 
///		1. The render function -- generates / processes / consumes audio samples
///
///
///  Common sources of bugs:
///		1. Conduit is a source, but declared as a processor (the default) -- this causes a crash in graph rendering
///
@class ZKMORConduitBus, ZKMORInputBus, ZKMOROutputBus, ZKMORGraph; 
@interface ZKMORConduit : NSObject <NSCopying, NSCoding> {
	//  Status State
	unsigned				_conduitType;		
	BOOL					_isInitialized;
	unsigned				_maxFramesPerSlice;
	NSString*				_purposeString;				// the reason for this object's existence
	
	//  Debug State
	unsigned				_debugLevel;
	
	//  Bus State
	NSMutableArray*			_inputBuses;
	NSMutableArray*			_outputBuses;
	BOOL					_areBusesInitialized;
	
	//  Cached State
	ZKMORRenderFunction		_renderFunction;
	BOOL					_isGraphConnectionOwner;
	NSString*				_descriptionCached;
	ZKMORGraph*				_graph;
}

//  State Management
- (void)initialize;				///< throws ConduitError
- (void)globalReset;
- (void)uninitialize;			///< throws ConduitError
- (BOOL)isInitialized;

//  Type Queries
- (BOOL)isProcessor;
- (BOOL)isSource;
- (BOOL)isSink;
- (BOOL)isAudioUnit;
- (BOOL)isMixer;
- (BOOL)isFormatConverter;
- (BOOL)isStartable;			///< YES if I implement the ZKMORStarting protocol

//  Format Management
- (unsigned)maxFramesPerSlice;								///< the max number of frames I can be asked for
- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice;	///< throws ConduitError
								

//  Bus Management 
- (unsigned)numberOfInputBuses;						///< defaults to 1
- (BOOL)isNumberOfInputBusesSettable;
- (void)setNumberOfInputBuses:(unsigned)busCount;	///< throws ConduitError

- (unsigned)numberOfOutputBuses;					///< defaults to 1
- (BOOL)isNumberOfOutputBusesSettable;
- (void)setNumberOfOutputBuses:(unsigned)busCount;	///< throws ConduitError


  /// The buses are owned by the Conduit, so you don't need to release them
  /// and in fact, you should not hold a reference to an bus for an extended
  /// period of time until the AU is initialized (the instances of conduit bus
  /// may change up to that point)
- (ZKMORInputBus  *)inputBusAtIndex:(unsigned)index;
- (ZKMOROutputBus *)outputBusAtIndex:(unsigned)index;

//  Debugging -- effects all buses. Can also be turned on a per-bus basis.
- (unsigned)debugLevel;
	/// See the ZKMORDebugLevel enum for a list of valid values which can be or-ed together
- (void)setDebugLevel:(unsigned)debugLevel;

//  Rendering
	/// Subclasses should override this methods to provide their own functions,
	/// the system will automatically cache them in the ivars so they can be accessed
	/// without an ObjC message look-up
- (ZKMORRenderFunction)renderFunction;

@end



///
///  ZKMORConduit (ZKMORConduitLogging)
/// 
///  Logging methods on conduits.
///
@interface ZKMORConduit (ZKMORConduitLogging)

- (NSString *)purposeString;
- (void)setPurposeString:(NSString *)purposeString;
- (void)logBusFormatSummary;

@end



///
///  ZKMORConduit (ZKMORConduitInternal)
/// 
///  Internal methods on a Conduit. You shouldn't need to call
///  these directly, but subclassers may want to override.
///
@interface ZKMORConduit (ZKMORConduitInternal)
- (ZKMORGraph *)graph;
- (void)setGraph:(ZKMORGraph *)graph;

	// bus objects are instances of this class
- (Class)inputBusClass;
- (Class)outputBusClass;

	// does the heavy-lifting to change the bus count
- (void)setNumberOfBuses:(unsigned)numBuses scope:(AudioUnitScope)scope;

	// creates bus objects for the specified scope
- (void)initializeBusesForScope:(AudioUnitScope)scope;

	// creates bus objects and puts them into the apropriate arrays
- (void)initializeBuses;

// format information
- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus;
	/// if you override setStreamFormatForBus, you need to call ZKMORGraph>>changedStreamFormatOnConduitBus:
	/// if the conduit has a graph. ZKMORAudioUnit does this automatically via the property listening
	/// mechanism, but other conduits must manually do this.
- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus;

// callbacks
	// this is true for classes that
	// need to manage their own connections
	// into the graph (e.g., AudioUnits)
- (BOOL)isGraphConnectionOwner;
	// if isGraphConnectionOwner is true, then setCallback:busNumber: has to be implemented
- (void)setCallback:(AURenderCallbackStruct*)callback busNumber:(unsigned)bus;

// notifications
- (void)graphSampleRateChanged:(Float64)graphSampleRate;

@end



///
///  ZKMORConduitBus
///
///  The default implementation for a conduit bus. Only has a stream format. You don't create
///  conduit buses -- you get them from conduits. Note, that the conduit bus object doesn't "really"
///  exist until the conduit is initialized and may disappear if the number of input/output buses ont
///  the parent conduit is changed.
///
@interface ZKMORConduitBus : NSObject {
	//  Bus State
	ZKMORConduit*					_conduit;
	AudioStreamBasicDescription		_streamFormat;
	unsigned						_busNumber;
	AudioUnitScope					_scope;
	
	//  Debug State
	unsigned						_debugLevel;
	
		// used to maintain data coherence, while a change
		// is being made
	BOOL	_isExecutingPropertyChange;
}

//  Accessors
- (ZKMORConduit *)conduit;
- (unsigned)busNumber;

- (AudioStreamBasicDescription)streamFormat;
- (void)setStreamFormat:(AudioStreamBasicDescription)streamFormat;

//  Scope
- (AudioUnitScope)scope;
- (BOOL)isInput;
- (BOOL)isOutput;

					
//  Convenience Functions
- (unsigned)numberOfChannels;
- (void)setNumberOfChannels:(unsigned)numberOfChannels;
- (Float64)sampleRate;
- (void)setSampleRate:(Float64)sampleRate;

//  Debugging
- (unsigned)debugLevel;
- (void)setDebugLevel:(unsigned)debugLevel;

@end



///
///  ZKMORConduitBus (ZKMORConduitBusInternal)
/// 
///  Internal methods on a ConduitBus. You shouldn't need to call
///  these directly, but subclassers may want to override.
///
@interface ZKMORConduitBus (ZKMORConduitBusInternal)

//  Initialization
- (id)initWithConduit:(id)conduit busNumber:(unsigned)busNumber scope:(AudioUnitScope)scope;

	// synchronize the stream format with the conduit
- (void)updateStreamFormat;

@end



///
///  ZKMORInputBus
///
///  The bus that accepts audio data.
///
@interface ZKMORInputBus : ZKMORConduitBus {
	ZKMOROutputBus*		_feederBus;
}

@end



///
///  ZKMORInputBus (ZKMORInputBusInternal)
/// 
///  Internal methods on an input bus. You shouldn't need to call
///  these directly, but subclassers may want to override.
///
@interface ZKMORInputBus (ZKMORInputBusInternal)

	/// The default is to set this bus' stream format to the source's stream format.
- (BOOL)preparePatch:(ZKMOROutputBus *)source error:(NSError **)error;

@end



///
///  ZKMOROutputBus
///
///  The bus that produces audio data.
///
@interface ZKMOROutputBus : ZKMORConduitBus {
	ZKMORInputBus*		_receiverBus;
}

@end



///
///  ZKMORAbstractMethodCallConduit
/// 
///  Calls an ObjectiveC method to generate audio. It is discouraged to call ObjC in IOProcs, 
///  but the convenience of doing so is undeniable. If problems with this arise (dropouts, etc.),
///  you may need to re-write your functions to be pure C or C++.
///
@interface ZKMORAbstractMethodCallConduit : ZKMORConduit {
	IMP		_invokeFunctionPointer;

}

- (OSStatus)
	invokeFlags:(AudioUnitRenderActionFlags *)ioActionFlags
	timeStamp:(const AudioTimeStamp *)inTimeStamp
	outputBusNumber:(UInt32)inOutputBusNumber
	numberOfFrames:(UInt32)inNumberFrames
	bufferList:(AudioBufferList *)ioData;

@end



///
/// Functions for Various Constants
///
Float64		ZKMORDefaultSampleRate();
unsigned	ZKMORDefaultNumberChannels();
unsigned	ZKMORDefaultMaxFramesPerSlice();



///
///  ZKMORConduitStruct
/// 
///  The struct form of the conduit, for digging into the state of the object (used to
///  improve performance)
///
typedef struct { @defs(ZKMORConduit) } ZKMORConduitStruct;
typedef struct { @defs(ZKMORConduitBus) } ZKMORConduitBusStruct;
typedef struct { @defs(ZKMORInputBus) } ZKMORInputBusStruct;
typedef struct { @defs(ZKMOROutputBus) } ZKMOROutputBusStruct;
typedef struct { @defs(ZKMORAbstractMethodCallConduit) } ZKMORAbstractMethodCallConduitStruct;



//
// Convenience Functions
// 
void ZKMORStreamFormatChangeNumberOfChannels(AudioStreamBasicDescription* streamFormat, unsigned numChannels);
BOOL ZKMORIsDebuggingOnBus(ZKMORConduitBus* conduitBus, unsigned debugLevel);

//
//  Buffer List Convenience Functions
//
void ZKMORMakeBufferListSilent(AudioBufferList *ioData, AudioUnitRenderActionFlags *ioActionFlags);
void ZKMORMakeBufferListTailSilent(	AudioBufferList				*ioData, 
									AudioUnitRenderActionFlags	*ioActionFlags, 
									UInt32						initialFrame);

ZKMOR_C_END

// __ZKMORConduit_h__
#endif 

