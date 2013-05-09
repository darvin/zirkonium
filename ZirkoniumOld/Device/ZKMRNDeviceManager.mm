//
//  ZKMRNDeviceManager.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 01.03.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNDeviceManager.h"
#import "ZKMRNHALPlugInProtocol.h"
#import "ZKMRNDeviceDocument.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNPreferencesController.h"
#import "ZKMRNDeviceConstants.h"

@interface ZKMRNDeviceManager (ZKMRNDeviceManagerPrivate)

- (void)checkIn:(pid_t)processID stringLength:(CFIndex)length string:(char *)appname;
- (void)createHeartbeatTimer;
- (void)destroyHearbeatTimer;
- (void)heartbeat:(NSTimer *)timer;

- (void)createSpatializationTimer;
- (void)destroySpatializationTimer;
- (void)spatTick:(id)timer;

- (void)initializeDeviceDocument;

- (void)updateMixerDimensions;
- (void)updateOutputChannelMap;
	/// called by the system with the speaker mode or simulation mode changed
- (void)updateSpeakerMode;

@end

@interface ZKMRNDeviceClient (ZKMRNDeviceClientInternal)
- (CFMessagePortRef)messagePort;
- (void)setPID:(pid_t)pid applicationName:(char *)appname length:(CFIndex)length;
- (void)setPortName:(NSString *)portName;
@end

struct ZKMRNHALDeviceDelegate : public ZirkoniumHALServerPort::ServerPortDelegate
{
	ZKMRNHALDeviceDelegate(ZKMRNDeviceManager* manager) : ZirkoniumHALServerPort::ServerPortDelegate(), mManager(manager) { }
	
	void CheckIn(pid_t processID, CFIndex length, char* appname) { [mManager checkIn: processID stringLength: length string: appname]; }

	ZKMRNDeviceManager *	mManager;	
};

static void LogMixerLevels(Float32* mixerLevels, unsigned inputs, unsigned outputs)
{
	unsigned i, j;
	for (i = 0; i < (inputs + 1); ++i) {
		if (i < inputs) {
			printf("\t%.3f   ", mixerLevels[(i + 1) * (outputs + 1) - 1]);
			for (j = 0; j < outputs; ++j)
				printf("(%.3f) ", mixerLevels[(i * (outputs  + 1)) + j]);
			printf("\n");
		} else {
			printf("\t%.3f   ", mixerLevels[(inputs + 1) * (outputs + 1) - 1]);
			for (j = 0; j < outputs; ++j)
				printf(" %.3f  ", mixerLevels[(i * (outputs + 1)) + j]);
			printf("\n");
		}
	}
	printf("\n");
}


@implementation ZKMRNDeviceManager
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (mServer) delete mServer, mServer = NULL;
	if (mDelegate) delete mDelegate, mDelegate = NULL;
	if (_clients) [_clients release];
	if (_heartbeatTimer) [self destroyHearbeatTimer];
	if (_deviceSetup) [_deviceSetup release];
	[_panner unbind: @"speakerLayout"];
	[_panner release], _panner = nil;
	if (_spatializationMixer) [_spatializationMixer release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_zirkoniumSystem = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	_deviceNumberOfChannels = DEVICE_NUM_CHANNELS;
	_isNumberOfChannelsBeingUpdated = NO;
	
	_spatializationMixer = [[ZKMORMixerMatrix alloc] init];
	[_spatializationMixer setPurposeString: @"Zirk Device Spat Mixer"];
	[[_spatializationMixer inputBusAtIndex: 0] setNumberOfChannels: _deviceNumberOfChannels];
	
	_panner = [[ZKMNRVBAPPanner alloc] init];
	[_panner bind: @"speakerLayout" toObject: _zirkoniumSystem withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[_panner setMixer: _spatializationMixer];
	
	_mixerLevels = NULL;
	_clients = [[NSMutableArray alloc] init];

	mServer = new ZirkoniumHALServerPort;
	mDelegate = new ZKMRNHALDeviceDelegate(self);
	mServer->SetDelegate(mDelegate);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), mServer->GetRunLoopSource(), kCFRunLoopCommonModes);

	[self createHeartbeatTimer];
	[self createSpatializationTimer];
	
	[self synchronizeOutputPatch];
	
	return self;
}

#pragma mark _____ Accessors
- (NSArray *)clients { return _clients; }
- (ZKMNRVBAPPanner *)panner { return _panner; }
- (ZKMORMixerMatrix *)spatializationMixer { return _spatializationMixer; }
- (float)masterGain { return [_spatializationMixer masterVolume]; }
- (void)setMasterGain:(float)masterGain { [_spatializationMixer setMasterVolume: masterGain]; }
- (unsigned)deviceNumberOfChannels { return _deviceNumberOfChannels; }
- (void)setDeviceNumberOfChannels:(unsigned)deviceNumberOfChannels
{
	_isNumberOfChannelsBeingUpdated = YES;
	_deviceNumberOfChannels = deviceNumberOfChannels;
	
	[_spatializationMixer uninitialize];
	[[_spatializationMixer inputBusAtIndex: 0] setNumberOfChannels: _deviceNumberOfChannels];
	[self synchronizeOutputPatch];
	
		// create the ids	
	NSEnumerator* inputSources = [[_deviceSetup inputSources] objectEnumerator];
	id input = [inputSources nextObject];
	[input setValue: [NSNumber numberWithInt: _deviceNumberOfChannels] forKey: @"numberOfChannels"];
	[_deviceSetup equalizeNumberOfGraphChannels];
	
	if ([_clients count] < 1) return;

	NSMutableArray* clients = _clients;
	int i, count = [clients count];
	for (i = count - 1; i >= 0; --i) {
		ZKMRNDeviceClient* client = [clients objectAtIndex: i];
		CFMessagePortRef clientPort = [client messagePort];
		mServer->SendSetNumberOfChannels(clientPort, _deviceNumberOfChannels);
	}
	_isNumberOfChannelsBeingUpdated = NO;
}
- (unsigned)numberOfSpeakers { return [[_zirkoniumSystem speakerSetup] numberOfSpeakers]; }
- (unsigned)numberOfDirectOuts 
{ 
	ZKMRNDirectOutPatch* directOutPatch = [_zirkoniumSystem directOutPatch];
	return (directOutPatch) ? [directOutPatch numberOfChannels] : 0;
}

- (void)setLogging:(BOOL)isLogging level:(unsigned)loggingLevel
{
	int i, count = [_clients count];
	for (i = count - 1; i >= 0; --i) {
		ZKMRNDeviceClient* client = [_clients objectAtIndex: i];
		CFMessagePortRef clientPort = [client messagePort];
		mServer->SendLoggingLevel(clientPort, isLogging, loggingLevel);
	}
}

- (ZKMRNDeviceDocument *)deviceSetup 
{ 
	if (!_deviceSetup) [self initializeDeviceDocument];
	return _deviceSetup; 
}

- (void)setDeviceSetup:(ZKMRNDeviceDocument *)deviceSetup
{
	if (_deviceSetup) [_deviceSetup release];
	_deviceSetup = deviceSetup;
	if (_deviceSetup) [_deviceSetup retain];
	[self synchronizeOutputPatch];
}

- (NSString *)defaultDeviceSetupPath { return [[_zirkoniumSystem applicationSupportFolder] stringByAppendingPathComponent: @"device.zrkdxml"]; }
- (ZKMRNDeviceDocument *)createNewDeviceSetup
{
	ZKMRNDeviceDocument* deviceSetup;
	NSDocumentController* documentController = [NSDocumentController sharedDocumentController];
	NSError* error = nil;
	deviceSetup = [documentController makeUntitledDocumentOfType: @"Device" error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return nil;
	}
	
	// configure the device setup
		// turn on inputs
	[deviceSetup setInputOn: YES];
	NSEnumerator* inputSources = [[deviceSetup inputSources] objectEnumerator];
	id input = [inputSources nextObject];
	[input setValue: [NSNumber numberWithInt: _deviceNumberOfChannels] forKey: @"numberOfChannels"];
	
		// create the ids
	[deviceSetup equalizeNumberOfGraphChannels];
	[documentController addDocument: deviceSetup];
	return deviceSetup;
}

- (void)createDeviceDocumentURL:(NSURL *)deviceDocURL
{
	NSError* error = nil;
	_deviceSetup = [self createNewDeviceSetup];
	[_deviceSetup retain];
	[_deviceSetup saveToURL: deviceDocURL ofType: @"Device" forSaveOperation: NSSaveAsOperation error: &error];
}

- (void)synchronizeOutputPatch
{
	unsigned numberOfOutputChannels = [self numberOfSpeakers] + [self numberOfDirectOuts];;
	
	[_spatializationMixer uninitialize];
	[[_spatializationMixer outputBusAtIndex: 0] setNumberOfChannels: numberOfOutputChannels];
	[_spatializationMixer initialize];
	[_spatializationMixer setToCanonicalLevels];
	[self updateMixerDimensions];
	[self updateOutputChannelMap];
	[self updateSpeakerMode];
}

#pragma mark _____ ZKMRNDeviceManagerPrivate
- (void)checkIn:(pid_t)processID stringLength:(CFIndex)length string:(char *)appname
{
	ZKMRNDeviceClient* client = [[ZKMRNDeviceClient alloc] init];
	[client setPID: processID applicationName: appname length: length];
	NSString* portName = (NSString *) mServer->CopyPortNameForPID(processID);
	[client setPortName: portName];
	[portName release];
	
	// tell the device what the current setup is
	ZKMRNDeviceDocument* deviceSetup = [self deviceSetup];
	if (deviceSetup) {
		CFMessagePortRef clientPort = [client messagePort];
		if (clientPort) {
				// send number of output channels
			mServer->SendSetNumberOfChannels(clientPort, _deviceNumberOfChannels);
			
				// send channel map
			UInt32 mapSize = [[_zirkoniumSystem deviceOutput] channelMapSize];
			SInt32 map[mapSize];
			[[_zirkoniumSystem deviceOutput] getPrimitiveChannelMap: map size: mapSize];
			mServer->SendOutputChannelMap(clientPort, mapSize, map);
				// send speaker mode
			UInt8 speakerMode = [_zirkoniumSystem loudspeakerMode];
			UInt8 simMode = [_zirkoniumSystem loudspeakerSimulationMode];
			ZKMNRSpeakerLayout* speakerLayout = [[_zirkoniumSystem speakerLayoutSimulator] speakerLayout];
			NSString* errorString;
			NSData* data = 
				[NSPropertyListSerialization 
					dataFromPropertyList: [speakerLayout dictionaryRepresentation] 
					format: NSPropertyListXMLFormat_v1_0 
					errorDescription: &errorString];
			if (data) {
				mServer->SendSpeakerMode(clientPort, _mixerInputOutputDimensions[0] - 1, _mixerInputOutputDimensions[1] - 1, speakerMode, simMode, (CFDataRef) data);
			} else {
				ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not get data from speaker layout %@"), errorString);
				[errorString release];
			}
		}
	}

		// add the client to the list of clients
	NSMutableArray* clients = [self mutableArrayValueForKey: @"clients"];
	[clients addObject: client];
	[client release];
}

- (void)createHeartbeatTimer
{
	if (_heartbeatTimer) [self destroyHearbeatTimer];
	
	_heartbeatTimer = [NSTimer timerWithTimeInterval: 1. target: self selector: @selector(heartbeat:) userInfo: nil repeats: YES];
	[_heartbeatTimer retain];
	[[NSRunLoop currentRunLoop] addTimer: _heartbeatTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _heartbeatTimer forMode: NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _heartbeatTimer forMode: NSEventTrackingRunLoopMode];
}

- (void)destroyHearbeatTimer
{
	[_heartbeatTimer invalidate];
	[_heartbeatTimer release], _heartbeatTimer = nil;
}

- (void)heartbeat:(NSTimer *)timer
{
	NSMutableArray* clients = [self mutableArrayValueForKey: @"clients"];
	int i, count = [clients count];
	for (i = count - 1; i >= 0; --i) {
		ZKMRNDeviceClient* client = [clients objectAtIndex: i];
		CFMessagePortRef clientPort = [client messagePort];
		if (!clientPort) {
			[clients removeObjectAtIndex: i];
			continue;
		}
		SInt32 ans = mServer->SendHeartbeatMessage(clientPort);
		if (kCFMessagePortSuccess != ans) {
			[clients removeObjectAtIndex: i];
		}
	}
}

- (void)createSpatializationTimer
{
	if (_spatializationTimer) [self destroySpatializationTimer];
	_spatializationTimer = [NSTimer timerWithTimeInterval: 0.025 target: self selector: @selector(spatTick:) userInfo: nil repeats: YES];
//	_spatializationTimer = [NSTimer timerWithTimeInterval: 1. target: self selector: @selector(spatTick:) userInfo: nil repeats: YES];
	[_spatializationTimer retain];
	[[NSRunLoop currentRunLoop] addTimer: _spatializationTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _spatializationTimer forMode: NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _spatializationTimer forMode: NSEventTrackingRunLoopMode];
}

- (void)destroySpatializationTimer
{
	[_spatializationTimer invalidate];
	[_spatializationTimer release], _spatializationTimer = nil;
}

- (void)spatTick:(id)timer
{
	if ([_clients count] < 1) return;
	if (_isNumberOfChannelsBeingUpdated) return;

		// update the mixer levels	
 	[_panner updatePanningToMixer];

	[_spatializationMixer getMixerLevels: _mixerLevels size: _mixerLevelsSize];
	
	NSMutableArray* clients = _clients;
	int i, count = [clients count];
	for (i = count - 1; i >= 0; --i) {
		ZKMRNDeviceClient* client = [clients objectAtIndex: i];
		CFMessagePortRef clientPort = [client messagePort];
		mServer->SendSetMatrix(clientPort, _mixerLevelsSize * sizeof(Float32), _mixerLevels);
	}
/*	
	static int debugCount = 0;
	if (--debugCount < 0) {
		debugCount = 39;
		LogMixerLevels(_mixerLevels, _mixerInputOutputDimensions[0] - 1, _mixerInputOutputDimensions[1] - 1);
	}
*/
}

- (void)initializeDeviceDocument
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSURL* deviceDocURL = [NSURL fileURLWithPath: [self defaultDeviceSetupPath]];
	if (![fileManager fileExistsAtPath: [deviceDocURL path]]) { [self createDeviceDocumentURL: deviceDocURL]; return; }
		
	NSError* error = nil;
	_deviceSetup = [[ZKMRNDeviceDocument alloc] initWithContentsOfURL: deviceDocURL ofType: @"Device" error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return;
	}
//	[[NSDocumentController sharedDocumentController] addDocument: _deviceSetup];
}

- (void)updateMixerDimensions
{
	// no need to lock here -- this happens in the same thread as the spatTick, so it can't happen simultaneously
	[_spatializationMixer getMixerLevelsDimensionsInput: &_mixerInputOutputDimensions[0] output: &_mixerInputOutputDimensions[1]];
	if (_mixerLevels) {
			// the size is the same as it was before -- no need to reallocate
		if (_mixerInputOutputDimensions[0] * _mixerInputOutputDimensions[1] == _mixerLevelsSize) return;
			// size changed -- reallocate
		free(_mixerLevels);
	} 
	_mixerLevelsSize = _mixerInputOutputDimensions[0] * _mixerInputOutputDimensions[1];
	_mixerLevels = (Float32 *) malloc(_mixerLevelsSize * sizeof(Float32));
}

- (void)updateOutputChannelMap
{
	UInt32 mapSize = [[_zirkoniumSystem deviceOutput] channelMapSize];
	SInt32 map[mapSize];
	[[_zirkoniumSystem deviceOutput] getPrimitiveChannelMap: map size: mapSize];
	NSArray* clients = _clients;
	int i, count = [clients count];
	for (i = 0; i < count; ++i) {
		ZKMRNDeviceClient* client = [clients objectAtIndex: i];
		CFMessagePortRef clientPort = [client messagePort];
		if (clientPort) mServer->SendOutputChannelMap(clientPort, mapSize, map);
	}
}

	// needs to be called after update mixer dimensions
- (void)updateSpeakerMode
{
	ZKMNRSpeakerLayout* speakerLayout = [[_zirkoniumSystem speakerLayoutSimulator] speakerLayout];
	if (!speakerLayout) return;
	UInt8 speakerMode = [_zirkoniumSystem loudspeakerMode];
	UInt8 simMode = [_zirkoniumSystem loudspeakerSimulationMode];
	NSString* errorString;
	NSData* data = 
		[NSPropertyListSerialization 
			dataFromPropertyList: [speakerLayout dictionaryRepresentation] 
			format: NSPropertyListXMLFormat_v1_0 
			errorDescription: &errorString];
	if (!data) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not get data from speaker layout %@"), errorString);
		[errorString release];
		return;
	}
	
	NSArray* clients = _clients;
	int i, count = [clients count];
	for (i = 0; i < count; ++i) {
		ZKMRNDeviceClient* client = [clients objectAtIndex: i];
		CFMessagePortRef clientPort = [client messagePort];
		if (clientPort) mServer->SendSpeakerMode(clientPort, _mixerInputOutputDimensions[0] - 1, _mixerInputOutputDimensions[1] - 1, speakerMode, simMode, (CFDataRef) data);
	}
}

@end

@implementation ZKMRNDeviceClient
- (void)dealloc
{
	if (_pid) [_pid release];
	if (_applicationName) [_applicationName release];
	if (_portName) [_portName release];
	if (_messagePort) CFRelease(_messagePort);
	[super dealloc];
}

- (NSNumber *)pid { return _pid; }
- (NSString *)applicationName { return _applicationName; }
- (NSNumber *)portNumber { return _portNumber; }

#pragma mark _____ ZKMRNDeviceClientInternal
- (CFMessagePortRef)messagePort { return _messagePort; }
- (void)setPID:(pid_t)pid applicationName:(char *)appname length:(CFIndex)length
{
	_pid = [[NSNumber alloc] initWithInt: pid];
	_applicationName = [[NSString alloc] initWithCString: appname length: length];
}

- (void)setPortName:(NSString *)portName
{
	_portName = [portName retain];
	_messagePort = CFMessagePortCreateRemote(NULL, (CFStringRef) portName);
}

@end
