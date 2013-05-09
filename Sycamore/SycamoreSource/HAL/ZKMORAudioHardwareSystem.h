//
//  ZKMORAudioHardwareSystem.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  Abstractions for the audio hardware connected to the computer.
//

#import "ZKMORCore.h"
#import <CoreAudio/CoreAudio.h>

#ifndef __ZKMORAudioHardwareSystem_h__
#define __ZKMORAudioHardwareSystem_h__

ZKMDECLCPPT(CAAudioHardwareDevice)
extern NSString* const	ZKMORAudioHardwareDevicesChangedNotification;
extern NSString* const	ZKMORAudioDeviceSampleRateChangedNotification;


///
///  ZKMORAudioDevice
///  
///  Abstraction for an Audio Hardware Device connected to the computer
///  The ZKMORAudioHardwareSystem keeps arrays of the devices which are available, so
///  you don't need to instantiate these objects yourself.
/// 
@interface ZKMORAudioDevice : NSObject {
	ZKMCPPT(CAAudioHardwareDevice)	mAudioHardwareDevice;
	NSString*		_audioDeviceDescription;
	NSMutableArray*	_outputChannelNames;
	NSMutableArray*	_inputChannelNames;	
	BOOL			_isDefaultInput;	
	BOOL			_isDefaultOutput;
	BOOL			_isSystemOutput;	
}

//  Initialization -- Don't make an audio devices. Get it from the AudioHardwareSystem


//  General Information 
- (AudioDeviceID)audioDeviceID;
- (NSString *)audioDeviceDescription;
- (NSString *)UID;
- (NSString *)configurationApplicationBundleID;

//  Device Information
- (BOOL)isInputDevice;
- (BOOL)isOutputDevice;

- (unsigned)numberOfOutputChannels;
- (unsigned)numberOfInputChannels;

- (NSArray *)outputChannelNames;
- (NSArray *)inputChannelNames;

- (Float64)nominalSampleRate;
- (Float64)actualSampleRate;
- (UInt32)ioBufferSize;
- (float)throughput;				// MB/sec

//  System Information
- (BOOL)isDefaultOutput;
- (BOOL)isDefaultInput;
- (BOOL)isSystemOutput;

//  Device Status
- (BOOL)isRunning;
- (BOOL)isRunningSomewhere;
- (BOOL)isAlive;

@end

///
///  ZKMORAudioDevice(ZKMORAudioDeviceApplicationServices)
///
///  Includes methods which require ApplicationsServices.
/// 

@interface ZKMORAudioDevice(ZKMORAudioDeviceApplicationServices)

- (BOOL)launchConfigurationApplicationWithError:(NSError **)error;

@end

///
///  ZKMORAudioHardwareSystem
///  
///  Abstraction for the Audio Hardware System -- that is, all devices
///  connected to the computer
/// 
@interface ZKMORAudioHardwareSystem : NSObject {
	NSMutableArray*		_availableDevices;
	NSMutableArray*		_outputDevices;
}

///  Singleton
+ (ZKMORAudioHardwareSystem *)sharedAudioHardwareSystem;

//  Device Accessing
+ (unsigned)numberOfDevices;
+ (AudioDeviceID)audioDeviceIDForDeviceAtIndex:(unsigned)index;

//  Queries
+ (BOOL)isDefaultInputAlsoDefaultOutput;

//  Accessors
- (NSArray *)availableDevices;	///< returns an array of ZKMORAudioDevice
- (NSArray *)outputDevices;		///< returns an array of ZKMORAudioDevice

- (ZKMORAudioDevice *)defaultOutputDevice;
- (ZKMORAudioDevice *)defaultInputDevice;
- (ZKMORAudioDevice *)systemOutputDevice;
- (ZKMORAudioDevice *)audioDeviceForDeviceID:(AudioDeviceID)audioDeviceID;
- (ZKMORAudioDevice *)audioDeviceForUID:(NSString *)uid;

@end


#ifdef __cplusplus
//  C++ Things
@interface ZKMORAudioDevice (ZKMORAudioDeviceCPP)
- (CAAudioHardwareDevice *)caAudioHardwareDevice;
@end

#endif

#endif __ZKMORAudioHardwareSystem_h__