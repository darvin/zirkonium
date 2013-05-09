//
//  ZKMORAudioHardwareSystem.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioHardwareSystem.h"
#import "ZKMORLoggerCPP.h"
#import "CAAudioHardwareSystem.h"
#import "CAAudioHardwareDevice.h"
#import "CAAudioHardwareStream.h"
#import "ZKMORUtilities.h"
#import "CAException.h"

NSString* const	ZKMORAudioHardwareDevicesChangedNotification = @"ZKMORAudioHardwareDevicesChangedNotification";
NSString* const	ZKMORAudioDeviceSampleRateChangedNotification = @"ZKMORAudioDeviceSampleRateChangedNotification";

@interface ZKMORAudioDevice (ZKMORAudioDevicePrivate)

- (id)initWithAudioDeviceID:(AudioDeviceID)deviceID;
- (id)initWithIndex:(unsigned)index;
- (void)registerForPropertyChanges;
- (void)unregisterForPropertyChanges;
- (void)updateChannelNames;
- (void)updateOutputChannelNamesOnStream:(AudioStreamID)streamID;
- (void)updateInputChannelNamesOnStream:(AudioStreamID)streamID;
- (void)valueChangedForDevice:(AudioDeviceID)inDevice property:(AudioDevicePropertyID)inPropertyID channel:(UInt32)channel isInput:(BOOL)isInput;

// Key-Value Obeserving
	// methods that are used internally to invoke
	// Key-Value Observing notifications on the main thread
- (void)valueChangedForProperty:(NSString *)propertyName;
	// This method takes ownerhip of the NSArray and will
	// release it when it is finished
- (void)valueChangedForProperties:(NSArray *)propertyNames;

@end

static OSStatus ZKMORAudioDevicePropertyListener(	AudioDeviceID			inDevice,
													UInt32					inChannel,
													Boolean					isInput,
													AudioDevicePropertyID	inPropertyID,
													void*					inClientData)
{
	ZKMORAudioDevice* audioDevice = (ZKMORAudioDevice*) inClientData;
	if (!audioDevice) return noErr;
									
	[audioDevice valueChangedForDevice: inDevice property: inPropertyID channel: inChannel isInput: isInput];
		
	return noErr;
}

static void DeviceAddGlobalPropListener(CAAudioHardwareDevice* device, int property, id refCon)
{
	device->AddPropertyListener(0, kAudioDeviceSectionGlobal, property, ZKMORAudioDevicePropertyListener,  refCon);
}

static void DeviceRemoveGlobalPropListener(CAAudioHardwareDevice* device, int property)
{
	try {
		device->RemovePropertyListener(0, kAudioDeviceSectionGlobal, property, ZKMORAudioDevicePropertyListener);
	} catch (const CAException& e) {
			// ignore the bad device error -- this just means the device
			// has gone away, in which case, we don't need to unregister
			// on it anyway
		if (!e.GetError() == kAudioHardwareBadDeviceError) {
			ZKMORLogError(kZKMORLogSource_Hardware, 
				CFSTR("Unregister device listener failed on property %u"), property);
		}
	}
}

@implementation ZKMORAudioDevice

	// Need to modify the superclass implementation of this
	// because the value can be changed from the system
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
	BOOL automatic;
    if ([theKey isEqualToString: @"numberOfOutputChannels"]) {
        automatic = NO;
    } else if ([theKey isEqualToString: @"nominalSampleRate"]) {
		 automatic = NO;
	} else if ([theKey isEqualToString: @"actualSampleRate"]) {
		 automatic = NO;
	} else if ([theKey isEqualToString: @"ioBufferSize"]) {
		 automatic = NO;
	} else if ([theKey isEqualToString: @"throughput"]) {
		 automatic = NO;
	} else if ([theKey isEqualToString: @"isRunning"]) {
		 automatic = NO;
	} else if ([theKey isEqualToString: @"isRunningSomewhere"]) {
		 automatic = NO;
	} else if ([theKey isEqualToString: @"isAlive"]) {
		 automatic = NO;
	} else {
        automatic = [super automaticallyNotifiesObserversForKey: theKey];
    }
	
    return automatic;
}


- (void)dealloc {
	[self unregisterForPropertyChanges];
	
	if (mAudioHardwareDevice) delete mAudioHardwareDevice;
	if (_audioDeviceDescription) [_audioDeviceDescription release];
	if (_outputChannelNames) [_outputChannelNames release];
	if (_inputChannelNames) [_inputChannelNames release];
	[super dealloc];
}

- (id)initWithAudioDeviceID:(AudioDeviceID)deviceID {
	if (self = [super init]) {
		try {
			mAudioHardwareDevice = new CAAudioHardwareDevice(deviceID);
			CFStringRef name = mAudioHardwareDevice->CopyName();
			CFStringRef manu = mAudioHardwareDevice->CopyManufacturer();
			_audioDeviceDescription = [[NSString alloc] initWithFormat: @"%@:%@", manu, name];
			CFRelease(name);
			CFRelease(manu);
			
			_isDefaultInput = (CAAudioHardwareSystem::GetDefaultDevice(true, false) == deviceID);
			_isDefaultOutput = (CAAudioHardwareSystem::GetDefaultDevice(false, false) == deviceID);
			_isSystemOutput = (CAAudioHardwareSystem::GetDefaultDevice(false, true) == deviceID);
			
			[self updateChannelNames];
		} catch (CAException& e) {			
			// this isn't a problem -- the device went away, but we'll
			// be notified of this soon enough and this instance will then
			// be collected
			mAudioHardwareDevice = NULL;
			_isDefaultInput = false;
			_isDefaultOutput = false;
			_isSystemOutput = false;
			_audioDeviceDescription = @"Dead Device";
			ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Hardware, 
				CFSTR("Device removed after initialization %u"), deviceID);
		}
		
		try {
			[self registerForPropertyChanges];
		} catch (CAException& e) {
			OSStatus err = e.GetError();
			ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Hardware, 
				CFSTR("%u(%4.4s): Could not register for changes on device %@"), 
				err, &err, _audioDeviceDescription);
		}
	}

	return self;
}

- (id)initWithIndex:(unsigned)index
{
	return [self initWithAudioDeviceID: CAAudioHardwareSystem::GetDeviceAtIndex(index)];
}

#pragma mark _____ General Information 
- (AudioDeviceID)audioDeviceID { return (mAudioHardwareDevice) ? mAudioHardwareDevice->GetAudioDeviceID() : 0; }
- (NSString *)audioDeviceDescription { return _audioDeviceDescription; }
- (NSString *)UID { return [(NSString*) mAudioHardwareDevice->CopyUID() autorelease]; }
- (NSString *)configurationApplicationBundleID {
	return (mAudioHardwareDevice) ? 
		[(NSString*)mAudioHardwareDevice->CopyConfigurationApplicationBundleID() autorelease] :
		nil;
}


#pragma mark _____ Device Information
- (BOOL)isInputDevice { return (mAudioHardwareDevice) ? mAudioHardwareDevice->HasSection(kAudioDeviceSectionInput) : NO; }
- (BOOL)isOutputDevice { return (mAudioHardwareDevice) ? mAudioHardwareDevice->HasSection(kAudioDeviceSectionOutput) : NO; }

- (unsigned)numberOfOutputChannels { return (mAudioHardwareDevice) ? mAudioHardwareDevice->GetTotalNumberChannels(kAudioDeviceSectionOutput) : 0; }
- (unsigned)numberOfInputChannels { return (mAudioHardwareDevice) ? mAudioHardwareDevice->GetTotalNumberChannels(kAudioDeviceSectionInput) : 0; }

- (NSArray *)outputChannelNames { return _outputChannelNames; }
- (NSArray *)inputChannelNames { return _inputChannelNames; }

- (Float64)nominalSampleRate { return (mAudioHardwareDevice) ? mAudioHardwareDevice->GetNominalSampleRate() : 0.0; }
- (Float64)actualSampleRate { return (mAudioHardwareDevice) ? mAudioHardwareDevice->GetActualSampleRate() : 0.0; }
- (UInt32)ioBufferSize { return (mAudioHardwareDevice) ? mAudioHardwareDevice->GetIOBufferSize() : 0; }

- (float)throughput {
	// throughput (in bytes) is the number of channels * the sample rate * the data byte size
	float throughput = [self numberOfOutputChannels] * [self nominalSampleRate] * sizeof(float);
		// devide by 1000 * 1000 to get throughput in MB / sec
	return throughput / 1000000.0f;
}


#pragma mark _____ System Information
- (BOOL)isDefaultOutput { return _isDefaultOutput; }
- (BOOL)isDefaultInput { return _isDefaultInput; }
- (BOOL)isSystemOutput { return _isSystemOutput; }

#pragma mark _____ Device Status
- (BOOL)isRunning { return (mAudioHardwareDevice) ? mAudioHardwareDevice->IsRunning() : NO; }
- (BOOL)isRunningSomewhere { return (mAudioHardwareDevice) ? mAudioHardwareDevice->IsRunningSomewhere() : NO; }
- (BOOL)isAlive { return (mAudioHardwareDevice) ? mAudioHardwareDevice->IsAlive() : NO; }

#pragma mark _____ Logging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	const char *aliveString = [self isAlive] ? "Alive" : "Dead";
	const char *runningSomewhereString = [self isRunningSomewhere] ? "Running Somewhere" : "Not Running Anywhere";	
		
	ZKMORLog(level, source, CFSTR("%@%s%@\n%s\tID: %u Manu Name: %@ %s %s"),
		tag, indentStr, self, indentStr, [self audioDeviceID], _audioDeviceDescription, 
		aliveString, runningSomewhereString);
}

#pragma mark _____ ZKMORAudioDevicePrivate
- (void)registerForPropertyChanges {
	CAAudioHardwareDevice* device = [self caAudioHardwareDevice];
	
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyDeviceIsAlive, self);
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyDeviceHasChanged, self);
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyDeviceIsRunning, self);
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyDeviceIsRunningSomewhere,  self);
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyBufferFrameSize, self);									
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyStreams, self);
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyNominalSampleRate, self);
	DeviceAddGlobalPropListener(device, kAudioDevicePropertyJackIsConnected, self);
	DeviceAddGlobalPropListener(device, kAudioDeviceProcessorOverload, self);
}

- (void)unregisterForPropertyChanges {

	CAAudioHardwareDevice* device = [self caAudioHardwareDevice];
	
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyDeviceIsAlive);
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyDeviceHasChanged);
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyDeviceIsRunning);
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyDeviceIsRunningSomewhere);
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyBufferFrameSize);									
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyStreams);
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyNominalSampleRate);
	DeviceRemoveGlobalPropListener(device, kAudioDevicePropertyJackIsConnected);
	DeviceRemoveGlobalPropListener(device, kAudioDeviceProcessorOverload);
}

- (void)updateChannelNames
{
	if (_outputChannelNames) [_outputChannelNames release];
	_outputChannelNames = [[NSMutableArray alloc] init];

	// enumerate through the output streams
	UInt32 i, count = mAudioHardwareDevice->GetNumberStreams(kAudioDeviceSectionOutput);
	for (i = 0; i < count; i++)
		[self updateOutputChannelNamesOnStream: mAudioHardwareDevice->GetStreamByIndex(kAudioDeviceSectionOutput, i)];
	
	if (_inputChannelNames) [_inputChannelNames release];
	_inputChannelNames = [[NSMutableArray alloc] init];

	// enumerate through the input streams
	count = mAudioHardwareDevice->GetNumberStreams(kAudioDeviceSectionInput);
	for (i = 0; i < count; i++)
		[self updateInputChannelNamesOnStream: mAudioHardwareDevice->GetStreamByIndex(kAudioDeviceSectionInput, i)];
}

- (void)updateOutputChannelNamesOnStream:(AudioStreamID)streamID
{
	CAAudioHardwareStream hardwareStream(streamID);
	NSString* streamName;
	try {
		streamName = (NSString *) hardwareStream.CopyName();
	} catch (CAException& e) {
		// stream has no name
		streamName = nil;
	}
	
	// go through each channel in the stream
	AudioStreamBasicDescription streamFormat;
	hardwareStream.GetCurrentIOProcFormat(streamFormat);
	
		// mono stream -- handle the single channel
	if (streamFormat.mChannelsPerFrame < 2) {
		if (!streamName) streamName = [[NSString alloc] initWithFormat: @"CH:%u", hardwareStream.GetStartingDeviceChannel()];
			
		[_outputChannelNames addObject: streamName];		
		[streamName release];
		return;
	} 

	UInt32 i, count = streamFormat.mChannelsPerFrame;
	for (i = 0; i < count; i++) {
		NSString* chName;
		chName = (streamName) ?
			[[NSString alloc] initWithFormat: @"%@:%u", streamName, hardwareStream.GetStartingDeviceChannel() + i] :
			[[NSString alloc] initWithFormat: @"CH:%u", hardwareStream.GetStartingDeviceChannel() + i];
		[_outputChannelNames addObject: chName];
		[chName release];
	}

	[streamName release];
}

- (void)updateInputChannelNamesOnStream:(AudioStreamID)streamID
{
	CAAudioHardwareStream hardwareStream(streamID);
	NSString* streamName;
	try {
		streamName = (NSString *) hardwareStream.CopyName();
	} catch (CAException& e) {
		// stream has no name
		streamName = nil;
	}
	
	// go through each channel in the stream
	AudioStreamBasicDescription streamFormat;
	hardwareStream.GetCurrentIOProcFormat(streamFormat);
	
		// mono stream -- handle the single channel
	if (streamFormat.mChannelsPerFrame < 2) {
		if (!streamName) streamName = [[NSString alloc] initWithFormat: @"CH:%u", hardwareStream.GetStartingDeviceChannel()];
			
		[_inputChannelNames addObject: streamName];		
		[streamName release];
		return;
	} 

	UInt32 i, count = streamFormat.mChannelsPerFrame;
	for (i = 0; i < count; i++) {
		NSString* chName;
		chName = (streamName) ?
			[[NSString alloc] initWithFormat: @"%@:%u", streamName, hardwareStream.GetStartingDeviceChannel() + i] :
			[[NSString alloc] initWithFormat: @"CH:%u", hardwareStream.GetStartingDeviceChannel() + i];
		[_inputChannelNames addObject: chName];
		[chName release];
	}

	[streamName release];
}

- (void)valueChangedForDevice:(AudioDeviceID)inDevice property:(AudioDevicePropertyID)inPropertyID channel:(UInt32)channel isInput:(BOOL)isInput
{
	if (kAudioDevicePropertyDeviceIsAlive == inPropertyID) {
		[self valueChangedForProperty: @"isAlive"];
	}
	if (kAudioDevicePropertyDeviceHasChanged == inPropertyID) {
			// valueChangedForProperties will release this arry
		NSArray* propertyNames = 
			[[NSArray alloc] 
				initWithObjects: 
					@"isAlive", @"isRunning", @"isRunningSomewhere",
					@"numberOfOutputChannels", @"ioBufferSize",
					@"nominalSampleRate", @"throughput", 
					nil];	
		[self valueChangedForProperties: propertyNames];
	}
	if (kAudioDevicePropertyDeviceIsRunning == inPropertyID) {
		[self valueChangedForProperty: @"isRunning"];
	}
	if (kAudioDevicePropertyDeviceIsRunningSomewhere == inPropertyID) {
		[self valueChangedForProperty: @"isRunningSomewhere"];
	}
	if (kAudioDevicePropertyStreams == inPropertyID) {
		[self valueChangedForProperty: @"numberOfOutputChannels"];
	}
	if (kAudioDevicePropertyBufferFrameSize == inPropertyID) {
		[self valueChangedForProperty: @"ioBufferSize"];
	}	
	if (kAudioDevicePropertyNominalSampleRate == inPropertyID) {
			// valueChangedForProperties will release this arry
		NSArray* propertyNames = 
			[[NSArray alloc] 
				initWithObjects: 
					@"nominalSampleRate", @"throughput", 
					nil];	
		[self valueChangedForProperties: propertyNames];		
	}
	if (kAudioDevicePropertyJackIsConnected == inPropertyID) {

	}	
	if (kAudioDeviceProcessorOverload == inPropertyID)
		ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_Hardware, CFSTR("Hardware overload on device %u"), inDevice);
}

- (void)mainThreadValueChangedForProperty:(NSString *)propertyName {
	[self willChangeValueForKey: propertyName];
	[self didChangeValueForKey: propertyName];
	if (@"nominalSampleRate" == propertyName)
		[[NSNotificationCenter defaultCenter] postNotificationName: ZKMORAudioDeviceSampleRateChangedNotification object: self];
}

- (void)mainThreadValueChangedForProperties:(NSArray *)propertyNames {
	unsigned count = [propertyNames count];
	unsigned i;
	for (i = 0; i < count; i++) {
		NSString* propertyName = [propertyNames objectAtIndex: i];
		[self willChangeValueForKey: propertyName];
	}
	
	for (i = 0; i < count; i++) {
		NSString* propertyName = [propertyNames objectAtIndex: i];
		[self didChangeValueForKey: propertyName];
		if (@"nominalSampleRate" == propertyName) 
			[[NSNotificationCenter defaultCenter] postNotificationName: ZKMORAudioDeviceSampleRateChangedNotification object: self];
	}
	
	[propertyNames release];
}

- (void)valueChangedForProperty:(NSString *)propertyName {
	[self 
		performSelectorOnMainThread: @selector(mainThreadValueChangedForProperty:)
		withObject: propertyName
		waitUntilDone: NO];
}

- (void)valueChangedForProperties:(NSArray *)propertyNames {
	[self 
		performSelectorOnMainThread: @selector(mainThreadValueChangedForProperties:)
		withObject: propertyNames
		waitUntilDone: NO];
}


- (CAAudioHardwareDevice *)caAudioHardwareDevice {
	return mAudioHardwareDevice;
}


@end

@implementation ZKMORAudioDevice(ZKMORAudioDeviceApplicationServices)

- (BOOL)launchConfigurationApplicationWithError:(NSError **)error
{
	NSString* applicationBundleID = [self configurationApplicationBundleID];

	// get the FSRef of the config app
	FSRef theAppFSRef;
	OSStatus err = LSFindApplicationForInfo(kLSUnknownCreator, (CFStringRef)applicationBundleID, NULL, &theAppFSRef, NULL);
	if (err) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find configuration application to launch %i"), err);
		if (error != NULL)
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		return NO;
	}
	
	//	open it
	err = LSOpenFSRef(&theAppFSRef, NULL);
	if (err) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not open configuration application %i"), err);
		if (error != NULL)
			*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];		
		return NO;
	}
	return YES;
}

@end

static ZKMORAudioHardwareSystem* sharedAudioHardwareSystem = NULL;

static OSStatus ZKMORAudioHardwarePropertyListener(	AudioHardwarePropertyID		inPropertyID,
													void*						inClientData)
{
	ZKMORAudioHardwareSystem* hardwareSystem = (ZKMORAudioHardwareSystem*) inClientData;
	if (kAudioHardwarePropertyDevices == inPropertyID) {
		[hardwareSystem 
			performSelectorOnMainThread: @selector(updateDevices)
			withObject: nil
			waitUntilDone: NO];
	}
	
	return noErr;
}	

@interface ZKMORAudioHardwareSystem (ZKMORAudioHardwareSystemPrivate)

- (void)initializeDevices;
- (void)updateDevices;
- (void)updateDevicesRemoveRemovedDevices;
- (void)updateDevicesInsertInsertedDevices;
- (void)removeFromOutputDevices:(ZKMORAudioDevice *)device;
- (void)insertIntoOutputDevices:(ZKMORAudioDevice *)device;

- (void)registerForPropertyChanges;

@end


@implementation ZKMORAudioHardwareSystem

	// Need to modify the superclass implementation of this
	// because the value can be changed from the system
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
	BOOL automatic;
    if ([theKey isEqualToString: @"availableDevices"]) {
        automatic = NO;
    } else if ([theKey isEqualToString: @"outputDevices"]) {
		 automatic = NO;
	} else {
        automatic = [super automaticallyNotifiesObserversForKey: theKey];
    }
	
    return automatic;
}

- (void)dealloc {
	sharedAudioHardwareSystem = NULL;
	if (_availableDevices) [_availableDevices release];
	if (_outputDevices) [_outputDevices release];
	[super dealloc];		
}

- (id)init {
	if (sharedAudioHardwareSystem) {
		[self release];
		return sharedAudioHardwareSystem;
	}
	
	if (self = [super init]) {
		sharedAudioHardwareSystem = self;
	
		[self initializeDevices];
		[self registerForPropertyChanges];
	}
	
	return self;
}

#pragma mark _____ Singleton
+ (ZKMORAudioHardwareSystem *)sharedAudioHardwareSystem 
{
	if (!sharedAudioHardwareSystem) {
			// this will assign the instance to sharedAudioHardwareSystemInfo
		[[ZKMORAudioHardwareSystem alloc] init];
	}
		
	return sharedAudioHardwareSystem;
}

#pragma mark _____ Device Accessing
+ (unsigned)numberOfDevices { return CAAudioHardwareSystem::GetNumberDevices(); }

+ (AudioDeviceID)audioDeviceIDForDeviceAtIndex:(unsigned)index {
	return CAAudioHardwareSystem::GetDeviceAtIndex(index);
}

#pragma mark _____ Queries
+ (BOOL)isDefaultInputAlsoDefaultOutput {
	return CAAudioHardwareSystem::GetDefaultDevice(true, false) 
		== CAAudioHardwareSystem::GetDefaultDevice(false, false);
}

#pragma mark _____ Accessors
- (NSArray *)availableDevices { return _availableDevices; }
- (NSArray *)outputDevices { return _outputDevices; }

- (ZKMORAudioDevice *)defaultOutputDevice {
	ZKMORAudioDevice* defaultOutput = nil;
	unsigned count, i;
	count = [_outputDevices count];
	for (i = 0; i < count; i++) {
		ZKMORAudioDevice* device = [_outputDevices objectAtIndex: i];
		if ([device isDefaultOutput]) {
			defaultOutput = device;
			break;
		}
	}

	return defaultOutput;	
}

- (ZKMORAudioDevice *)defaultInputDevice
{
	ZKMORAudioDevice* defaultInput = nil;
	unsigned count, i;
	count = [_availableDevices count];
	for (i = 0; i < count; i++) {
		ZKMORAudioDevice* device = [_availableDevices objectAtIndex: i];
		if ([device isDefaultInput]) {
			defaultInput = device;
			break;
		}
	}

	return defaultInput;	
}

- (ZKMORAudioDevice *)systemOutputDevice
{
	ZKMORAudioDevice* systemOutput = nil;
	unsigned count, i;
	count = [_outputDevices count];
	for (i = 0; i < count; i++) {
		ZKMORAudioDevice* device = [_outputDevices objectAtIndex: i];
		if ([device isSystemOutput]) {
			systemOutput = device;
			break;
		}
	}

	return systemOutput;	
}

- (ZKMORAudioDevice *)audioDeviceForDeviceID:(AudioDeviceID)audioDeviceID {
	unsigned i;
	unsigned numberOfDevices = [_availableDevices count];
	for (i = 0; i < numberOfDevices; i++) {
		
		ZKMORAudioDevice* device = [_availableDevices objectAtIndex: i];
		if ([device audioDeviceID] == audioDeviceID)
			return device;
	}
	
	return nil;
}

- (ZKMORAudioDevice *)audioDeviceForUID:(NSString *)uid
{
	unsigned i;
	unsigned numberOfDevices = [_availableDevices count];
	for (i = 0; i < numberOfDevices; i++) {
		
		ZKMORAudioDevice* device = [_availableDevices objectAtIndex: i];
		if ([[device UID] isEqualToString: uid])
			return device;
	}
	
	return nil;
}

#pragma mark _____ ZKMORAudioHardwareSystemPrivate
- (void)initializeDevices {

	unsigned i;
	unsigned numberOfDevices = [ZKMORAudioHardwareSystem numberOfDevices];
	
	_availableDevices = [[NSMutableArray alloc] initWithCapacity: numberOfDevices];
	_outputDevices = [[NSMutableArray alloc] initWithCapacity: numberOfDevices];	

	for (i = 0; i < numberOfDevices; i++) {
		ZKMORAudioDevice* device = 
			[[ZKMORAudioDevice alloc] initWithIndex: i];

		[_availableDevices addObject: device];
			// the array owns it now
		[device release];
	}

	for (i = 0; i < numberOfDevices; i++) {
		ZKMORAudioDevice* device = [_availableDevices objectAtIndex: i];
		if ([device isOutputDevice])
			[_outputDevices addObject: device];
	}
}

- (void)updateDevices {
	[self updateDevicesRemoveRemovedDevices];
	[self updateDevicesInsertInsertedDevices];
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMORAudioHardwareDevicesChangedNotification object: self];
}

- (void)updateDevicesRemoveRemovedDevices {
	NSMutableIndexSet* removedDeviceIndex = [NSMutableIndexSet indexSet];
	unsigned i, elementIndex;
	
	for (i = [_availableDevices count]; i > 0; i--) {
		elementIndex = i - 1;
		ZKMORAudioDevice* device = [_availableDevices objectAtIndex: elementIndex];
		unsigned deviceIndex = CAAudioHardwareSystem::GetIndexForDevice([device audioDeviceID]);

		// if the device still exists, we can skip it
		if (deviceIndex < 0xFFFFFFFF)
			continue;
		
		// this device has been removed, take it out of the arrays
		[self removeFromOutputDevices: device];

		[removedDeviceIndex addIndex: elementIndex];
		[self	
			willChange:			NSKeyValueChangeRemoval 
			valuesAtIndexes:	removedDeviceIndex
			forKey:				@"availableDevices"];
		[_availableDevices removeObjectAtIndex: elementIndex];
		[self	
			didChange:			NSKeyValueChangeRemoval 
			valuesAtIndexes:	removedDeviceIndex
			forKey:				@"availableDevices"];
		[removedDeviceIndex removeAllIndexes];
	}		
}

- (void)updateDevicesInsertInsertedDevices {
	unsigned numberOfDevices = [ZKMORAudioHardwareSystem numberOfDevices];
	NSMutableIndexSet* insertedDeviceIndex = [NSMutableIndexSet indexSet];
	unsigned i;

	for (i = 0; i < numberOfDevices; i++) {
		// if the device is already in the list, we don't need to
		// add it again
		if ([self audioDeviceForDeviceID: CAAudioHardwareSystem::GetDeviceAtIndex(i)])
			continue;
		
		// a new device
		[insertedDeviceIndex addIndex: [_availableDevices count]];
		[self	
			willChange:			NSKeyValueChangeInsertion
			valuesAtIndexes:	insertedDeviceIndex
			forKey:				@"availableDevices"];		
		ZKMORAudioDevice* device = 
			[[ZKMORAudioDevice alloc] initWithIndex: i];
		[_availableDevices addObject: device];
			// the array owns it now
		[device release];

		[self	
			didChange:			NSKeyValueChangeInsertion 
			valuesAtIndexes:	insertedDeviceIndex
			forKey:				@"availableDevices"];
		[insertedDeviceIndex removeAllIndexes];
		
		[self insertIntoOutputDevices: device];
	}
}

- (void)removeFromOutputDevices:(ZKMORAudioDevice *)device
{
	unsigned outputDeviceIndex = [_outputDevices indexOfObject: device];
	if (NSNotFound != outputDeviceIndex) {
		NSMutableIndexSet* removedDeviceIndex = 
			[NSMutableIndexSet indexSetWithIndex: outputDeviceIndex];

		[self	
			willChange:			NSKeyValueChangeRemoval 
			valuesAtIndexes:	removedDeviceIndex
			forKey:				@"outputDevices"];
			
		[_outputDevices removeObjectAtIndex: outputDeviceIndex];

		[self	
			didChange:			NSKeyValueChangeRemoval 
			valuesAtIndexes:	removedDeviceIndex
			forKey:				@"outputDevices"];
	}
}

- (void)insertIntoOutputDevices:(ZKMORAudioDevice *)device
{
	if ([device isOutputDevice]) {
		NSMutableIndexSet* insertedDeviceIndex = [NSMutableIndexSet indexSetWithIndex: [_outputDevices count]];
		[self	
			willChange:			NSKeyValueChangeInsertion
			valuesAtIndexes:	insertedDeviceIndex
			forKey:				@"outputDevices"];
		[_outputDevices addObject: device];
		[self	
			didChange:			NSKeyValueChangeInsertion 
			valuesAtIndexes:	insertedDeviceIndex
			forKey:				@"outputDevices"];
	}
}

- (void)registerForPropertyChanges {

	CAAudioHardwareSystem::AddPropertyListener(	kAudioHardwarePropertyDevices, 
												ZKMORAudioHardwarePropertyListener, 
												self);
}

@end
