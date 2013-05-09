//
//  ZKMRNPreferencesController.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNPreferencesController.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNStudioSetupDocument.h"
#import "ZKMRNDomeView.h"
#import "ZKMRNSpatializerView.h"
#import "ZKMRNSpeaker.h"
#import "ZKMRNSimpleMap.h"
#import "ZKMRNOutputPatch.h"
#import "ZKMRNOutputPatchChannel.h"
#import "ZKMRNLightTableView.h"
#import "ZKMRNLightController.h"
#import "ZKMRNDeviceManager.h"
#import "ZKMRNDeviceDocument.h"

@interface ZKMRNPreferencesController (ZKMRNPreferencesControllerPrivate)

- (void)setPreferencesToDefaultValues;
- (void)synchronizeSpatializationMixerCrosspoints;
- (NSMutableArray *)cleanDeviceDocumentPathList:(NSArray *)devicePathList;

@end


@implementation ZKMRNPreferencesController
#pragma mark _____ NSWindowController Overrides
- (void)awakeFromNib
{
	[domeView setPositionIdeal: YES];
	[domeView bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[outputMapDomeView setDelegate: self];
	[outputMapDomeView bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[spatializerView bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[spatializerView setPannerSources: [NSArray arrayWithObject: _testPannerSource]];
	[self bind: @"testSourceOutputs" toObject: outputMapSpeakersController withKeyPath: @"selectionIndexes" options: nil];
	[[_zirkoniumSystem loggerClient] setTextView: logTextView];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(devicesChangedNotification:) name: ZKMORAudioHardwareDevicesChangedNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputDeviceWillDisappear:) name: ZKMORDeviceOutputDeviceWillDisappearNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputDeviceDidDisappear:) name: ZKMORDeviceOutputDeviceDidDisappearNotification object: nil];
	
	if (!_showLightTab) {
		[[lightTab tabView] removeTabViewItem: lightTab];
	} else {
		[redView setInitialIndex: 0];
		[redView setLightController: [_zirkoniumSystem lightController]];
		[greenView setInitialIndex: 1];
		[greenView setLightController: [_zirkoniumSystem lightController]];
		[blueView setInitialIndex: 2];
		[blueView setLightController: [_zirkoniumSystem lightController]];
		[gradientView setLightController: [_zirkoniumSystem lightController]];
	}
	
	[[self window] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[_testGraph release];
		// the test panner source will automically unregister itself
	[_testPannerSource release];
	[super dealloc];
}

- (IBAction)showWindow:(id)sender
{
	[super showWindow: sender];
	ZKMRNStudioSetupDocument* document = [_zirkoniumSystem studioSetupDocument];
	if (![[document windowControllers] containsObject: self]) [document addWindowController: self];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	return [[_zirkoniumSystem studioSetupDocument] undoManager];
}

#pragma mark _____ Initialization
- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)system
{
	if (!(self = [super initWithWindowNibName: @"ZKMRNPreferences"])) return nil;
	
	_zirkoniumSystem = system;
	_audioHardwareSystem = [ZKMORAudioHardwareSystem sharedAudioHardwareSystem];
		// default to pink noise
	_testSourceIndex = 0;
	_testSourceVolume = 0.25;
	_testGraph = [[ZKMORGraph alloc] init];
	_testPannerSource = [[ZKMNRPannerSource alloc] init];
	[[_zirkoniumSystem panner] registerPannerSource: _testPannerSource];
	
	// set up test graph
	AudioStreamBasicDescription streamFormat;
	ZKMORPinkNoise*		pinkNoise = [[ZKMORPinkNoise alloc] init];
	ZKMORWhiteNoise* 	whiteNoise = [[ZKMORWhiteNoise alloc] init];
	_testMixer = [[ZKMORMixerMatrix alloc] init];
		// set up the conduits
	[_testMixer setNumberOfInputBuses: 2];
	[_testMixer setNumberOfOutputBuses: 1];
	[_testGraph setPurposeString: @"Graph for test tones"];
	[_testMixer setPurposeString: @"Mixer for test tones"];

	streamFormat = [[pinkNoise outputBusAtIndex: 0] streamFormat];
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[pinkNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[whiteNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_testMixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_testMixer inputBusAtIndex: 1] setStreamFormat: streamFormat];
		// just send out a mono output, either pink or white noise
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[_testMixer outputBusAtIndex: 0] setStreamFormat: streamFormat];

	[_testGraph beginPatching];
		[_testGraph setHead: _testMixer];
		[_testGraph patchBus: [pinkNoise outputBusAtIndex: 0] into: [_testMixer inputBusAtIndex: 0]];
		[_testGraph patchBus: [whiteNoise outputBusAtIndex: 0] into: [_testMixer inputBusAtIndex: 1]];
		[_testGraph initialize];
	[_testGraph endPatching];
	[pinkNoise release]; [whiteNoise release]; [_testMixer release];
	[self setTestSourceIndex: 0];

	// default preferences on the system
	[self setPreferencesToDefaultValues];
		
	return self;
}

#pragma mark _____ UI Accessors
- (float)fontSize { return 11.f; }
- (ZKMORAudioHardwareSystem *)audioHardwareSystem { return _audioHardwareSystem; }
- (NSArray *)audioOutputDevices { return [_audioHardwareSystem outputDevices]; }
- (ZKMORAudioDevice *)audioOutputDevice { return [_zirkoniumSystem audioOutputDevice]; }
- (void)setAudioOutputDevice:(ZKMORAudioDevice *)audioOutputDevice 
{ 
	[self willChangeValueForKey: @"filePlayerBufferDuration"];
	[_zirkoniumSystem setAudioOutputDevice: audioOutputDevice];
	[self didChangeValueForKey: @"filePlayerBufferDuration"];
	
	[[NSUserDefaults standardUserDefaults] setObject: [audioOutputDevice UID] forKey: @"Device"];
}

- (ZKMRNSpeakerSetup *)speakerSetup { return [_zirkoniumSystem speakerSetup]; }
- (void)setSpeakerSetup:(ZKMRNSpeakerSetup *)speakerSetup 
{ 
	[_zirkoniumSystem setSpeakerSetup: speakerSetup]; 
	[[NSUserDefaults standardUserDefaults] setObject: [speakerSetup valueForKey: @"name"] forKey: @"SpeakerSetup"];
}

- (NSManagedObject *)room { return [_zirkoniumSystem room]; }
- (void)setRoom:(NSManagedObject *)room 
{ 
	[_zirkoniumSystem setRoom: room]; 
	[[NSUserDefaults standardUserDefaults] setObject: [room valueForKey: @"name"] forKey: @"Room"];
}

- (ZKMRNInputPatch *)inputPatch { return [_zirkoniumSystem inputPatch]; }
- (void)setInputPatch:(ZKMRNInputPatch *)inputPatch 
{ 
	[_zirkoniumSystem setInputPatch: inputPatch];
	if (inputPatch) {
		[[NSUserDefaults standardUserDefaults] setObject: [inputPatch valueForKey: @"name"] forKey: @"InputPatch"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"InputPatch"];
	}
}

- (ZKMRNOutputPatch *)outputPatch { return [_zirkoniumSystem outputPatch]; }
- (void)setOutputPatch:(ZKMRNOutputPatch *)outputPatch 
{ 
	[_zirkoniumSystem setOutputPatch: outputPatch];
	if (outputPatch) {
		[[NSUserDefaults standardUserDefaults] setObject: [outputPatch valueForKey: @"name"] forKey: @"OutputPatch"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"OutputPatch"];
	}
}

- (ZKMRNDirectOutPatch *)directOutPatch { return [_zirkoniumSystem directOutPatch]; }
- (void)setDirectOutPatch:(ZKMRNDirectOutPatch *)directOutPatch
{
	[_zirkoniumSystem setDirectOutPatch: directOutPatch];
	if (directOutPatch) {
		[[NSUserDefaults standardUserDefaults] setObject: [directOutPatch valueForKey: @"name"] forKey: @"DirectOutPatch"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"DirectOutPatch"];
	}
}

- (float)masterGain { return [_zirkoniumSystem masterGain]; }
- (void)setMasterGain:(float)masterGain
{
	[_zirkoniumSystem setMasterGain: masterGain];
	[[NSUserDefaults standardUserDefaults] setFloat: masterGain forKey: @"MasterGain"];
}

- (int)filePlayerNumberOfBuffers { return [_zirkoniumSystem filePlayerNumberOfBuffers]; }
- (void)setFilePlayerNumberOfBuffers:(int)filePlayerNumberOfBuffers 
{
	[self willChangeValueForKey: @"filePlayerBufferDuration"];
	[_zirkoniumSystem setFilePlayerNumberOfBuffers: filePlayerNumberOfBuffers]; 
	[self didChangeValueForKey: @"filePlayerBufferDuration"];
	[[NSUserDefaults standardUserDefaults] setInteger: filePlayerNumberOfBuffers forKey: @"FilePlayerNumberOfBuffers"];
}

- (int)filePlayerBufferSize { return [_zirkoniumSystem filePlayerBufferSize]; }
- (void)setFilePlayerBufferSize:(int)filePlayerBufferSize 
{
	[self willChangeValueForKey: @"filePlayerBufferDuration"];
	[_zirkoniumSystem setFilePlayerBufferSize: filePlayerBufferSize];
	[self didChangeValueForKey: @"filePlayerBufferDuration"];
	
	[[NSUserDefaults standardUserDefaults] setInteger: filePlayerBufferSize forKey: @"FilePlayerBufferSize"];
}

- (int)sampleRateConverterQuality { return [_zirkoniumSystem sampleRateConverterQualityUI]; }
- (void)setSampleRateConverterQuality:(int)sampleRateConverterQuality
{
	[_zirkoniumSystem setSampleRateConverterQualityUI: sampleRateConverterQuality];
	NSLog(@"Set SampleRateConverterQuality %u", sampleRateConverterQuality);
	[[NSUserDefaults standardUserDefaults] setInteger: sampleRateConverterQuality forKey: @"SampleRateConverterQuality"];
}

- (int)filePlayerBufferDuration
{
	return (unsigned) ([self filePlayerNumberOfBuffers] * [self filePlayerBufferSize] * 1000.f / [[_zirkoniumSystem audioOutputDevice] nominalSampleRate]);
}

- (NSTimeInterval)displayTimerInterval { return [_zirkoniumSystem displayTimerInterval]; }
- (void)setDisplayTimerInterval:(NSTimeInterval)displayTimerInterval
{
	[_zirkoniumSystem setDisplayTimerInterval: displayTimerInterval];
	[[NSUserDefaults standardUserDefaults] setFloat: displayTimerInterval forKey: @"DisplayTimerInterval"];
}

- (int)loudspeakerMode { return [_zirkoniumSystem loudspeakerMode]; }
- (void)setLoudspeakerMode:(unsigned)loudspeakerMode
{
	[self willChangeValueForKey: @"loudspeakerMode"];
	[_zirkoniumSystem setLoudspeakerMode: loudspeakerMode];
	[self didChangeValueForKey: @"loudspeakerMode"];
	
	[[NSUserDefaults standardUserDefaults] setInteger: loudspeakerMode forKey: @"LoudspeakerMode"];
}

- (void)setLoudspeakerModeTemporary:(unsigned)loudspeakerMode
{
	[self willChangeValueForKey: @"loudspeakerMode"];
	[_zirkoniumSystem setLoudspeakerMode: loudspeakerMode];
	[self didChangeValueForKey: @"loudspeakerMode"];
}

- (unsigned)loudspeakerSimulationMode { return [_zirkoniumSystem loudspeakerSimulationMode]; }
- (void)setLoudspeakerSimulationMode:(unsigned)loudspeakerSimulationMode
{
	[self willChangeValueForKey: @"loudspeakerSimulationMode"];
	[_zirkoniumSystem setLoudspeakerSimulationMode: loudspeakerSimulationMode];
	[self didChangeValueForKey: @"loudspeakerSimulationMode"];
	
	[[NSUserDefaults standardUserDefaults] setInteger: loudspeakerSimulationMode forKey: @"LoudspeakerSimulationMode"];
}

- (BOOL)isSendingLighting { return [[_zirkoniumSystem lightController] isSendingLighting]; }
- (void)setSendingLighting:(BOOL)isSendingLighting
{
	[self willChangeValueForKey: @"sendingLighting"];
	[[_zirkoniumSystem lightController] setSendingLighting: isSendingLighting];
	[self didChangeValueForKey: @"sendingLighting"];
	
	[[NSUserDefaults standardUserDefaults] setBool: isSendingLighting forKey: @"IsSendingLighting"];
}

- (NSTimeInterval)lightTimerInterval { return [[_zirkoniumSystem lightController] lightTimerInterval]; }
- (void)setLightTimerInterval:(NSTimeInterval)lightTimerInterval
{
	[self willChangeValueForKey: @"lightTimerInterval"];
	[[_zirkoniumSystem lightController] setLightTimerInterval: lightTimerInterval];
	[self didChangeValueForKey: @"lightTimerInterval"];
	
	[[NSUserDefaults standardUserDefaults] setFloat: lightTimerInterval forKey: @"LightTimerInterval"];
}

- (float)lightGain { return [[_zirkoniumSystem lightController] lightGain]; }
- (void)setLightGain:(float)lightGain
{
	[self willChangeValueForKey: @"lightGain"];
	[[_zirkoniumSystem lightController] setLightGain: lightGain];
	[self didChangeValueForKey: @"lightGain"];
	
	[[NSUserDefaults standardUserDefaults] setFloat: lightGain forKey: @"LightGain"];
}


- (BOOL)isShowingSpeakerMesh { return [spatializerView isShowingMesh]; }
- (void)setShowingSpeakerMesh:(BOOL)isShowingSpeakerMesh { [spatializerView setShowingMesh: isShowingSpeakerMesh]; }

- (int)loggingLevel { return [_zirkoniumSystem loggingLevel]; }
- (void)setLoggingLevel:(int)loggingLevel 
{ 
	[self willChangeValueForKey: @"loggingLevel"];
	[_zirkoniumSystem setLoggingLevel: loggingLevel];
	[self didChangeValueForKey: @"loggingLevel"];
}
//- (NSAttributedString *)logText { return [[_zirkoniumSystem loggerClient] logText]; }

- (ZKMRNZirkoniumSystem *)zirkoniumSystem { return _zirkoniumSystem; }
- (NSManagedObjectContext *)managedObjectContext { return [[_zirkoniumSystem studioSetupDocument] managedObjectContext]; }

- (NSArray *)speakerSetupSortDescriptors 
{ 
	NSSortDescriptor* sortDesc = [[NSSortDescriptor alloc] initWithKey: @"name" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: sortDesc];
	[sortDesc release];
	return descriptors;
}

- (void)setSpeakerSetupSortDescriptors:(NSArray *)speakerSetupSortDescriptors { }  // Ignore

- (ZKMRNDeviceManager *)deviceManager { return [_zirkoniumSystem deviceManager]; }


- (NSMutableArray *)deviceDocumentPaths { return _deviceDocumentPaths; }
- (void)setDeviceDocumentPaths:(NSArray *)deviceDocumentPaths
{
	if (_deviceDocumentPaths) [_deviceDocumentPaths release];
	_deviceDocumentPaths = [self cleanDeviceDocumentPathList: deviceDocumentPaths];
	
	NSMutableArray* paths = [[NSMutableArray alloc] init];
	unsigned i, count = [_deviceDocumentPaths count];
	for (i = 0; i < count; i++) {
		[paths addObject: [[_deviceDocumentPaths objectAtIndex: i] path]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: paths forKey: @"DeviceDocumentPaths"];
	[paths release];
}

- (void)initializeDeviceDocumentPaths
{
	NSArray* paths = [[NSUserDefaults standardUserDefaults] arrayForKey: @"DeviceDocumentPaths"];
	NSMutableArray* deviceDocumentPaths = [[NSMutableArray alloc] init];
	unsigned i, count = [paths count];
	
	BOOL includesDefaultPath = NO;
	NSString* defaultDeviceSetupPath = [[_zirkoniumSystem deviceManager] defaultDeviceSetupPath];
	
	for (i = 0; i < count; i++) {
		ZKMRNDeviceDocumentPath* ddPath = [[ZKMRNDeviceDocumentPath alloc] initWithPath: [paths objectAtIndex: i] controller: self];
		[deviceDocumentPaths addObject: ddPath];
		[ddPath release];
		
		if ([defaultDeviceSetupPath isEqualToString: [ddPath path]]) {
			includesDefaultPath = YES;
			[ddPath setDefault: YES];
		}
	}

	if (!includesDefaultPath) {
		ZKMRNDeviceDocumentPath* ddPath = [[ZKMRNDeviceDocumentPath alloc] initWithPath: defaultDeviceSetupPath controller: self];
		[deviceDocumentPaths addObject: ddPath];
		[ddPath setDefault: YES];		
		[ddPath release];
	}
	
	[self setDeviceDocumentPaths: deviceDocumentPaths];
	[deviceDocumentPaths release];
}

#pragma mark _____ UI Actions
- (IBAction)configureAudioOutputDevice:(id)sender 
{ 
	NSError* error = nil;
	BOOL didSucceed = [[self audioOutputDevice] launchConfigurationApplicationWithError: &error]; 
	if (!didSucceed) [self presentError: error]; 
}

- (IBAction)clearLog:(id)sender
{
	NSRange range = NSMakeRange(0, [[logTextView textStorage] length]);
	[[logTextView textStorage] beginEditing];
	[[[logTextView textStorage] mutableString] replaceCharactersInRange: range withString: @""];
	[[logTextView textStorage] endEditing];
}

- (IBAction)refreshLog:(id)sender;
{
	NSRange range = NSMakeRange([[logTextView textStorage] length], 0);
	[logTextView scrollRangeToVisible: range];
}

- (IBAction)revertLightTable:(id)sender
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* defaultLightTable = [userDefaults objectForKey: @"DefaultLightTable"];
	if (nil != defaultLightTable) {
		[[_zirkoniumSystem lightController] loadLightTable: defaultLightTable];
			// the displays need to be told that the underlying table has changed
		[redView setNeedsDisplay: YES];
		[greenView setNeedsDisplay: YES];
		[blueView setNeedsDisplay: YES];
		[gradientView setNeedsDisplay: YES];
	}
}

- (IBAction)saveLightTable:(id)sender
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	ZKMRNLightController* lightController = [_zirkoniumSystem lightController];
	[lightController saveLightTable];
	[userDefaults setObject: [lightController lightTables] forKey: @"LightTableList"];
	[userDefaults setObject: [lightController lightTableName] forKey: @"DefaultLightTable"];
}

- (IBAction)defaultLightTable:(id)sender
{
	[[_zirkoniumSystem lightController] setDBLightTableToDefault];
	[redView setNeedsDisplay: YES];
	[greenView setNeedsDisplay: YES];
	[blueView setNeedsDisplay: YES];
	[gradientView setNeedsDisplay: YES];
}

- (IBAction)newLightTable:(id)sender
{
	ZKMRNLightController* lightController = [_zirkoniumSystem lightController];
	NSDictionary* tableDict = 
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"New Light Table", ZKMRNLightControllerTableNameKey,
			[lightController dbLightTableData], ZKMRNLightControllerTableDataKey, nil];
	
	NSIndexSet* indices = [NSIndexSet indexSetWithIndex: [[lightController lightTables] count]];
	[lightController willChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];
		[[lightController lightTables] addObject: tableDict];
	[lightController didChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];
}

- (IBAction)loadLightTable:(id)sender
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSArray* selectedObjects = [lightTablesController selectedObjects];
	if (!selectedObjects) return;
	if ([selectedObjects count] < 1) return;
	
	NSString* lightTableName = [[selectedObjects objectAtIndex: 0] valueForKey: ZKMRNLightControllerTableNameKey];
	[[_zirkoniumSystem lightController] loadLightTable: lightTableName];
	[userDefaults setObject: lightTableName forKey: @"DefaultLightTable"];
	[redView setNeedsDisplay: YES];
	[greenView setNeedsDisplay: YES];
	[blueView setNeedsDisplay: YES];
	[gradientView setNeedsDisplay: YES];
}

- (IBAction)deleteLightTable:(id)sender
{
	NSArray* selectedObjects = [lightTablesController selectedObjects];
	if (!selectedObjects) return;
	if ([selectedObjects count] < 1) return;
	
	ZKMRNLightController* lightController = [_zirkoniumSystem lightController];
	NSString* lightTableName = [[selectedObjects objectAtIndex: 0] valueForKey: ZKMRNLightControllerTableNameKey];
	if (!lightTableName) return;
	
	if ([lightTableName isEqualToString: [lightController lightTableName]]) {
		NSAlert* alert = [NSAlert alertWithMessageText: nil defaultButton: nil alternateButton: nil otherButton: nil informativeTextWithFormat: @"Cannot delete active light setting."];
		[alert setAlertStyle: NSInformationalAlertStyle];
		[alert runModal];
	}
	[lightController removeLightTable: lightTableName];


		// save the information
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: [lightController lightTables] forKey: @"LightTableList"];
	[userDefaults setObject: [lightController lightTableName] forKey: @"DefaultLightTable"];
}

- (IBAction)allLightsOff:(id)sender
{
	ZKMRNLightController* lightController = [_zirkoniumSystem lightController];
	[lightController sendAllLightsOff];
}

- (IBAction)addDeviceDocument:(id)sender
{
	NSAlert* alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle: @"OK"];
	[alert setMessageText: @"Drag and drop from the Finder to add a device document file to the list."];
	[alert setAlertStyle: NSWarningAlertStyle];
	[alert beginSheetModalForWindow: [self window] modalDelegate: self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo: NULL];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// do nothing
}

#pragma mark _____ Testing Accessors
- (ZKMORGraph *)testGraph { return _testGraph; }

- (unsigned)testSourceIndex { return _testSourceIndex; }
- (void)setTestSourceIndex:(unsigned)testSourceIndex 
{ 
	_testSourceIndex = testSourceIndex;
	[_testMixer setInputsAndOutputsOn];
	[_testMixer setMasterVolume: _testSourceVolume];
	[_testMixer setVolume: 1.f forCrosspointInput: _testSourceIndex output: 0];	
	[_testMixer setVolume: 0.f forCrosspointInput: (_testSourceIndex + 1) % 2 output: 0];
}

- (float)testSourceVolume { return _testSourceVolume; }

- (void)setTestSourceVolume:(float)testSourceVolume
{
	_testSourceVolume = testSourceVolume;
	[_testMixer setMasterVolume: _testSourceVolume];
}

- (NSIndexSet *)testSourceOutputs { return _testSourceOutputs; }
- (void)setTestSourceOutputs:(NSIndexSet *)testSourceOutputs
{
	if (testSourceOutputs == _testSourceOutputs) return;
	if (_testSourceOutputs) [_testSourceOutputs release];
	_testSourceOutputs = (testSourceOutputs) ? [testSourceOutputs retain] : nil;
	if ([self isGraphTesting]) [self synchronizeSpatializationMixerCrosspoints];
}

- (BOOL)isGraphTesting { return [_zirkoniumSystem isGraphTesting]; }
- (void)setGraphTesting:(BOOL)isGraphTesting
{
	[_zirkoniumSystem setGraphTesting: isGraphTesting];
	[self synchronizeSpatializationMixerCrosspoints];
}

- (ZKMNRPannerSource *)testPannerSource { return _testPannerSource; }

#pragma mark _____ ZKMRNPreferencesControllerPrivate
- (void)setPreferencesToDefaultValues
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* defaultDevice = [userDefaults stringForKey: @"Device"];
	if (nil == defaultDevice) {
		ZKMORAudioDevice* audioDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] defaultOutputDevice];
		defaultDevice = [audioDevice UID];
		[userDefaults setObject: defaultDevice forKey: @"Device"];
	} else {
		ZKMORAudioDevice* audioDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] audioDeviceForUID: defaultDevice];
		if (audioDevice) [self setAudioOutputDevice: audioDevice];
	}
	
	NSString* defaultSpeakerSetup = [userDefaults stringForKey: @"SpeakerSetup"];
	if (nil == defaultSpeakerSetup) {
		defaultSpeakerSetup = @"Octophonic";
		[userDefaults setObject: defaultSpeakerSetup forKey: @"SpeakerSetup"];
	}
	[_zirkoniumSystem setSpeakerSetup: [[_zirkoniumSystem studioSetupDocument] speakerSetupWithName: defaultSpeakerSetup]];
	
	NSString* defaultRoom = [userDefaults stringForKey: @"Room"];
	if (nil == defaultRoom) {
		defaultRoom = @"Kubus";
		[userDefaults setObject: defaultRoom forKey: @"Room"];
	} else
	[_zirkoniumSystem setRoom: [[_zirkoniumSystem studioSetupDocument] roomWithName: defaultRoom]];
	
		/// kZKMRNSystemLoudspeakerMode_Real or kZKMRNSystemLoudspeakerMode_Virtual	
	int defaultLoudspeakerMode = [userDefaults integerForKey: @"LoudspeakerMode"];
	[_zirkoniumSystem setLoudspeakerMode: defaultLoudspeakerMode];
		/// kZKMNRSpeakerLayoutSimulationMode_Headphones or kZKMNRSpeakerLayoutSimulationMode_5Dot0	
	int defaultLoudspeakerSimulationMode = [userDefaults integerForKey: @"LoudspeakerSimulationMode"];
	[_zirkoniumSystem setLoudspeakerSimulationMode: defaultLoudspeakerSimulationMode];
	
	NSString* defaultInputPatch = [userDefaults stringForKey: @"InputPatch"];
	if (nil == defaultInputPatch) {
		[_zirkoniumSystem setInputPatch: nil];
	} else {
		[_zirkoniumSystem setInputPatch: [[_zirkoniumSystem studioSetupDocument] inputPatchWithName: defaultInputPatch]];
	}
	
	NSString* defaultOutputPatch = [userDefaults stringForKey: @"OutputPatch"];
	if (nil == defaultOutputPatch) {
		[_zirkoniumSystem setOutputPatch: nil];
	} else {
		[_zirkoniumSystem setOutputPatch: [[_zirkoniumSystem studioSetupDocument] outputPatchWithName: defaultOutputPatch]];
	}
	
	NSString* defaultDirectOutPatch = [userDefaults stringForKey: @"DirectOutPatch"];
	if (nil == defaultOutputPatch) {

	} else {
		[_zirkoniumSystem setDirectOutPatch: [[_zirkoniumSystem studioSetupDocument] directOutPatchWithName: defaultDirectOutPatch]];
	}
	
	float masterGain = [userDefaults floatForKey: @"MasterGain"];
	if (0.f == masterGain) {
		masterGain = [_zirkoniumSystem masterGain];
		[userDefaults setFloat: masterGain forKey: @"MasterGain"];
	} else {
		[_zirkoniumSystem setMasterGain: masterGain];
	}
		
	int defaultFilePlayerNumberOfBuffers = [userDefaults integerForKey: @"FilePlayerNumberOfBuffers"];
	if (0 == defaultFilePlayerNumberOfBuffers) {
		defaultFilePlayerNumberOfBuffers = [_zirkoniumSystem filePlayerNumberOfBuffers];
		[userDefaults setInteger: defaultFilePlayerNumberOfBuffers forKey: @"FilePlayerNumberOfBuffers"];
	} else {
		[_zirkoniumSystem setFilePlayerNumberOfBuffers: defaultFilePlayerNumberOfBuffers];
	}
	
	int defaultFilePlayerBufferSize = [userDefaults integerForKey: @"FilePlayerBufferSize"];
	if (0 == defaultFilePlayerBufferSize) {
		defaultFilePlayerBufferSize = [_zirkoniumSystem filePlayerBufferSize];
		[userDefaults setInteger: defaultFilePlayerBufferSize forKey: @"FilePlayerBufferSize"];
	} else {
		[_zirkoniumSystem setFilePlayerBufferSize: defaultFilePlayerBufferSize];
	}
	
	int defaultSRCQuality = [userDefaults integerForKey: @"SampleRateConverterQuality"];
	if (0 == defaultSRCQuality) {
		defaultSRCQuality = [_zirkoniumSystem sampleRateConverterQualityUI];
		[userDefaults setInteger: defaultSRCQuality forKey: @"SampleRateConverterQuality"];
	} else {
		[_zirkoniumSystem setSampleRateConverterQualityUI: defaultSRCQuality];
	}
	
	float defaultDiplayTimerInterval = [userDefaults floatForKey: @"DisplayTimerInterval"];
	if (0.f == defaultDiplayTimerInterval) {
		defaultDiplayTimerInterval = [_zirkoniumSystem displayTimerInterval];
		[userDefaults setFloat: defaultDiplayTimerInterval forKey: @"DisplayTimerInterval"];
	} else {
		[_zirkoniumSystem setDisplayTimerInterval: defaultDiplayTimerInterval];
	}
	
		// set the interval *before* setting sending lighting
	float defaultLightTimerInterval = [userDefaults floatForKey: @"LightTimerInterval"];
	if (0.f == defaultLightTimerInterval) {
		defaultLightTimerInterval = [[_zirkoniumSystem lightController] lightTimerInterval];
		[userDefaults setFloat: defaultLightTimerInterval forKey: @"LightTimerInterval"];
	} else {
		[[_zirkoniumSystem lightController] setLightTimerInterval: defaultLightTimerInterval];
	}
	
	BOOL defaultSendingLighting = [userDefaults boolForKey: @"IsSendingLighting"];
	[[_zirkoniumSystem lightController] setSendingLighting: defaultSendingLighting];
	
	NSArray* savedLightTables = [userDefaults arrayForKey: @"LightTableList"];
	NSMutableArray* lightTables = [[_zirkoniumSystem lightController] lightTables];
	if (nil == savedLightTables) {
		NSData* defaultLightTable = [userDefaults dataForKey: @"LightTable"];
		if (!defaultLightTable) {
			defaultLightTable = [[_zirkoniumSystem lightController] dbLightTableData];
		}
		// Transfer the light table over to the new system			
		// create a new list and remove the object
		NSDictionary* tableDict = 
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Light Setting 1", ZKMRNLightControllerTableNameKey,
				defaultLightTable, ZKMRNLightControllerTableDataKey, nil];
		[lightTables addObject: tableDict];
		[userDefaults setObject: lightTables forKey: @"LightTableList"];
		[userDefaults setObject: @"Light Setting 1" forKey: @"DefaultLightTable"];
//		[userDefaults removeObjectForKey: @"LightTable"];
	} else {
		[lightTables addObjectsFromArray: savedLightTables];
	}
	[[_zirkoniumSystem lightController] loadLightTable: [userDefaults stringForKey:	@"DefaultLightTable"]];
	
	float defaultLightGain = [userDefaults floatForKey: @"LightGain"];
	if (0.f == defaultLightGain) {
		defaultLightGain = [[_zirkoniumSystem lightController] lightGain];
		[userDefaults setFloat: defaultLightGain forKey: @"LightGain"];
	} else {
		[[_zirkoniumSystem lightController] setLightGain: defaultLightGain];
	}
	
	[self initializeDeviceDocumentPaths];
	
	_showLightTab = [userDefaults boolForKey: @"LightEnabled"];
}

- (void)synchronizeSpatializationMixerCrosspoints
{
	if (![self isGraphTesting]) return;
	
	ZKMORMixerMatrix* mixer = [_zirkoniumSystem spatializationMixer];
	if (_isTestingPanner) {
		[_testPannerSource setSynchedWithMixer: NO];
		[[_zirkoniumSystem panner] transferPanningToMixer];
		return;
	}
		// turn off all crosspoints
	[mixer setCrosspointsToZero];
    unsigned currentIndex = [_testSourceOutputs firstIndex];
    while (currentIndex != NSNotFound) {
		// turn on the selected crosspoints
		[mixer setVolume: 1.f forCrosspointInput: 0 output: currentIndex];
        currentIndex = [_testSourceOutputs indexGreaterThanIndex: currentIndex];
    }
}

- (NSMutableArray *)cleanDeviceDocumentPathList:(NSArray *)devicePathList
{
	NSMutableArray* cleanPaths = [[NSMutableArray alloc] init];
	if (!devicePathList) return cleanPaths;
	unsigned i, count = [devicePathList count];
	NSFileManager* fileManager = [NSFileManager defaultManager];
	for (i = 0; i < count; i++) {
		ZKMRNDeviceDocumentPath* path = [devicePathList objectAtIndex: i];
		if ([fileManager fileExistsAtPath: [path path]])
			[cleanPaths addObject: path];
	}
	
	return cleanPaths;
}

#pragma mark _____ ZKMRNSpeakerSetupViewDelegate
- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition
{
	id speaker = [speakerPosition tag];
	NSEvent* currentEvent = [[NSApplication sharedApplication] currentEvent];
	NSArray* speakers = [NSArray arrayWithObject: speaker];
	if ([currentEvent modifierFlags] & NSShiftKeyMask)
		[outputMapSpeakersController addSelectedObjects: speakers];	
	else
		[outputMapSpeakersController setSelectedObjects: speakers];
}

#pragma mark _____ Display Update
- (void)tick:(id)timer
{
	if (_isTestingPanner) [spatializerView setNeedsDisplay: YES];
}

#pragma mark _____ NSTabViewDelegate
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem { return YES; }

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem { }

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	BOOL wasTestingPanner = _isTestingPanner;
		// only change the state if we go to a page that effects the panner
	if ([@"Panner" isEqualTo: [tabViewItem identifier]]) _isTestingPanner = YES;
	if ([@"Output" isEqualTo: [tabViewItem identifier]]) _isTestingPanner = NO;	
	if (_isTestingPanner != wasTestingPanner) [self synchronizeSpatializationMixerCrosspoints];
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{

}

#pragma mark _____ NSWindow Delegate 
- (void)windowWillClose:(NSNotification *)notification
{
	[[self window] unregisterDraggedTypes];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject: NSFilenamesPboardType]) {
		return NSDragOperationCopy;		
	}
	return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	return [[pboard types] containsObject: NSFilenamesPboardType];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	if (![[pboard types] containsObject: NSFilenamesPboardType]) return NO;
		// not targeting the device documents
	if (![@"DeviceDocumentsItem" isEqualTo: [[mainTabView selectedTabViewItem] identifier]]) return NO;

	NSMutableArray* deviceDocumentPaths = [self deviceDocumentPaths];
	NSArray* files = [pboard propertyListForType: NSFilenamesPboardType];
	unsigned i, filesCount = [files count];
	for (i = 0; i < filesCount; i++) {
		ZKMRNDeviceDocumentPath* ddPath = [[ZKMRNDeviceDocumentPath alloc] initWithPath: [files objectAtIndex: i] controller: self];
		[deviceDocumentPaths addObject: ddPath];
		[ddPath release];
	}
	
	[self setDeviceDocumentPaths: deviceDocumentPaths];
	
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{

}

#pragma mark _____ Notifications
- (void)devicesChangedNotification:(NSNotification *)notification
{
	// a device was added or removed. If a device was added, see if it was the preferred default device and, if so, use it.
	NSString* defaultDevice = [[NSUserDefaults standardUserDefaults] stringForKey: @"Device"];
	ZKMORAudioDevice* audioDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] audioDeviceForUID: defaultDevice];
	if (audioDevice && ([self audioOutputDevice] != audioDevice)) [self setAudioOutputDevice: audioDevice];
}

- (void)outputDeviceWillDisappear:(NSNotification *)notification
{
	[self willChangeValueForKey: @"audioOutputDevice"];
}

- (void)outputDeviceDidDisappear:(NSNotification *)notification
{
	[self didChangeValueForKey: @"audioOutputDevice"];
}

@end

@implementation ZKMRNOutputMapSpeakersController
#pragma mark _____ ZKMRNOutputMapSpeakersControllerPrivate
- (void)updateOutputChannelMenu
{
	NSPopUpButtonCell* cell = (NSPopUpButtonCell *)[[tableView tableColumnWithIdentifier: @"output"] dataCell];
	[cell removeAllItems];
	[cell addItemsWithTitles: [[[preferencesController zirkoniumSystem] audioOutputDevice] outputChannelNames]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString: @"outputPatch"]) {
		[tableView setNeedsDisplay: YES];
		return;
	}
	
	if ([keyPath isEqualToString: @"zirkoniumSystem.audioOutputDevice"]) {
		[self updateOutputChannelMenu];
		[tableView setNeedsDisplay: YES];
		return;
	}
}

#pragma mark _____ NSObject Overrides
- (void)awakeFromNib
{
	[super awakeFromNib];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputPatchChanged:) name: ZKMRNOutputPatchChangedNotification object: nil];
	[preferencesController addObserver: self forKeyPath: @"outputPatch" options: NSKeyValueObservingOptionNew context: NULL];
	[preferencesController addObserver: self forKeyPath: @"zirkoniumSystem.audioOutputDevice" options: NSKeyValueObservingOptionNew context: NULL];
	
	[self updateOutputChannelMenu];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[preferencesController removeObserver: self forKeyPath: @"outputPatch"];
	[preferencesController removeObserver: self forKeyPath: @"zirkoniumSystem.audioOutputDevice"];
	[super dealloc];
}

#pragma mark _____ NSTableDataSource
- (int)numberOfRowsInTableView:(NSTableView *)tableView { return [[self arrangedObjects] count]; }

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
		// other colums are populated using bindings
	if (![@"output" isEqual: [tableColumn identifier]]) return nil;
	
	// find out which element in the output map the speaker with the index "row" is connected to
	ZKMRNOutputPatch* outputPatch = [preferencesController outputPatch];
		
	ZKMNRSpeakerPosition* position = [[[self arrangedObjects] objectAtIndex: row] speakerPosition];
	int zirkChannel = [position layoutIndex];
	if (!outputPatch) return [NSNumber numberWithInt: zirkChannel];
	
	if (zirkChannel < 0) return [NSNumber numberWithInt: 0];
	NSEnumerator* channels = [[outputPatch valueForKey: @"channels"] objectEnumerator];
	NSManagedObject* channel;
	while (channel = [channels nextObject]) {
		if ([[channel valueForKey: @"patchChannel"] intValue] == zirkChannel)
			return [channel valueForKey: @"sourceChannel"];
	}
	
	return [NSNumber numberWithInt: 0];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
		// other colums are changed using bindings
	if (![@"output" isEqual: [tableColumn identifier]]) return;
	
	// find out which element in the output map the speaker with the index "row" is connected to
	ZKMRNOutputPatch* outputPatch = [preferencesController outputPatch];
	if (!outputPatch) return;
			
	ZKMNRSpeakerPosition* position = [[[self arrangedObjects] objectAtIndex: row] speakerPosition];
	int zirkChannel = [position layoutIndex];
	if (zirkChannel < 0) return;
	
	NSEnumerator* channels = [[outputPatch valueForKey: @"channels"] objectEnumerator];
	NSManagedObject* channel;
	while (channel = [channels nextObject]) {
		if ([[channel valueForKey: @"patchChannel"] intValue] == zirkChannel) {
			[channel setValue: object forKey: @"sourceChannel"];
		}
	}
}

#pragma mark _____ Notifications
- (void)outputPatchChanged:(id)sender
{
	[tableView setNeedsDisplay: YES];
}

@end

@implementation ZKMRNDeviceDocumentPath

- (void)dealloc
{
	if (_path) [_path release];
	[super dealloc];
}

- (id)initWithPath:(NSString *)path controller:(ZKMRNPreferencesController *)controller
{
	if (!(self = [super init])) return nil;
	_path = path;
	[_path retain];
	_isDefault = NO;
	_controller = controller;
	
	return self;
}
- (NSString *)path { return _path; }
- (BOOL)isDefault { return _isDefault; }
- (void)setDefault:(BOOL)isDefault 
{ 
	_isDefault = isDefault;

	if (!_isDefault) return;
	NSEnumerator* paths = [[_controller deviceDocumentPaths] objectEnumerator];
	ZKMRNDeviceDocumentPath* path;
	while (path = [paths nextObject]) {
		if (path != self) [path setDefault: NO];
	}
	
	NSFileManager* fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath: _path]) {
		ZKMRNDeviceDocument* deviceSetup;
		NSError* error = nil;		
		deviceSetup = [[ZKMRNDeviceDocument alloc] initWithContentsOfURL: [NSURL fileURLWithPath: _path] ofType: @"Device" error: &error];
		if (!error)
			[[_controller deviceManager] setDeviceSetup: deviceSetup];
		else 
			[_controller presentError: error];
		[deviceSetup release];
	} else {
		[[_controller deviceManager] createDeviceDocumentURL: [NSURL fileURLWithPath: _path]];
	}
}

@end
