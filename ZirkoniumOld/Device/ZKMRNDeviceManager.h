//
//  ZKMRNDeviceManager.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 01.03.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
ZKMDECLCPPT(ZirkoniumHALServerPort)
ZKMDECLCPPT(ZKMRNHALDeviceDelegate)

@class ZKMRNDeviceDocument, ZKMRNZirkoniumSystem;
@interface ZKMRNDeviceManager : NSObject {
	ZKMCPPT(ZirkoniumHALServerPort)	mServer;
	ZKMCPPT(ZKMRNHALDeviceDelegate)	mDelegate;
	ZKMRNZirkoniumSystem*			_zirkoniumSystem;
	ZKMRNDeviceDocument*			_deviceSetup;
	NSMutableArray*					_clients;
	NSTimer*						_heartbeatTimer;
	unsigned						_mixerInputOutputDimensions[2];
	unsigned						_mixerLevelsSize;	
	Float32*						_mixerLevels;
	unsigned						_deviceNumberOfChannels;
	BOOL							_isNumberOfChannelsBeingUpdated;
	
		// audio state for the devices
	ZKMNRVBAPPanner*		_panner;
	ZKMORMixerMatrix*		_spatializationMixer;
	
	NSTimer*				_spatializationTimer;
}

//  Accessors
- (NSArray *)clients;
- (ZKMNRVBAPPanner *)panner;
- (ZKMORMixerMatrix *)spatializationMixer;
- (float)masterGain;
- (void)setMasterGain:(float)masterGain;
- (unsigned)deviceNumberOfChannels;
- (void)setDeviceNumberOfChannels:(unsigned)deviceNumberOfChannels;
- (unsigned)numberOfSpeakers;
- (unsigned)numberOfDirectOuts;

- (void)setLogging:(BOOL)isLogging level:(unsigned)loggingLevel;

- (ZKMRNDeviceDocument *)deviceSetup;
- (void)setDeviceSetup:(ZKMRNDeviceDocument *)deviceSetup;
- (NSString *)defaultDeviceSetupPath;
- (ZKMRNDeviceDocument *)createNewDeviceSetup;
- (void)createDeviceDocumentURL:(NSURL *)studioURL;

// Actions
	/// called by the system when the speaker setup or direct-out setup changes
- (void)synchronizeOutputPatch;

@end

@interface ZKMRNDeviceClient : NSObject {
	NSNumber*			_pid;
	NSString*			_applicationName;
	NSNumber*			_portNumber;
	NSString*			_portName;
	CFMessagePortRef	_messagePort;
	CFAbsoluteTime		_lastHeartbeatTime;
}

//  UI Accessors
- (NSNumber *)pid;
- (NSString *)applicationName;
- (NSNumber *)portNumber;

@end