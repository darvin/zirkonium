//
//  ZKMRNZirkoniumSystem.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNStudioSetupDocument.h"
#import "ZKMRNPreferencesController.h"
#import "ZKMRNPieceDocument.h"
#import "ZKMRNOutputPatch.h"
#import "ZKMRNOutputPatchChannel.h"
#import "ZKMRNDirectOutPatch.h"
#import "ZKMRNFileV1Importer.h"
#import "ZKMRNDeviceManager.h"
#import "ZKMORLoggerClient.h"
#import "ZKMRNLightController.h"
#import "ZKMRNOSCController.h"
#import "ZKMRNAudioUnitController.h"


static NSString* const ZKMRNErrorDomain = @"ZKMRNErrorDomain";
ZKMRNZirkoniumSystem* gSharedZirkoniumSystem = nil;

@interface ZKMRNZirkoniumSystem (ZKMRNZirknoiumSystemPrivate)

- (void)createSpatializationTimer;
- (void)destroySpatializationTimer;
- (void)spatTick:(id)timer;

- (void)createDisplayTimer;
- (void)destroyDisplayTimer;
- (void)tick:(id)timer;

- (void)createLoggerTimer;
- (void)destroyLoggerTimer;
- (void)logTick:(id)timer;

- (NSString *)fileNameForNewFile;
- (void)flushAndCloseRecordFile;
- (void)createRecordFile;
- (void)cycleRecordFile;

@end


@implementation ZKMRNZirkoniumSystem
#pragma mark _____ NSObject Overrides
- (void)dealloc 
{
	gSharedZirkoniumSystem = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[_studioSetup release], _studioSetup = nil;
	[_spatializationMixer release], _spatializationMixer = nil;
	[_speakerLayoutSimulator release], _speakerLayoutSimulator = nil;
	[_deviceOutput release], _deviceOutput = nil;
	[_panner unbind: @"speakerLayout"];
	[_panner release], _panner = nil;
	[_scheduler release], _scheduler = nil;
	[_oscController release], _oscController = nil;
	[_deviceManager release], _deviceManager = nil;
	[_audioUnitController release], _audioUnitController = nil;
	if (_spatializationTimer) [self destroySpatializationTimer];
	if (_displayTimer) [self destroyDisplayTimer];
	if (_loggerTimer) [self destroyLoggerTimer];
    [super dealloc];
}

- (void)awakeFromNib
{
	// this is obviously not thread safe, but doesn't need to be either -- at the time this method
	// is called, there is only one thread running.
	gSharedZirkoniumSystem = self;
	
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
//	ZKMORLogPrinterStart();
	_loggerClient = [ZKMORLoggerClient sharedLoggerClient];
	_isPlaying = NO;
	_isTesting = NO;
	
	_masterGain = 1.f;
	_filePlayerNumberOfBuffers = 4;
	_filePlayerBufferSize = 4096;
	_sampleRateConverterQuality = kAudioConverterQuality_Min;
	_displayTimerInterval = 0.1;
	_spatializationTimerInterval = 0.025;
	
	// initialize the audio first
	_deviceOutput = [[ZKMORDeviceOutput alloc] init];
	_audioGraph = [[ZKMORGraph alloc] init];
	[_deviceOutput setGraph: _audioGraph];
		// give ownership to the device output
	[_audioGraph release];

	_speakerLayoutSimulator	= [[ZKMNRSpeakerLayoutSimulator alloc] init];
	_loudspeakerMode = kZKMRNSystemLoudspeakerMode_Real;
	_loudspeakerSimulationMode = [_speakerLayoutSimulator simulationMode];
	_spatializationMixer = [[ZKMORMixerMatrix alloc] init];
	[_spatializationMixer setPurposeString: @"Zirk System Spat Mixer"];
	[_spatializationMixer setMeteringOn: YES];
	[_audioGraph beginPatching];
		[_audioGraph setHead: _spatializationMixer];
	[_audioGraph endPatching];
	[_audioGraph initialize];
	
	_panner = [[ZKMNRVBAPPanner alloc] init];
	[_panner bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[_panner setMixer: _spatializationMixer];
	
	_scheduler = [[ZKMNREventScheduler alloc] init];
	[_scheduler setClock: [self clock]];
	[_scheduler addTimeDependent: _panner];
	
	[self initializeStudioSetup];
	_lightController = [[ZKMRNLightController alloc] initWithZirkoniumSystem: self];	
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputPatchChanged:) name: ZKMRNOutputPatchChangedNotification object: nil];
	
	_oscController = [[ZKMRNOSCController alloc] init];
	_deviceManager = [[ZKMRNDeviceManager alloc] init];
	_audioUnitController = [[ZKMRNAudioUnitController alloc] init];
//	_isStudioSetupSupported = NO;
	_isStudioSetupSupported = YES;
	
	_isRecording = NO;
	_hasFileName = NO;
	_fileRecorder = [[ZKMORAudioFileRecorder alloc] init];
	
	[self createLoggerTimer];
	_preferencesController = [[ZKMRNPreferencesController alloc] initWithZirkoniumSystem: self];
}

#pragma mark _____ Singleton
	// The MainMenu.nib automatically creates an instance of ZKMRNZirkoniumSystem
+ (ZKMRNZirkoniumSystem *)sharedZirkoniumSystem { return gSharedZirkoniumSystem; }

#pragma mark _____ Accessors
- (ZKMORAudioDevice *)audioOutputDevice { return [_deviceOutput outputDevice]; }
- (void)setAudioOutputDevice:(ZKMORAudioDevice *)audioOutputDevice 
{ 
	NSError* error = nil;
	if (![_deviceOutput setOutputDevice: audioOutputDevice error: &error]) {
		[_preferencesController presentError: error];
	}
}
- (ZKMRNSpeakerSetup *)speakerSetup { return _speakerSetup; }
- (void)setSpeakerSetup:(ZKMRNSpeakerSetup *)speakerSetup
{
	if (_speakerSetup != speakerSetup) {
		if (_speakerSetup) [_speakerSetup release];
		_speakerSetup = speakerSetup; 
		if (!_speakerSetup) return;
		[_speakerSetup retain];

/*
			// DEBUG
		NSDictionary* speakerPlist = [[_speakerSetup speakerLayout] dictionaryRepresentation];
		NSString* error;
		NSData* plistData = [NSPropertyListSerialization dataFromPropertyList: speakerPlist format: NSPropertyListXMLFormat_v1_0 errorDescription: &error];
		NSMutableString* plistString = [[NSMutableString alloc] initWithData: plistData encoding: NSASCIIStringEncoding];
		[plistString replaceOccurrencesOfString:@"\n" withString: @" " options: 0 range: NSMakeRange(0, [plistString length])];
		NSLog(@"Layout:\n %@", plistString);
		[plistString release];
*/
		[_lightController speakerSetupChanged];
		[self synchronizeAudioGraph];
	}
}
- (NSManagedObject *)room { return _room; }
- (void)setRoom:(NSManagedObject *)room
{
	if (_room != room) {
		if (_room) [_room release];
		_room = room; 
		if (_room) [_room retain];
	}
}

- (unsigned)loudspeakerMode { return _loudspeakerMode; }
- (void)setLoudspeakerMode:(unsigned)loudspeakerMode { _loudspeakerMode = loudspeakerMode; [self synchronizeAudioGraph]; }
- (unsigned)loudspeakerSimulationMode { return _loudspeakerSimulationMode; }
- (void)setLoudspeakerSimulationMode:(unsigned)loudspeakerSimulationMode { _loudspeakerSimulationMode = loudspeakerSimulationMode; [self synchronizeAudioGraph]; }

- (ZKMRNInputPatch *)inputPatch  { return _inputPatch; }
- (void)setInputPatch:(ZKMRNInputPatch *)inputPatch
{
	if (_inputPatch != inputPatch) {
		if (_inputPatch) [_inputPatch release];
		_inputPatch = inputPatch; 
		if (_inputPatch) [_inputPatch retain];
		[self synchronizeInputPatch];
	}
}

- (ZKMRNOutputPatch *)outputPatch { return _outputPatch; }
- (void)setOutputPatch:(ZKMRNOutputPatch *)outputPatch
{
	if (_outputPatch != outputPatch) {
		if (_outputPatch) [_outputPatch release];
		_outputPatch = outputPatch; 
		if (_outputPatch) [_outputPatch retain];
		[self synchronizeOutputPatch];
	}
}

- (ZKMRNDirectOutPatch *)directOutPatch { return _directOutPatch; }
- (void)setDirectOutPatch:(ZKMRNDirectOutPatch *)directOutPatch
{
	if (_directOutPatch != directOutPatch) {
		if (_directOutPatch) [_directOutPatch release];
		_directOutPatch = directOutPatch; 
		if (_directOutPatch) [_directOutPatch retain];
		[self synchronizeDirectOutPatch];
	}
}

- (float)masterGain { return _masterGain; }
- (void)setMasterGain:(float)masterGain
{
	_masterGain = masterGain;
	[_deviceOutput setVolume: _masterGain];
	[_deviceManager setMasterGain: _masterGain];
}

- (unsigned)filePlayerNumberOfBuffers { return _filePlayerNumberOfBuffers; }
- (void)setFilePlayerNumberOfBuffers:(unsigned)filePlayerNumberOfBuffers { _filePlayerNumberOfBuffers = filePlayerNumberOfBuffers; }

- (unsigned)filePlayerBufferSize { return _filePlayerBufferSize; }
- (void)setFilePlayerBufferSize:(unsigned)filePlayerBufferSize { _filePlayerBufferSize = filePlayerBufferSize; }

- (unsigned)sampleRateConverterQuality { return _sampleRateConverterQuality; }
- (void)setSampleRateConverterQuality:(unsigned)sampleRateConverterQuality { _sampleRateConverterQuality = sampleRateConverterQuality; }

- (unsigned)sampleRateConverterQualityUI {
	unsigned srcQualityUI = 0;
	switch (_sampleRateConverterQuality) {
		case kAudioConverterQuality_Min:
			srcQualityUI = 0;
			break;
		case kAudioConverterQuality_Low:
			srcQualityUI = 1;
			break;
		case kAudioConverterQuality_Medium:
			srcQualityUI = 2;
			break;
		case kAudioConverterQuality_High:
			srcQualityUI = 3;
			break;
		case kAudioConverterQuality_Max:
			srcQualityUI = 4;
			break;
		default:
			break;
	}
	
	return srcQualityUI;
}

- (void)setSampleRateConverterQualityUI:(unsigned)sampleRateConverterQualityUI
{
	unsigned srcQuality = 0;
	switch (sampleRateConverterQualityUI) {
		case 0:
			srcQuality = kAudioConverterQuality_Min;
			break;
		case 1:
			srcQuality = kAudioConverterQuality_Low;
			break;
		case 2:
			srcQuality = kAudioConverterQuality_Medium;
			break;
		case 3:
			srcQuality = kAudioConverterQuality_High;
			break;
		case 4:
			srcQuality = kAudioConverterQuality_Max;
			break;
		default:
			break;
	}
	[self setSampleRateConverterQuality: srcQuality];
}

- (NSTimeInterval)displayTimerInterval { return _displayTimerInterval; }
- (void)setDisplayTimerInterval:(NSTimeInterval)displayTimerInterval
{
	_displayTimerInterval = displayTimerInterval;
	if (_displayTimer) { [self destroyDisplayTimer]; [self createDisplayTimer]; }
}

- (ZKMRNStudioSetupDocument *)studioSetupDocument { return _studioSetup; }
- (ZKMRNPreferencesController *)preferencesController { return _preferencesController; }
- (ZKMRNLightController *)lightController { return _lightController; }
- (ZKMORLoggerClient *)loggerClient { return _loggerClient; }

- (NSString *)zirkoniumVersionString
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"];
}

#pragma mark _____ Actions
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain
{
	NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
	// just ignore
	if ([documents count] < 1) {
		ZKMORLogDebug(CFSTR("/pan/az %u {%.2f %.2f} {%.2f %.2f} %.2f"), channel, center.azimuth, center.zenith, span.azimuthSpan, span.zenithSpan, gain);
		return;
	}
	NSEnumerator* docs = [documents objectEnumerator];
	id doc;
	while (doc = [docs nextObject]) {
		if ([doc respondsToSelector: @selector(panChannel:az:span:gain:)])
			[doc panChannel: channel az: center span: span gain: gain];
	}
}

- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain
{
	NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
	// just ignore
	if ([documents count] < 1) {
		ZKMORLogDebug(CFSTR("/pan/speaker/az %u {%.2f %.2f} %.2f"), channel, center.azimuth, center.zenith, gain);
		return;
	}
	NSEnumerator* docs = [documents objectEnumerator];
	id doc;
	while (doc = [docs nextObject]) {
		if ([doc respondsToSelector: @selector(panChannel:speakerAz:gain:)])
			[doc panChannel: channel speakerAz: center gain: gain];
	}
}

- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain
{
	NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
	// just ignore
	if ([documents count] < 1) {
		ZKMORLogDebug(CFSTR("/pan/speaker/xy %u {%.2f %.2f} %.2f"), channel, center.x, center.y, gain);
		return;
	}
	NSEnumerator* docs = [documents objectEnumerator];
	id doc;
	while (doc = [docs nextObject]) {
		if ([doc respondsToSelector: @selector(panChannel:speakerXy:gain:)])
			[doc panChannel: channel speakerXy: center gain: gain];
	}
}

- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain
{
	NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
	// just ignore
	if ([documents count] < 1) {
		ZKMORLogDebug(CFSTR("/pan/xy %u {%.2f %.2f} {%.2f %.2f} %.2f"), channel, center.x, center.y, span.xSpan, span.ySpan, gain);
		return;
	}
	NSEnumerator* docs = [documents objectEnumerator];
	id doc;
	while (doc = [docs nextObject]) {
		if ([doc respondsToSelector: @selector(panChannel:xy:span:gain:)])
			[doc panChannel: channel xy: center span: span gain: gain];
	}
}

#pragma mark _____ ZKMRNZirkoniumSystemAudio
- (ZKMORDeviceOutput *)deviceOutput { return _deviceOutput; }
- (ZKMORDeviceInput *)deviceInput { return [_deviceOutput deviceInput]; }
- (ZKMORGraph *)audioGraph { return _audioGraph; }
- (ZKMORMixerMatrix *)spatializationMixer { return _spatializationMixer; }
- (ZKMNRSpeakerLayoutSimulator *)speakerLayoutSimulator { return _speakerLayoutSimulator; }
- (ZKMNRVBAPPanner *)panner { return _panner; }
- (ZKMNREventScheduler *)scheduler { return _scheduler; }
- (ZKMORClock *)clock { return [_deviceOutput clock]; }


#pragma mark _____ ZKMRNZirkoniumSystemInternal
- (NSString *)applicationSupportFolder 
{
// Returns the support folder for the application, used to store the Core Data
// store file.  This code uses a folder named "Zirkonium" for
// the content, either in the NSApplicationSupportDirectory location or (if the
// former cannot be found), the system's temporary directory.
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent: @"Zirkonium"];
}

- (void)initializeStudioSetup
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSURL* studioURL = 
		[NSURL fileURLWithPath: [[self applicationSupportFolder] stringByAppendingPathComponent: @"studio.zrkstu"]];
	if (![fileManager fileExistsAtPath: [studioURL path]]) { [self createStudioSetupURL: studioURL]; return; }
		
	NSError* error = nil;
	_studioSetup = [[ZKMRNStudioSetupDocument alloc] initWithContentsOfURL: studioURL ofType: @"Studio" error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return;
	}
}

- (void)createStudioSetupURL:(NSURL *)studioURL
{
	NSError* error = nil;
	NSDocumentController* documentController = [NSDocumentController sharedDocumentController];

	// look for the defaultstudio.zrkstu and copy it over
	NSString* defaultStudioPath = [[NSBundle mainBundle] pathForResource: @"defaultsetup" ofType: @"zrkstu"];
	if (defaultStudioPath) {
		NSFileManager* fileManager = [NSFileManager defaultManager];
		NSString* studioPath = [studioURL path];
		NSString* applicationSupportFolder = [self applicationSupportFolder];
		BOOL success = YES;
		BOOL dirExists = [fileManager fileExistsAtPath: applicationSupportFolder];
		if (!dirExists) success = [fileManager createDirectoryAtPath: applicationSupportFolder attributes: nil];
		if (!success) NSLog(@"Could not create directory %@", applicationSupportFolder);		
		success = [fileManager copyPath: defaultStudioPath toPath: studioPath handler: nil];
		if (!success) NSLog(@"Could not copy studio setup %@", studioPath);
		_studioSetup = [documentController makeDocumentWithContentsOfURL: studioURL ofType: @"Studio" error: &error];
		if (error) {
			[[NSApplication sharedApplication] presentError: error];
			return;
		}
		[_studioSetup retain];
		[documentController addDocument: _studioSetup];	
		return;
	}
	
	_studioSetup = [documentController makeUntitledDocumentOfType: @"Studio" error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return;
	}
	
	[_studioSetup retain];
	[documentController addDocument: _studioSetup];
}


- (void)synchronizeInputPatch
{
	if (![_deviceOutput isInputEnabled]) return;

	ZKMORDeviceInput* deviceInput = [_deviceOutput deviceInput];
		// pass the info on to the device output
	if (!_inputPatch) {
		[deviceInput setChannelMap: nil];
		return;
	}
	
	unsigned numberOfChannels = [[_inputPatch valueForKey: @"numberOfChannels"] unsignedIntValue];
	[deviceInput setNumberOfChannels: numberOfChannels];

	NSMutableArray* channelMap = [deviceInput channelMap];
	unsigned i, count = [channelMap count];
		// initialize the channel map -- turn off all channels
	for (i = 0; i < count; i++) [channelMap replaceObjectAtIndex: i withObject: [NSNumber numberWithInt: -1]];
	
	NSEnumerator* inputs = [[_inputPatch valueForKey: @"channels"] objectEnumerator];
	NSManagedObject* inputChannel;
	while (inputChannel = [inputs nextObject]) {
		unsigned deviceInput = [[inputChannel valueForKey: @"sourceChannel"] unsignedIntValue] % count;
		unsigned zirkInput = [[inputChannel valueForKey: @"patchChannel"] unsignedIntValue];
		[channelMap replaceObjectAtIndex: zirkInput withObject: [NSNumber numberWithInt: deviceInput]];
	}
	[deviceInput setChannelMap: channelMap];
}

- (void)synchronizeOutputPatch
{
		// no need for the output patch in virtual loudspeaker mode
	if (kZKMRNSystemLoudspeakerMode_Virtual == _loudspeakerMode) {
		[_deviceOutput setChannelMap: nil];
		return;
	}
	
	unsigned numberOfSpeakers = [_speakerSetup numberOfSpeakers];
	NSMutableArray* channelMap = [_deviceOutput channelMap];
	unsigned i, count = [channelMap count];
		// initialize the channel map -- turn off all channels
	for (i = 0; i < count; ++i) [channelMap replaceObjectAtIndex: i withObject: [NSNumber numberWithInt: -1]];

	if (_outputPatch) {
		// apply the output patch
		NSEnumerator* outputs = [[_outputPatch valueForKey: @"channels"] objectEnumerator];
		NSManagedObject* outputChannel;
		while (outputChannel = [outputs nextObject]) {
			unsigned deviceOutput = [[outputChannel valueForKey: @"sourceChannel"] unsignedIntValue];
			NSNumber* zirkOutput = [outputChannel valueForKey: @"patchChannel"];
			if (deviceOutput < count) [channelMap replaceObjectAtIndex: deviceOutput withObject: zirkOutput];
		}
	} else {
		// turn on all the speakers
		for (i = 0; i < MIN(numberOfSpeakers, count); i++) {
			[channelMap replaceObjectAtIndex: i withObject: [NSNumber numberWithInt: i]];
		}
	}
	
	if (_directOutPatch) {
		// add the direct outs
		NSEnumerator* directOuts = [[_directOutPatch valueForKey: @"channels"] objectEnumerator];
		NSManagedObject* directOutChannel;
		while (directOutChannel = [directOuts nextObject]) {
			unsigned deviceOutput = [[directOutChannel valueForKey: @"sourceChannel"] unsignedIntValue];
			unsigned zirkOutput = numberOfSpeakers + [[directOutChannel valueForKey: @"patchChannel"] unsignedIntValue];
			if (deviceOutput < count) [channelMap replaceObjectAtIndex: deviceOutput withObject: [NSNumber numberWithInt: zirkOutput]];
		}		
	}
	
	[_deviceOutput setChannelMap: channelMap];
}

- (void)synchronizeDirectOutPatch
{
		// pass the info on to the device output
	if (!_directOutPatch || (kZKMRNSystemLoudspeakerMode_Virtual == _loudspeakerMode)) {
		return;
	}

	[self synchronizeAudioGraph];
	[self synchronizeOutputPatch];
}

- (void)synchronizeAudioGraph
{
	[_speakerLayoutSimulator setSpeakerLayout: [_speakerSetup speakerLayout]];
	[_speakerLayoutSimulator setSimulationMode: _loudspeakerSimulationMode];
		
		// TODO: Create ZKMRNZirkoniumSystem Graph
		// Graph should have a FileWriter at the end
		// ZKMRNPieceDocument >> spatializer >> simulator >> writer >> dac
	[_audioGraph beginPatching];
		unsigned numberOfSpeakers = [_speakerSetup numberOfSpeakers];
		if (kZKMRNSystemLoudspeakerMode_Real == _loudspeakerMode) {
			unsigned numberOfOutputChannels = numberOfSpeakers;
			[_spatializationMixer uninitialize];
			[_spatializationMixer setNumberOfOutputBuses: 1];
			if (_directOutPatch) numberOfOutputChannels += [_directOutPatch numberOfChannels];
			[[_spatializationMixer outputBusAtIndex: 0] setNumberOfChannels: numberOfOutputChannels];
			[_audioGraph setHead: _spatializationMixer];
			[self synchronizeRecorder];
		} else {
			ZKMORMixer3D* mixer3D = [_speakerLayoutSimulator mixer3D];
			[_spatializationMixer uninitialize];
			unsigned i;
			[_spatializationMixer setNumberOfOutputBuses: numberOfSpeakers];
			for (i = 0; i < numberOfSpeakers; i++) {
				ZKMOROutputBus* outputBus = [_spatializationMixer outputBusAtIndex: i];
				[outputBus setNumberOfChannels: 1];
				[_audioGraph patchBus: outputBus into: [mixer3D inputBusAtIndex: i]];
			}
			[_audioGraph setHead: mixer3D];
			[self synchronizeRecorder];
		}
		[_audioGraph initialize];
	[_audioGraph endPatching];
	[_spatializationMixer setInputsAndOutputsOn];
	[_panner transferPanningToMixer];
	[self synchronizeOutputPatch];
}

- (void)synchronizeRecorder
{
	ZKMORConduit* recordingSource = [_audioGraph head];
	memset(&_fileFormatDesc, 0, sizeof(_fileFormatDesc));
	unsigned numberOfChannels = [[recordingSource outputBusAtIndex: 0] numberOfChannels];
	[ZKMORAudioFileRecorder getAIFFInt16Format: &_fileFormatDesc channels: numberOfChannels];
	
	[_audioGraph beginPatching];
		if ([self isRecording]) {
			[_fileRecorder uninitialize];
			[[_fileRecorder outputBusAtIndex: 0] setNumberOfChannels: numberOfChannels];
			[[_fileRecorder inputBusAtIndex: 0] setNumberOfChannels: numberOfChannels];
			if (!_hasFileName) {
				NSError* error = nil;
				[_fileRecorder setFilePath: [self fileNameForNewFile] fileType: kAudioFileAIFFType dataFormat: _fileFormatDesc error: &error];
				if (error) {
					NSLog(@"Could not set file path %@", error);
				} else {
					[_audioGraph patchBus: [recordingSource outputBusAtIndex: 0] into: [_fileRecorder inputBusAtIndex: 0]];
					[_audioGraph setHead: _fileRecorder];
					_hasFileName = YES;
				}
			}
		} else {
			// bypass the recorder -- do nothing
			[_fileRecorder flushAndClose];
			_hasFileName = NO;
		}
	[_audioGraph endPatching];
}

#pragma mark _____ Notifications
- (void)outputPatchChanged:(id)notification
{
	NSManagedObject* channel = [notification object];
	if ([channel valueForKey: @"patch"] == _outputPatch) {
		[self synchronizeOutputPatch];
	}
}

#pragma mark _____ ZKMRNZirkoniumUISystem
- (IBAction)studioSetup:(id)sender
{
	if (_isStudioSetupSupported) {
		if ([[_studioSetup windowControllers] count] < 1)
			[_studioSetup makeWindowControllers];
		[_studioSetup showWindows];	
	} else {
		NSDictionary* userInfo = 
			[NSDictionary 
				dictionaryWithObjectsAndKeys: 
					@"Studio Setup not supported in this version.", NSLocalizedDescriptionKey, nil];
		NSError* notSupportedError = [NSError errorWithDomain: ZKMRNErrorDomain code: -1 userInfo: userInfo];
		[[NSApplication sharedApplication] presentError: notSupportedError];
	}
}

- (IBAction)deviceSetup:(id)sender
{
//	ZKMRNDeviceDocument* deviceSetup = [_deviceManager deviceSetup];
	NSDocument* deviceSetup = (NSDocument *) [_deviceManager deviceSetup];
	if ([[deviceSetup windowControllers] count] < 1) {
		[deviceSetup makeWindowControllers];
		[[NSDocumentController sharedDocumentController] addDocument: deviceSetup];
	}
	[deviceSetup showWindows];
}

- (IBAction)showPreferences:(id)sender { [_preferencesController showWindow: nil]; }
- (IBAction)showAboutBox:(id)sender { [aboutPanel makeKeyAndOrderFront: sender]; }
- (IBAction)import:(id)sender { [[ZKMRNFileV1Importer sharedFileImporter] run]; }
- (IBAction)newDeviceSetup:(id)sender
{
	ZKMRNDeviceDocument* deviceSetup = 	[_deviceManager createNewDeviceSetup];
	[deviceSetup makeWindowControllers];
	[deviceSetup showWindows];
}

- (ZKMRNPieceDocument *)playingPiece { return _playingPiece; }
- (void)setPlayingPiece:(ZKMRNPieceDocument *)document
{
	if (_isPlaying) [self setPlaying: NO];
	if (_isTesting) [self setGraphTesting: NO];
	_playingPiece = document;
	[_audioGraph beginPatching];
		[_spatializationMixer uninitialize];
		[_audioGraph 
			patchBus: [[document pieceGraph] outputBusAtIndex: 0]  
			into: [_spatializationMixer inputBusAtIndex: 0]];
		[_audioGraph initialize];
	[_audioGraph endPatching];
	[_spatializationMixer setInputsAndOutputsOn];
}

- (ZKMRNDeviceManager *)deviceManager { return _deviceManager; }
- (unsigned)deviceNumberOfChannels { return [_deviceManager deviceNumberOfChannels]; }
- (void)setDeviceNumberOfChannels:(unsigned)deviceNumberOfChannels { [_deviceManager setDeviceNumberOfChannels: deviceNumberOfChannels]; }

- (unsigned)loggingLevel
{
	int isLogging = ZKMORLoggerIsLogging();
	if (!isLogging) return 0;
	unsigned logLevel = ZKMORLoggerGetLogLevel();
	if (logLevel <= kZKMORLogLevel_Error) return 1;
	if (logLevel <= kZKMORLogLevel_Warning) return 2;
	if (logLevel <= kZKMORLogLevel_Info) return 3;
	return 4;
}

- (void)setLoggingLevel:(unsigned)loggingLevel
{
	
	if (loggingLevel < 1) {
		ZKMORLoggerSetIsLogging(0);
		[_deviceManager setLogging: NO level: kZKMORLogLevel_Error];
		return;
	}
	if (!ZKMORLoggerIsLogging()) ZKMORLoggerSetIsLogging(1);
	
	unsigned logLevelUInt32;
	switch (loggingLevel) {
		case 1: logLevelUInt32 = kZKMORLogLevel_Error; break;
		case 2: logLevelUInt32 = kZKMORLogLevel_Warning; break;
		case 3: logLevelUInt32 = kZKMORLogLevel_Info; break;
		default: logLevelUInt32 = kZKMORLogLevel_Debug; break;
	}
	
	ZKMORLoggerSetLogLevel(logLevelUInt32);
	[_deviceManager setLogging: YES level: logLevelUInt32];
}

- (NSString *)playButtonTitle { return ([self isPlaying]) ? @"Stop" : @"Play"; }
- (NSString *)recordButtonTitle { return ([self isRecording]) ? @"Stop" : @"Rec"; }

#pragma mark _____ ZKMRNZirknoiumUISystemAudio
- (BOOL)isPlaying { return _isPlaying; }
- (void)setPlaying:(BOOL)isPlaying
{
	[self willChangeValueForKey: @"playButtonTitle"];
	_isPlaying = isPlaying;
	if (_isPlaying) {
		[_audioGraph start];
		[_deviceOutput start];
		[self createSpatializationTimer];
		[self createDisplayTimer];
	} else {
		[_deviceOutput stop];
		[_audioGraph stop];
		[self destroySpatializationTimer];		
		[self destroyDisplayTimer];
		if ([self isRecording]) [self cycleRecordFile];
	}
	[self didChangeValueForKey: @"playButtonTitle"];	
}

- (BOOL)isGraphTesting { return _isTesting; }
- (void)setGraphTesting:(BOOL)isGraphTesting
{
	if (_isPlaying) return;
	
	_isTesting = isGraphTesting;
	if (!_isTesting) {
		[_deviceOutput stop];
		[_audioGraph stop];
		[self destroyDisplayTimer];
		return;	
	}

		// update the mixer first
	[_audioGraph beginPatching];
		[_spatializationMixer uninitialize];
		[_audioGraph 
			patchBus: [[_preferencesController testGraph] outputBusAtIndex: 0]  
			into: [_spatializationMixer inputBusAtIndex: 0]];
		[_audioGraph initialize];
	[_audioGraph endPatching];
	[_spatializationMixer setInputsAndOutputsOn];
	
	[_panner beginEditingActiveSources];
		[_panner setNumberOfActiveSources: 1];
		[_panner setActiveSource: [_preferencesController testPannerSource] atIndex: 0];
	[_panner endEditingActiveSources];

	[_panner transferPanningToMixer];
			
	[_audioGraph start];
	[_deviceOutput start];
	[self createDisplayTimer];
}

- (BOOL)isRecording { return _isRecording; }
- (void)setRecording:(BOOL)isRecording
{
	if (isRecording == _isRecording) return;
	[self willChangeValueForKey: @"recordButtonTitle"];
	_isRecording = isRecording;
	[self synchronizeAudioGraph];
	[self didChangeValueForKey: @"recordButtonTitle"];	

}

#pragma mark _____ ZKMRNZirknoiumUISystemPrivate
- (void)createSpatializationTimer
{
	if (_spatializationTimer) [self destroySpatializationTimer];
	_spatializationTimer = [NSTimer timerWithTimeInterval: _spatializationTimerInterval target: self selector: @selector(spatTick:) userInfo: nil repeats: YES];
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
	if (_isTesting) return;
	
	[_scheduler task: _spatializationTimerInterval];
}

- (void)createDisplayTimer
{
	if (_displayTimer) [self destroyDisplayTimer];
	_displayTimer = [NSTimer timerWithTimeInterval: _displayTimerInterval target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	[_displayTimer retain];
	[[NSRunLoop currentRunLoop] addTimer: _displayTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _displayTimer forMode: NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer: _displayTimer forMode: NSEventTrackingRunLoopMode];
}

- (void)destroyDisplayTimer
{
	[_displayTimer invalidate];
	[_displayTimer release], _displayTimer = nil;
}

- (void)tick:(id)timer
{
	if (_isTesting) {
		[_preferencesController tick: timer];
	} else {
		[_playingPiece tick: timer];
	}
}

- (void)createLoggerTimer
{
	if (_loggerTimer) [self destroyLoggerTimer];
	_loggerTimer = [NSTimer timerWithTimeInterval: 1.0 target: self selector: @selector(logTick:) userInfo: nil repeats: YES];
	[_loggerTimer retain];
	[[NSRunLoop currentRunLoop] addTimer: _loggerTimer forMode: NSDefaultRunLoopMode];
}

- (void)destroyLoggerTimer
{
	[_loggerTimer invalidate];
	[_loggerTimer release], _loggerTimer = nil;
}

- (void)logTick:(id)timer
{
	[_loggerClient tick: timer];
}

- (NSString *)fileNameForNewFile
{
		// create a file name
	NSCalendarDate* date = [NSCalendarDate calendarDate];
	return [NSString stringWithFormat: @"%@/Desktop/%i%.2i%.2i-%.2i%.2i%.2i-Zirkonium.aif", 
			NSHomeDirectory(),
			[date yearOfCommonEra], [date monthOfYear], [date dayOfMonth], 
			[date hourOfDay], [date minuteOfHour], [date secondOfMinute]];
}

- (void)createRecordFile
{
	if (_isRecording) {
		[_audioGraph beginPatching];
			NSError* error = nil;
			[_fileRecorder setFilePath: [self fileNameForNewFile] fileType: kAudioFileAIFFType dataFormat: _fileFormatDesc error: &error];
			if (error) {
				NSLog(@"Could not set file path %@", error);
			} 
		[_audioGraph endPatching];
		_hasFileName = YES;
	}
}

- (void)flushAndCloseRecordFile
{
	[_fileRecorder flushAndClose];
	_hasFileName = NO;
}

- (void)cycleRecordFile
{
	[self flushAndCloseRecordFile];
	[self createRecordFile];
}


@end
