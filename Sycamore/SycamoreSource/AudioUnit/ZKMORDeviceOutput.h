//
//  ZKMORDeviceOutput.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 30.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORConduit.h"
#import "ZKMOROutput.h"

#ifndef __ZKMORDeviceOutput_H__
#define __ZKMORDeviceOutput_H__

extern NSString* const	ZKMORDeviceOutputDeviceWillDisappearNotification;
extern NSString* const	ZKMORDeviceOutputDeviceDidDisappearNotification;

///
///  ZKMORDeviceOutput
///
///  Calls a graph for data and sends the output to a device. The device output uses the AUHAL audio unit
///  for its underlying interaction with the device. By default, it turns on input (if the device has input).
///  Clients may turn off input if they don't need it.
///
///  The implementation details rely on TN2091 http://developer.apple.com/technotes/tn2002/tn2091.html .
///
@class ZKMORGraph, ZKMORAudioDevice, ZKMORAudioUnit, ZKMORDeviceInput;
@interface ZKMORDeviceOutput : ZKMOROutput  {
	ZKMORAudioUnit*		_outputUnit;
	ZKMORAudioDevice*	_outputDevice;
	ZKMORDeviceInput*	_deviceInput;
	OSStatus			_lastError;
	
	NSArray* _channelMapSortedByPatchChannel;
}

//  Accessors
- (ZKMORAudioDevice *)outputDevice;
	/// setOutputDevice may return an error if the device has no output (i.e., is only an input device)
	///
	/// ZKMORDeviceOutput always runs at the same sample rate as the device. If the device's sample rate changes,
	/// the device output will stop itself and switch the graph and input (if there is one) to run at the new sample
	/// rate before continuing.
- (BOOL)setOutputDevice:(ZKMORAudioDevice *)outputDevice error:(NSError **)error;

/// Return an mutable array of NSNumber objects representing the channel map.
/// The function retuns a mutable array to make it easy to alter and use in a call to
///  set channel map. See kAudioOutputUnitProperty_ChannelMap for more info.
- (NSMutableArray *)channelMap; 
- (void)setChannelMap:(NSArray *)channelMap; ///< Takes an array of NSNumber objects to define a channel map.

- (NSArray *)channelMapSortedByPatchChannel;
- (void)setChannelMapSortedByPatchChannel:(NSArray*)channelMap;

- (UInt32)channelMapSize;
	/// returns the size of the map that was written
- (UInt32)getPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size;
- (void)setPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size;

- (float)volume;
- (void)setVolume:(float)volume;

	/// For informational purposes, you can have a look at the output unit's stream format, but it will
	/// always be the same as the Graph's output stream format.
- (AudioStreamBasicDescription)outputUnitStreamFormat;

- (ZKMORAudioUnit *)outputUnit;

	/// The more robust way to watch for errors is to make yourself a delegate of the graph or add a
	/// render notification to the graph, but, as a convenience, I store more recent error.
- (OSStatus)lastError;

//  Input
	/// Returns true if the device input can be used. Check this before utilizing the device input.
- (BOOL)canDeliverInput;
- (BOOL)isInputEnabled;
	/// if canDeliverInput is false, setInputEnabled: will do nothing
- (void)setInputEnabled:(BOOL)isEnabled;

- (ZKMORDeviceInput *)deviceInput;

//  Queries
- (BOOL)isDefaultOutput;	/// does this output track the default device

@end



///
///  ZKMORDeviceInput
///
///  Gets input from a device. Do not create this yourself, get it from the device output.
///
@interface ZKMORDeviceInput : ZKMORConduit  {
	ZKMORDeviceOutput*	_deviceOutput;
	ZKMORAudioUnit*		_outputUnit;
}

//  Accessors
- (ZKMORDeviceOutput *)deviceOutput;

- (unsigned)numberOfChannels;
- (void)setNumberOfChannels:(unsigned)numberOfChannels;

/// Return an mutable array of NSNumber objects representing the channel map.
/// The function retuns a mutable array to make it easy to alter and use in a call to
///  set channel map. See kAudioOutputUnitProperty_ChannelMap for more info.
- (NSMutableArray *)channelMap; 
- (void)setChannelMap:(NSArray *)channelMap; ///< Takes an array of NSNumber objects to define a channel map.

- (UInt32)channelMapSize;
	/// returns the size of the map that was written
- (UInt32)getPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size;
- (void)setPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size;

//  Queries
	/// return true if the device input can be used, false otherwise
- (BOOL)isValid;

@end



///
///  ZKMORDefaultOutput
///
///  Is a device output that tracks the default device. This uses the DefaultOutput Audio Unit to communicate
///  with the device. Calls to setOutputDevice will fail with an error.
///
@interface ZKMORDefaultOutput : ZKMORDeviceOutput  {

}

@end



//
//  ZKMORDeviceOutputStruct
// 
//  The struct form of the device output/input, for digging into the state of the object (used to
//  improve performance)
//
typedef struct { @defs(ZKMORDeviceOutput) } ZKMORDeviceOutputStruct;
typedef struct { @defs(ZKMORDeviceInput) } ZKMORDeviceInputStruct;
#endif
