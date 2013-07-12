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
#import "ZKMORLoggerClient.h"
#import "ZKMRNTestSourceController.h"
#import "ZKMRNOutputPatchChannel.h"
#import "ZKMRNDirectOutPatchChannel.h"
#import "LightController.h"
#import "CoreDataWorkaround.h"

static NSString* const ZKMRNErrorDomain = @"ZKMRNErrorDomain";
ZKMRNZirkoniumSystem* gSharedZirkoniumSystem = nil;

static void print_stream_info (AudioStreamBasicDescription *stream)
{
	printf ("  mSampleRate = %f\n", stream->mSampleRate);
	printf ("  mFormatID = '%c%c%c%c'\n",
			(char) (stream->mFormatID >> 24) & 0xff,
			(char) (stream->mFormatID >> 16) & 0xff,
			(char) (stream->mFormatID >> 8) & 0xff,
			(char) (stream->mFormatID >> 0) & 0xff);
	
	printf ("  mFormatFlags: 0x%lx\n", stream->mFormatFlags);
	
#define doit(x) if (stream->mFormatFlags & x) { printf ("    " #x " (0x%x)\n", x); }
	doit (kAudioFormatFlagIsFloat);
	doit (kAudioFormatFlagIsBigEndian);
	doit (kAudioFormatFlagIsSignedInteger);
	doit (kAudioFormatFlagIsPacked);
	doit (kAudioFormatFlagIsAlignedHigh);
	doit (kAudioFormatFlagIsNonInterleaved);
	doit (kAudioFormatFlagsAreAllClear);
#undef doit
	
#define doit(x) printf ("  " #x " = %ld\n", stream->x)
	doit (mBytesPerPacket);
	doit (mFramesPerPacket);
	doit (mBytesPerFrame);
	doit (mChannelsPerFrame);
	doit (mBitsPerChannel);
#undef doit
}


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
@synthesize _recordingOutputFormat;

#pragma mark _____ NSObject Overrides
- (void)dealloc 
{
	gSharedZirkoniumSystem = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[_studioSetup release], _studioSetup = nil;
	[_spatializationMixer release], _spatializationMixer = nil;
	[_speakerLayoutSimulator release], _speakerLayoutSimulator = nil;
	[_deviceOutput release], _deviceOutput = nil;
	//[_virtualDeviceOutput release], _virtualDeviceOutput = nil; 
	[_panner unbind: @"speakerLayout"];
	[_panner release], _panner = nil;
	[_scheduler release], _scheduler = nil;
	//[_deviceManager release], _deviceManager = nil;
	if (_spatializationTimer) [self destroySpatializationTimer];
	if (_displayTimer) [self destroyDisplayTimer];
	if (_loggerTimer) [self destroyLoggerTimer];
    [super dealloc];
}

- (void)awakeFromNib
{
	// @David
	_recordingOutputFormat = nil;
	
	// this is obviously not thread safe, but doesn't need to be either -- at the time this method
	// is called, there is only one thread running.
	[NSMigrationManager addRelationshipMigrationMethodIfMissing];
	
	// global pointer set (also look for _system in PieceDocument Class)
	gSharedZirkoniumSystem = self;
	
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	//	ZKMORLogPrinterStart();
	_loggerClient = [ZKMORLoggerClient sharedLoggerClient];
	_isPlaying = NO;
	_isTesting = NO;
	
	//_masterGain = 1.f;
	_filePlayerNumberOfBuffers = 4;
	_filePlayerBufferSize = 4096;
	_sampleRateConverterQuality = kAudioConverterQuality_Min;
	_displayTimerInterval = 0.1;
	_spatializationTimerInterval = 0.025;
	
	_currentPieceDocument = nil;		
	
	// initialize the audio first
	//_virtualDeviceController = [[ZKMRNVirtualDeviceController alloc] init];
	
	_deviceOutput = [[ZKMORDeviceOutput alloc] init];
	_audioGraph = [[ZKMORGraph alloc] init];
	[_deviceOutput setGraph: _audioGraph];
	// give ownership to the device output
	[_audioGraph release];
	
	
	_speakerLayoutSimulator	= [[ZKMNRSpeakerLayoutSimulator alloc] init];
	_loudspeakerMode = kZKMRNSystemLoudspeakerMode_Virtual;
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
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputPatchChanged:) name: ZKMRNOutputPatchChangedNotification object: nil];
	
	_isStudioSetupSupported = YES;
	[self initializeStudioSetup];
	
	if(!_lightController)
		_lightController = [[LightController alloc] initWithZirkoniumSystem: self];	
	
	_isRecording = NO;
	_hasFileName = NO;
	_fileRecorder = [[ZKMORAudioFileRecorder alloc] init];
	
	[self createLoggerTimer];
	
	_preferencesController = [[ZKMRNPreferencesController alloc] initWithZirkoniumSystem: self];
	
	_testSourceController = [[ZKMRNTestSourceController alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(oscSenderDidTogglePlay:) name: @"OSCSenderToggledPlayNotification" object:nil]; 
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(oscSenderDidMoveToStart:) name: @"OSCSenderMoveToStartNotification" object:nil]; 
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

- (ZKMRNOutputPatch *)outputPatch { return (_outputPatch!=nil && [[_outputPatch valueForKey:@"isApplicable"] boolValue]) ? _outputPatch : nil; }
- (void)setOutputPatch:(ZKMRNOutputPatch *)outputPatch
{
	if (_outputPatch != outputPatch) {
		if (_outputPatch) [_outputPatch release];
		_outputPatch = outputPatch; 
		if (_outputPatch) [_outputPatch retain];
		[self synchronizeAudioGraph]; // ... calls "synchronizeOutputPatch"
	}
}

- (float)masterGain { return [[[NSUserDefaults standardUserDefaults] valueForKey:@"MasterGain"] floatValue]; }
- (void)setMasterGain:(float)masterGain
{
	float gain = MAX(0.0, MIN(1.0, masterGain));
	[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithFloat:gain] forKey: @"MasterGain"];
	
	[_deviceOutput setVolume: gain];
	//[_deviceManager setMasterGain: _masterGain];
	[_testSourceController synchronizeSpatializationMixerCrosspoints];
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
- (LightController *)lightController { return _lightController; }
- (ZKMORLoggerClient *)loggerClient { return _loggerClient; }


-(void)setCurrentPieceDocument:(ZKMRNPieceDocument*)currentPieceDocument{ _currentPieceDocument = currentPieceDocument; }
-(ZKMRNPieceDocument*)currentPieceDocument { 
	return _currentPieceDocument;  
}

-(NSTimeInterval)spatializationTimerInterval { return _spatializationTimerInterval; }


- (NSString *)zirkoniumVersionString
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"];
}


#pragma mark _____ Actions

-(void)panChannelAz:(NSDictionary*)arguments
{
	unsigned channel = [[arguments valueForKey:@"channel"] intValue];
	ZKMNRSphericalCoordinate center;
	center.azimuth = [[arguments valueForKey:@"azimuth"] floatValue];
	center.zenith = [[arguments valueForKey:@"zenith"] floatValue];
	ZKMNRSphericalCoordinateSpan span;
	span.azimuthSpan = [[arguments valueForKey:@"azimuthSpan"] floatValue];
	span.zenithSpan = [[arguments valueForKey:@"zenithSpan"] floatValue];
	float gain = [[arguments valueForKey:@"gain"] floatValue];
	
	[self panChannel:channel az:center span:span gain:gain];
}

-(void)panChannelXy:(NSDictionary*)arguments
{
	unsigned channel = [[arguments valueForKey:@"channel"] intValue];
	ZKMNRRectangularCoordinate center;
	center.x = [[arguments valueForKey:@"x"] floatValue];
	center.y = [[arguments valueForKey:@"y"] floatValue];
	ZKMNRRectangularCoordinateSpan span;
	span.xSpan = [[arguments valueForKey:@"xSpan"] floatValue];
	span.ySpan = [[arguments valueForKey:@"ySpan"] floatValue];
	float gain = [[arguments valueForKey:@"gain"] floatValue];
	
	[self panChannel:channel xy:center span:span gain:gain];
}

-(void)panChannelSpeakerAz:(NSDictionary*)arguments
{
	unsigned channel = [[arguments valueForKey:@"channel"] intValue];
	ZKMNRSphericalCoordinate center;
	center.azimuth = [[arguments valueForKey:@"azimuth"] floatValue];
	center.zenith = [[arguments valueForKey:@"zenith"] floatValue];
	float gain = [[arguments valueForKey:@"gain"] floatValue];
	
	[self panChannel:channel speakerAz:center gain:gain];
	
}

-(void)panChannelSpeakerXy:(NSDictionary*)arguments
{
	unsigned channel = [[arguments valueForKey:@"channel"] intValue];
	ZKMNRRectangularCoordinate center;
	center.x = [[arguments valueForKey:@"x"] floatValue];
	center.y = [[arguments valueForKey:@"y"] floatValue];
	float gain = [[arguments valueForKey:@"gain"] floatValue];
	
	[self panChannel:channel speakerXy:center gain:gain];
}

#pragma mark -

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

-(void)oscSenderDidTogglePlay:(NSNotification*)inNotification
{
	if([self playingPiece])
		[[self playingPiece] togglePlay:self];
	else {
		[[self currentPieceDocument] togglePlay:self]; 
	}
}

-(void)oscSenderDidMoveToStart:(NSNotification*)inNotification
{
	if([self playingPiece])
		[[self playingPiece] moveTransportToStart:self];
	else {
		[[self currentPieceDocument] moveTransportToStart:self]; 
	}
}



#pragma mark _____ ZKMRNZirkoniumSystemAudio
//- (ZKMRNVirtualDeviceController *)virtualDeviceController { return _virtualDeviceController; }
- (ZKMORDeviceOutput *)deviceOutput { return _deviceOutput; }
- (ZKMORDeviceInput *)deviceInput { return [_deviceOutput deviceInput]; /*[_deviceOutput deviceInput];*/ }
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
	[NSURL fileURLWithPath: [[self applicationSupportFolder] stringByAppendingPathComponent: @"studio2.zrkstu"]];
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
	NSString* defaultStudioPath = [[NSBundle mainBundle] pathForResource: @"defaultstudio" ofType: @"zrkstu"];
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
		NSNumber* sourceChannel = [inputChannel valueForKey: @"sourceChannel"];
		if(sourceChannel)
		{
			unsigned deviceInput = [sourceChannel unsignedIntValue] % count;
			unsigned zirkInput = [[inputChannel valueForKey: @"patchChannel"] unsignedIntValue];
			[channelMap replaceObjectAtIndex: zirkInput withObject: [NSNumber numberWithInt: deviceInput]];
		}
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
	
	
	if ([self outputPatch]) {
		// apply the output patch
		NSEnumerator* outputs = [[_outputPatch valueForKey: @"channels"] objectEnumerator];
		NSManagedObject* outputChannel;
		while (outputChannel = [outputs nextObject]) {
			//BOOL isDirectOut = [[outputChannel valueForKey: @"isDirectOut"] boolValue];
			NSNumber* sourceChannel = [outputChannel valueForKey: @"sourceChannel"];
			if(sourceChannel)
			{
				unsigned deviceOutput = [sourceChannel unsignedIntValue];
				unsigned zirkOutput   = [[outputChannel valueForKey: @"patchChannel"] unsignedIntValue];
				
				if (deviceOutput < count) [channelMap replaceObjectAtIndex: deviceOutput withObject: [NSNumber numberWithUnsignedInt:zirkOutput]];
			}
		}
	} else {
		// turn on all the speakers
		for (i = 0; i < MIN(numberOfSpeakers, count); i++) {
			[channelMap replaceObjectAtIndex: i withObject: [NSNumber numberWithInt: i]];
		}
	}
	
	
	if ([self outputPatch]) {
		// add the direct outs
		NSEnumerator* directOuts = [[_outputPatch valueForKey: @"directOutChannels"] objectEnumerator];
		NSManagedObject* directOutChannel;
		while (directOutChannel = [directOuts nextObject]) {
			NSNumber* sourceChannel = [directOutChannel valueForKey: @"sourceChannel"];
			if(sourceChannel)
			{
				unsigned deviceOutput = [sourceChannel unsignedIntValue];
				unsigned zirkOutput = numberOfSpeakers + [[directOutChannel valueForKey: @"patchChannel"] unsignedIntValue];
				if (deviceOutput < count) [channelMap replaceObjectAtIndex: deviceOutput withObject: [NSNumber numberWithInt: zirkOutput]];
			}
		}		
	}
	
	// TODO BASS OUT Add the bass outs
	
	
	[_deviceOutput setChannelMap: channelMap];
	
}

- (void)synchronizeAudioGraph
{
	unsigned numberOfSpeakers = [_speakerSetup numberOfSpeakers];
	if(numberOfSpeakers < 1) return;
	
	[_speakerLayoutSimulator setSpeakerLayout: [_speakerSetup speakerLayout]];
	[_speakerLayoutSimulator setSimulationMode: _loudspeakerSimulationMode];
	
	// TODO: Create ZKMRNZirkoniumSystem Graph
	// Graph should have a FileWriter at the end
	// ZKMRNPieceDocument >> spatializer >> simulator >> writer >> dac
	
	
	[_audioGraph beginPatching];
	
	
	if (kZKMRNSystemLoudspeakerMode_Real == _loudspeakerMode) {
		unsigned numberOfOutputChannels = numberOfSpeakers;
		
		//jens
		if([self outputPatch]) {
			numberOfOutputChannels+=[[_outputPatch valueForKey:@"numberOfDirectOuts"] intValue];
			numberOfOutputChannels += [_outputPatch numberOfBassOuts];
		}
		
		[_spatializationMixer uninitialize];
		[_spatializationMixer setNumberOfOutputBuses: 1];
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
	
	// @David
	[ZKMORAudioFileRecorder getAIFCInt24Format: &_fileFormatDesc channels: numberOfChannels];
	if (_recordingOutputFormat == @"AIFF 16 Bit")
		[ZKMORAudioFileRecorder getAIFFInt16Format: &_fileFormatDesc channels: numberOfChannels];
	if (_recordingOutputFormat == @"AIFC 24 Bit (uncompressed)")
		[ZKMORAudioFileRecorder getAIFCInt24Format: &_fileFormatDesc channels: numberOfChannels];
//	if (_recordingOutputFormat == @"AIFC 32 Bit (uncompressed)")
//		[ZKMORAudioFileRecorder getAIFCFloat32Format: &_fileFormatDesc channels: numberOfChannels];
//	if (_recordingOutputFormat == @"WAVE 16 Bit")
//		[ZKMORAudioFileRecorder getAIFCInt24Format: &_fileFormatDesc channels: numberOfChannels];
	
	[_audioGraph beginPatching];
	if ([self isRecording]) {
		
		[_fileRecorder uninitialize];
		[[_fileRecorder outputBusAtIndex: 0] setNumberOfChannels: numberOfChannels];
		[[_fileRecorder inputBusAtIndex: 0] setNumberOfChannels: numberOfChannels];
		if (!_hasFileName) {
			
			NSString* filename = [self fileNameForNewFile];
			
			if(filename) {
				
				NSError* error = nil;
				[_fileRecorder setFilePath:filename  fileType: kAudioFileAIFFType dataFormat: _fileFormatDesc error: &error];
				if (error) {
					NSLog(@"Could not set file path %@", error);
				} else {
					[_audioGraph patchBus: [recordingSource outputBusAtIndex: 0] into: [_fileRecorder inputBusAtIndex: 0]];
					[_audioGraph setHead: _fileRecorder];
					_hasFileName = YES;
					
					[[self playingPiece] toggleRecordButton:YES]; 
					
				}
				
			} else {
				_isRecording = NO; 
			}	
		}
		
	} else {
		// bypass the recorder -- do nothing
		
		NSString* recordingURL = nil; 
		if(![[self playingPiece] hasProcessedRecording]) {
			recordingURL = [[_fileRecorder fileURL] path]; 
		}
		
		[_fileRecorder flushAndClose];
		
		if(![[self playingPiece] hasProcessedRecording]) {
			[[NSFileManager defaultManager] removeFileAtPath:recordingURL handler:nil]; 
		}
		
		
		[[self playingPiece] toggleRecordButton:NO]; 
		_hasFileName = NO;
		[[self playingPiece] setHasProcessedRecording:NO]; 
	}
	[_audioGraph endPatching];
}

#pragma mark -


#pragma mark _____ Notifications
- (void)outputPatchChanged:(id)notification
{
	// ... synchronize
	[self synchronizeAudioGraph]; // ... calls "synchronizeOutputPatch"
}


#pragma mark _____ ZKMRNZirkoniumUISystem
- (IBAction)studioSetup:(id)sender
{
	if (_isStudioSetupSupported) {
		
		if(![_studioSetup windowIsActive])
		{
			NSWindowController* aWindowController = [[NSWindowController alloc] initWithWindowNibName:[_studioSetup windowNibName] owner:_studioSetup];
			[_studioSetup addWindowController:aWindowController];
			[aWindowController release];
		}
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

- (IBAction)enterFullscreenVisualizer:(id)sender
{
	if([self playingPiece]) {
		[[self playingPiece] activateVisualizer:self]; 
	} else {
		[[self currentPieceDocument] activateVisualizer:self];
	}
}

- (IBAction)exitFullscreenVisualizer: (id)sender
{
	if([self playingPiece]) {
		[[self playingPiece] deactivateVisualizer:self];
	} else {
		[[self currentPieceDocument] deactivateVisualizer:self];
	}
}


- (IBAction)showPreferences:(id)sender { [_preferencesController showWindow: nil]; }
- (IBAction)showAboutBox:(id)sender { [aboutPanel makeKeyAndOrderFront: sender]; }

- (ZKMRNPieceDocument *)playingPiece { 
	
	if(_playingPiece) {
		return _playingPiece; 
	} else {
		return [self currentPieceDocument];
	}
	
	return nil; 
}
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

//- (ZKMRNDeviceManager *)deviceManager { return _deviceManager; }
//- (unsigned)deviceNumberOfChannels { return [_deviceManager deviceNumberOfChannels]; }
//- (void)setDeviceNumberOfChannels:(unsigned)deviceNumberOfChannels { [_deviceManager setDeviceNumberOfChannels: deviceNumberOfChannels]; }

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
		//[_deviceManager setLogging: NO level: kZKMORLogLevel_Error];
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
	//[_deviceManager setLogging: YES level: logLevelUInt32];
}

- (NSString *)playButtonTitle { return ([self isPlaying]) ? @"Stop" : @"Play"; }
- (NSString *)recordButtonTitle { return ([self isRecording]) ? @"Stop" : @"Rec"; }

#pragma mark _____ ZKMRNZirknoiumUISystemAudio
- (BOOL)isPlaying { return _isPlaying; }
- (void)setPlaying:(BOOL)isPlaying
{
	[self willChangeValueForKey: @"playButtonTitle"];
	if(isPlaying) {
		[[ZKMRNTestSourceController sharedTestSourceController] setIsTestingInPresets:NO];
		[[ZKMRNTestSourceController sharedTestSourceController] setIsTestingInPreferences:NO]; 
		[[ZKMRNTestSourceController sharedTestSourceController] setGraphTesting:NO]; 
	}
	_isPlaying = isPlaying;
	if (_isPlaying) {
		//
		[_audioGraph start];
		[_deviceOutput start];
		//[[self virtualDeviceController] startDevice];
		
		[self createSpatializationTimer];
		[self createDisplayTimer];
		//[_masterSlaveController postOSCPlay];
		[[_preferencesController oscController] postOSCStop:NO];
		[[_preferencesController oscController] postOSCStart:YES];
		
	} else {
		
		[_deviceOutput stop];
		[_audioGraph stop];
		//[[self virtualDeviceController] stopDevice];
		[self destroySpatializationTimer];		
		[self destroyDisplayTimer];
		//[_masterSlaveController postOSCStop];
		[[_preferencesController oscController] postOSCStart:NO];
		[[_preferencesController oscController] postOSCStop:YES]; 
		if ([self isRecording]) {
			[self cycleRecordFile];
			[[self playingPiece] toggleRecord:self]; 
		}
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
	
	[self synchronizeAudioGraph];
	[self synchronizeOutputPatch];
	
	[_audioGraph beginPatching];
	[_spatializationMixer uninitialize];
	[_audioGraph 
	 patchBus: [[_testSourceController testGraph] outputBusAtIndex: 0]  
	 into: [_spatializationMixer inputBusAtIndex: 0]];
	[_audioGraph initialize];
	[_audioGraph endPatching];
	[_spatializationMixer setInputsAndOutputsOn];
	
	[_panner beginEditingActiveSources];
	[_panner setNumberOfActiveSources: 1];
	[_panner setActiveSource: [_testSourceController testPannerSource] atIndex: 0];
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
	//[self willChangeValueForKey: @"recordButtonTitle"];
	_isRecording = isRecording;
	[self synchronizeAudioGraph];
	//[self didChangeValueForKey: @"recordButtonTitle"];	
	
}

#pragma mark _____ ZKMRNZirknoiumUISystemPrivate


- (void)createSpatializationTimer
{
	if (_spatializationTimer) [self destroySpatializationTimer];
	
	// Note: working with Multi-threading here is probably not a good idea, since accessing core data objects from multiple threads is particularly difficult and dangerous 
	_spatializationTimer = [NSTimer timerWithTimeInterval: _spatializationTimerInterval target: self selector: @selector(spatTick:) userInfo: nil repeats: YES];
	[[NSRunLoop mainRunLoop] addTimer:_spatializationTimer forMode:NSDefaultRunLoopMode]; 
	[[NSRunLoop mainRunLoop] addTimer:_spatializationTimer forMode:NSEventTrackingRunLoopMode]; // Changed by JB possibly Side Effects?
	[_spatializationTimer retain];
	
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
	
	// Note: working with Multi-threading here is probably not a goog idea, since accessing core data objects from multiple threads is particularly difficult and dangerous 
	_displayTimer = [NSTimer timerWithTimeInterval: _displayTimerInterval target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	
	[[NSRunLoop mainRunLoop] addTimer: _displayTimer forMode: NSDefaultRunLoopMode];
	[[NSRunLoop mainRunLoop] addTimer: _displayTimer forMode: NSEventTrackingRunLoopMode];
	
	[_displayTimer retain];
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
	
	NSString* filename = [NSString stringWithFormat: @"%i%.2i%.2i_%.2i%.2i%.2i_Zirkonium", [date yearOfCommonEra], [date monthOfYear], [date dayOfMonth], [date hourOfDay], [date minuteOfHour], [date secondOfMinute]];
	
	NSSavePanel* savePanel = [NSSavePanel savePanel]; 
	NSString* path = @"~/";
	[savePanel setTitle:@"Select Recording Destination ..."];
	[savePanel setDirectory:[path stringByExpandingTildeInPath]];
	[savePanel setPrompt:NSLocalizedString(@"Save",nil)];
	[savePanel setRequiredFileType:@"aif"];
	if(NSOKButton == [savePanel runModalForDirectory:path file:filename])
		return [savePanel filename];
	
	return nil; 
	
}

- (void)createRecordFile
{
	/*
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
	 */
}

- (void)flushAndCloseRecordFile
{
	[_fileRecorder flushAndClose];
	_hasFileName = NO;
}

- (void)cycleRecordFile
{
	[self flushAndCloseRecordFile];
	//[self createRecordFile]; //JB (don't create a new file, just cancel recording)
}



@end
