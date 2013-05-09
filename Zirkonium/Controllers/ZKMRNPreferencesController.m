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
#import "ZKMRNTestSourceController.h"
#import "ZKMRNLightTableView.h"
#import "LightController.h"
@interface ZKMRNPreferencesController (ZKMRNPreferencesControllerPrivate)

- (void)setPreferencesToDefaultValues;
- (void)synchronizeSpatializationMixerCrosspoints;

@end


@implementation ZKMRNPreferencesController
#pragma mark _____ NSWindowController Overrides
- (void)awakeFromNib
{
	// configure recording output button
	[recordingOutputButton removeAllItems];
	[recordingOutputButton addItemWithTitle:@"AIFF 16 Bit"];
	[recordingOutputButton addItemWithTitle:@"AIFC 24 Bit (uncompressed)"];
//	[recordingOutputButton addItemWithTitle:@"AIFC 32 Bit (uncompressed)"];
//	[recordingOutputButton addItemWithTitle:@"WAVE 16 Bit"];
	[recordingOutputButton selectItem:[recordingOutputButton itemAtIndex:1]];
	
	domeView.isPositionIdeal = YES;
	[domeView bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[domeView setViewType:kDomeView3DPreviewType];
	
	[spatializerView bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[spatializerView setViewType:kDomeView2DPreviewType]; 
	
	[[_zirkoniumSystem loggerClient] setTextView: logTextView];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(devicesChangedNotification:) name: ZKMORAudioHardwareDevicesChangedNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputDeviceWillDisappear:) name: ZKMORDeviceOutputDeviceWillDisappearNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(outputDeviceDidDisappear:) name: ZKMORDeviceOutputDeviceDidDisappearNotification object: nil];
	
	[redView setInitialIndex: 0];
	[redView setLightController: [_zirkoniumSystem lightController]];
	[greenView setInitialIndex: 1];
	[greenView setLightController: [_zirkoniumSystem lightController]];
	[blueView setInitialIndex: 2];
	[blueView setLightController: [_zirkoniumSystem lightController]];
	[gradientView setLightController: [_zirkoniumSystem lightController]];

	// Hook Up Light Array Controller ...
	[[_zirkoniumSystem lightController] setLightTablesArrayController:lightTablesController]; 

	if(testSourceController)
		[spatializerView setPannerSources: [NSArray arrayWithObject: [testSourceController testPannerSource]]];
	else 
		NSLog(@"No Test Panner Source");
	[[self window] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
	
	[self updateOSCController];
	
	
	
	[[self managedObjectContext] processPendingChanges]; 
	[[[_zirkoniumSystem studioSetupDocument] undoManager] removeAllActions]; 
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if(_oscController)	
		[_oscController release]; 
	[super dealloc];
}

// @David
- (IBAction)recordingOutputButtonChanged:(id)sender
{
	NSMenuItem * selectedFormat = [recordingOutputButton selectedItem];
	[_zirkoniumSystem set_recordingOutputFormat:[selectedFormat title]];
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

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return @"Preferences";
}

#pragma mark _____ Initialization
- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)system
{	
	if (!(self = [super initWithWindowNibName: @"ZKMRNPreferences"])) return nil;
	
	[self initializeDefaults]; 
	
	_zirkoniumSystem = system;
	_audioHardwareSystem = [ZKMORAudioHardwareSystem sharedAudioHardwareSystem];
	
	// default preferences on the system
	[self setPreferencesToDefaultValues];
	
	_senderCount = 0;
	if(_oscController)
		[_oscController release];
	_oscController = [[OSCController alloc] init];
	
	[[self managedObjectContext] processPendingChanges]; 
	[[[_zirkoniumSystem studioSetupDocument] undoManager] removeAllActions]; 

	
	// Trick to load NIB and instanciate all Outlets ... 
	[self window]; 
	[self close];
	
	return self;
}

-(void)initializeDefaults
{	
	NSUserDefaultsController* defaultsController = [NSUserDefaultsController sharedUserDefaultsController];
	
	NSNumber* yes	= [NSNumber numberWithBool:YES];
	NSNumber* no	= [NSNumber numberWithBool:NO];
	
	NSDictionary* initialValues = [NSDictionary dictionaryWithObjectsAndKeys: 
		no,  @"showCoordinateSystem",
		yes, @"showSpeakerMesh",
		yes, @"showIDNumbers",
		yes, @"showIDVolumes", 
		yes, @"showSpeakersNumbering",
		[NSNumber numberWithInt:0], @"speakersNumberingMode",
		nil];
		
	[defaultsController setInitialValues:initialValues]; 
}


#pragma mark _____ UI Accessors

-(IBAction)actionEnableTesting:(id)sender
{
	[testSourceController bindToOutputController:outputMapSpeakersController isTestingPanner:YES];  //bind
	[testSourceController setIsTestingInPresets:NO];												//state
	[testSourceController setIsTestingInPreferences:(BOOL)[sender state]];
	
	[testSourceController setGraphTesting:(BOOL)[sender state]];									//audio	
}

-(OSCController*)oscController { return _oscController; }

- (float)fontSize { return 11.f; }
- (ZKMRNZirkoniumSystem *)zirkoniumSystem { return _zirkoniumSystem; }
- (NSManagedObjectContext *)managedObjectContext { return [[_zirkoniumSystem studioSetupDocument] managedObjectContext]; }

#pragma mark - Audio Devices 

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

#pragma mark - Speakers and Rooms

- (ZKMRNSpeakerSetup *)speakerSetup { return [_zirkoniumSystem speakerSetup]; }
- (void)setSpeakerSetup:(ZKMRNSpeakerSetup *)speakerSetup 
{ 
	ZKMRNSpeakerSetup* prevSpeakerSetup = [self speakerSetup];
	[prevSpeakerSetup willChangeValueForKey:@"isPreferenceSelected"];
	[speakerSetup willChangeValueForKey:@"isPreferenceSelected"];

	[_zirkoniumSystem setSpeakerSetup: speakerSetup]; 
	[[NSUserDefaults standardUserDefaults] setObject: [speakerSetup valueForKey: @"name"] forKey: @"SpeakerSetup"];
	
	[prevSpeakerSetup didChangeValueForKey:@"isPreferenceSelected"];
	[speakerSetup didChangeValueForKey:@"isPreferenceSelected"];}

- (NSManagedObject *)room { return [_zirkoniumSystem room]; }
- (void)setRoom:(NSManagedObject *)room 
{ 
	[_zirkoniumSystem setRoom: room]; 
	[[NSUserDefaults standardUserDefaults] setObject: [room valueForKey: @"name"] forKey: @"Room"];
}

#pragma mark - Patches

- (ZKMRNInputPatch *)inputPatch { return [_zirkoniumSystem inputPatch]; }
- (void)setInputPatch:(ZKMRNInputPatch *)inputPatch 
{ 
	ZKMRNInputPatch* prevInputPatch = [self inputPatch];
	[prevInputPatch willChangeValueForKey:@"isPreferenceSelected"];
	[inputPatch willChangeValueForKey:@"isPreferenceSelected"];
	
	[_zirkoniumSystem setInputPatch: inputPatch];
	if (inputPatch) {
		[[NSUserDefaults standardUserDefaults] setObject: [inputPatch valueForKey: @"name"] forKey: @"InputPatch"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"InputPatch"];
	}
	
	[prevInputPatch didChangeValueForKey:@"isPreferenceSelected"];
	[inputPatch didChangeValueForKey:@"isPreferenceSelected"];

}

- (ZKMRNOutputPatch *)outputPatch { return [_zirkoniumSystem outputPatch]; }
- (void)setOutputPatch:(ZKMRNOutputPatch *)outputPatch 
{ 
	ZKMRNOutputPatch* prevOutputPatch = [self outputPatch];
	[prevOutputPatch willChangeValueForKey:@"isPreferenceSelected"];
	[outputPatch willChangeValueForKey:@"isPreferenceSelected"];

	ZKMRNOutputPatch* newOutputPatch = ([[outputPatch valueForKey:@"isApplicable"] boolValue]) ? outputPatch : nil;
	
	[_zirkoniumSystem setOutputPatch: newOutputPatch];
	if (newOutputPatch) {
		[[NSUserDefaults standardUserDefaults] setObject: [outputPatch valueForKey: @"name"] forKey: @"OutputPatch"];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"OutputPatch"];
	}
	
	[prevOutputPatch didChangeValueForKey:@"isPreferenceSelected"];
	[outputPatch didChangeValueForKey:@"isPreferenceSelected"];

}

-(NSArrayController*)outputPatches { return outputPatches; }

#pragma mark - Master Gain

- (NSNumber*)masterGain { return [[NSUserDefaults standardUserDefaults] valueForKey:@"MasterGain"]; }

- (void)setMasterGain:(NSNumber*)masterGain
{
	float gain = MAX(0.0, MIN(1.0, [masterGain floatValue])); 

	[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithFloat:gain] forKey: @"MasterGain"];
	
	[_zirkoniumSystem setMasterGain:gain];
}

#pragma mark - Buffer Sizes

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

#pragma mark - Loudspeaker Mode

- (int)loudspeakerMode { return [_zirkoniumSystem loudspeakerMode]; }
- (void)setLoudspeakerMode:(unsigned)loudspeakerMode
{
	[self willChangeValueForKey: @"loudspeakerMode"];
	[_zirkoniumSystem setLoudspeakerMode: loudspeakerMode];
	[self didChangeValueForKey: @"loudspeakerMode"];
	
	[[NSUserDefaults standardUserDefaults] setInteger: loudspeakerMode forKey: @"LoudspeakerMode"];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];
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

#pragma mark - Speaker Mesh

//- (BOOL)isShowingSpeakerMesh { return [spatializerView isShowingMesh]; }
//- (void)setShowingSpeakerMesh:(BOOL)isShowingSpeakerMesh { [spatializerView setShowingMesh: isShowingSpeakerMesh]; }

#pragma mark - Logs

- (int)loggingLevel { return [_zirkoniumSystem loggingLevel]; }
- (void)setLoggingLevel:(int)loggingLevel 
{ 
	[self willChangeValueForKey: @"loggingLevel"];
	[_zirkoniumSystem setLoggingLevel: loggingLevel];
	[self didChangeValueForKey: @"loggingLevel"];
}
- (NSAttributedString *)logText { return [[_zirkoniumSystem loggerClient] logText]; }



- (NSArray *)speakerSetupSortDescriptors 
{ 
	NSSortDescriptor* sortDesc = [[NSSortDescriptor alloc] initWithKey: @"name" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: sortDesc];
	[sortDesc release];
	return descriptors;
}

- (void)setSpeakerSetupSortDescriptors:(NSArray *)speakerSetupSortDescriptors { }  // Ignore

#pragma mark -
#pragma mark - OpenGL View Options (JB)
#pragma mark -

/*
- (BOOL)showSpeakersNumbering
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSNumber* value = [userDefaults objectForKey:@"ShowSpeakersNumbering"];
	_showSpeakersNumbering = (nil!=value) ? [value boolValue] : YES;
	return _showSpeakersNumbering;
}

- (void)setShowSpeakersNumbering:(bool)showSpeakersNumbering
{
	_showSpeakersNumbering = showSpeakersNumbering;
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: [NSNumber numberWithBool:_showSpeakersNumbering] forKey: @"ShowSpeakersNumbering"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];
}

- (int)speakersNumberingMode
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSNumber* value = [userDefaults objectForKey:@"SpeakersNumberingMode"];
	_speakersNumberingMode = (nil!=value) ? [value intValue] : 0;
	return _speakersNumberingMode;
}
- (void)setSpeakersNumberingMode:(int)speakersNumberingMode
{
	_speakersNumberingMode = speakersNumberingMode;
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: [NSNumber numberWithInt:_speakersNumberingMode] forKey: @"SpeakersNumberingMode"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];
}
*/

#pragma mark - OSC (JB)

- (NSManagedObject *)oscConfiguration
{
	return [[_zirkoniumSystem studioSetupDocument] oscConfiguration]; 
}

- (NSManagedObject *)oscReceiver
{
	return [[_zirkoniumSystem studioSetupDocument] oscReceiver]; 
}

#pragma mark _____ UI Actions

- (IBAction)openStudioEditor:(id)sender
{
	[_zirkoniumSystem studioSetup:self];
}

- (IBAction)configureAudioOutputDevice:(id)sender 
{ 
	NSError* error = nil;
	BOOL didSucceed = [[self audioOutputDevice] launchConfigurationApplicationWithError: &error]; 
	if (!didSucceed) [self presentError: error]; 
}

#pragma mark - Log

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

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// do nothing
}

#pragma mark - OSC (JB)

-(void)updateOSCController
{	
	// ... halt the timers ...
	[_oscController stopOscSendTimer];	
	[_oscController setEnableReceive:[[[self oscConfiguration] valueForKey:@"enableReceive"] boolValue]];
	
	[_oscController configureInput:[[self oscReceiver] valueForKey:@"port"]];
	[_oscController configureOutputs:_oscSenderArrayController];
	
	// ... and restart the timers ...
	[_oscController updateTimers];
}


-(IBAction)actionIntervalChange:(id)sender
{	  
	[_oscController updateTimers]; 
}

-(IBAction)actionEnableChange:(id)sender
{
	BOOL enableReceive = [[[self oscConfiguration] valueForKey:@"enableReceive"] boolValue]; 
	[_oscController setEnableReceive:enableReceive];
	[_oscController updateTimers];
}

-(IBAction)actionInPortChange:(id)sender
{
	//validate ...
	if([sender intValue] < 1024) {
		[[self oscReceiver] willChangeValueForKey:@"port"];
		[[self oscReceiver] setValue:[NSNumber numberWithInt:2001] forKey:@"port"];
		[[self oscReceiver] didChangeValueForKey:@"port"];
	}
	
	[self updateOSCController];	
}

-(IBAction)actionOutPortChange:(id)sender
{
	//validate ...
	if([sender intValue] < 1024) {
		id senderSelection = [_oscSenderArrayController selection];
		[senderSelection willChangeValueForKey:@"port"];
		[senderSelection setValue:[NSNumber numberWithInt:1024] forKey:@"port"];
		[senderSelection didChangeValueForKey:@"port"];
	}
	
	[self updateOSCController];
}

-(IBAction)actionAddressChange:(id)sender
{
	//validate ...
	NSString* newAddress = [sender stringValue];
	NSArray* ipSplit = [newAddress componentsSeparatedByString:@"."]; 
	BOOL isValid = true; 
	if(	[ipSplit count] != 4) isValid = false; 
	NSString* component; 
	int value;
	for(component in ipSplit)
		if(![[NSScanner scannerWithString:component] scanInt:&value]) isValid = false; 

	if(!isValid) {
		id senderSelection = [_oscSenderArrayController selection];
		[senderSelection willChangeValueForKey:@"address"];
		[senderSelection setValue:@"127.0.0.1" forKey:@"address"];
		[senderSelection didChangeValueForKey:@"address"];
	}
	
	[self updateOSCController];
}

-(IBAction)actionAddSender:(id)sender
{
	[_oscSenderArrayController add:self];
}

-(IBAction)actionRemoveSender:(id)sender
{
	[_oscSenderArrayController remove:self];
}

#pragma mark -
#pragma mark Light
#pragma mark -

/*
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
*/

- (IBAction)revertLightTable:(id)sender
{
	// Load from User Defaults ...
	[[_zirkoniumSystem lightController] selectionChanged]; 
	
	[redView setNeedsDisplay: YES];
	[greenView setNeedsDisplay: YES];
	[blueView setNeedsDisplay: YES];
	[gradientView setNeedsDisplay: YES];
	
	/*
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
	*/
}

- (IBAction)saveLightTable:(id)sender
{
	LightController* lightController = [_zirkoniumSystem lightController]; 

	NSArray* selectedObjects = [lightTablesController selectedObjects];

	if (!selectedObjects || [selectedObjects count] < 1) 
		return;
		
	NSDictionary* selectedLightTable = [selectedObjects objectAtIndex:0];
	
	NSData* data = [lightController uiSelectedLightTableData];
	[selectedLightTable setValue:data forKey:ZKMRNLightControllerTableDataKey]; 

	//Save to User Defaults ...
	[[NSUserDefaultsController sharedUserDefaultsController] setValue:[lightTablesController arrangedObjects] forKeyPath:@"values.lightTables"]; 

	if([[selectedLightTable valueForKey:ZKMRNLightControllerTableSelectionKey] boolValue]) {
		[self loadLightTable:self];
	}

	/*
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	ZKMRNLightController* lightController = [_zirkoniumSystem lightController];
	[lightController saveLightTable];
	[userDefaults setObject: [lightController lightTables] forKey: @"LightTableList"];
	[userDefaults setObject: [lightController lightTableName] forKey: @"DefaultLightTable"];
	*/
}

/*
- (IBAction)defaultLightTable:(id)sender
{

	[[_zirkoniumSystem lightController] setDBLightTableToDefault];
	[redView setNeedsDisplay: YES];
	[greenView setNeedsDisplay: YES];
	[blueView setNeedsDisplay: YES];
	[gradientView setNeedsDisplay: YES];

}
*/

- (IBAction)addLightTable:(id)sender
{
	LightController* lightController = [_zirkoniumSystem lightController]; 
	
	NSData* defaultLightTableData = [lightController defaultLightTableData];
	
	NSString* defaultName = @"New Light Preset"; 
	
	NSDictionary* newLightTable = [NSDictionary dictionaryWithObjectsAndKeys:
												defaultName, ZKMRNLightControllerTableNameKey, 
												defaultLightTableData, ZKMRNLightControllerTableDataKey,
												[NSNumber numberWithBool:NO], ZKMRNLightControllerTableSelectionKey,
												nil];
	
	NSArray* lightTables = [[NSUserDefaults standardUserDefaults] valueForKey:@"lightTables"];
	[[NSUserDefaults standardUserDefaults] setValue:[lightTables arrayByAddingObject:newLightTable] forKey:@"lightTables"]; 
	
	/*
	ZKMRNLightController* lightController = [_zirkoniumSystem lightController];
	NSDictionary* tableDict = 
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"New Light Table", ZKMRNLightControllerTableNameKey,
			[lightController dbLightTableData], ZKMRNLightControllerTableDataKey, nil];
	
	NSIndexSet* indices = [NSIndexSet indexSetWithIndex: [[lightController lightTables] count]];
	[lightController willChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];
		[[lightController lightTables] addObject: tableDict];
	[lightController didChange: NSKeyValueChangeInsertion valuesAtIndexes: indices forKey: @"lightTables"];
	*/
}

- (IBAction)removeLightTable:(id)sender
{
	NSUInteger selectionIndex = [lightTablesController selectionIndex];

	if (NSNotFound==selectionIndex) 
		return;
		
	NSDictionary* selectedLightTable = [[lightTablesController arrangedObjects] objectAtIndex:selectionIndex];
	
	if([[selectedLightTable valueForKey:ZKMRNLightControllerTableSelectionKey] boolValue]) {
		
		// Currently Active ...
		NSAlert* alert = [NSAlert alertWithMessageText: nil defaultButton: nil alternateButton: nil otherButton: nil informativeTextWithFormat: @"Cannot delete active light setting."];
		[alert setAlertStyle: NSInformationalAlertStyle];
		[alert runModal];
	} else {
		
		// Not Active ...
		NSMutableArray* lightTables = [NSMutableArray arrayWithArray:[lightTablesController arrangedObjects]]; 
		[lightTables removeObjectAtIndex:selectionIndex]; 
		
		[[NSUserDefaults standardUserDefaults] setValue:[NSArray arrayWithArray:lightTables] forKey:@"lightTables"]; 
	}
	
	/*
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
	
	[self willChangeValueForKey:@"zirkoniumSystem"];
	[lightController removeLightTable: lightTableName];

		// save the information
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: [lightController lightTables] forKey: @"LightTableList"];
	[userDefaults setObject: [lightController lightTableName] forKey: @"DefaultLightTable"];
	
	[self didChangeValueForKey:@"zirkoniumSystem"];
	*/
}

-(IBAction)actionEnteredLightTableName:(id)sender
{
	// Save to User Defaults ...
	//NSLog(@"Save to User Defaults ");
	//NSArray* lightTables = [lightTablesController arrangedObjects];
	//[[NSUserDefaultsController sharedUserDefaultsController] setValue:lightTables forKeyPath:@"values.lightTables"]; 
	
	[self saveLightTable:self];
}

- (IBAction)loadLightTable:(id)sender
{
	NSDictionary* selectedLightTable = [[lightTablesController selectedObjects] objectAtIndex:0]; 
	if(selectedLightTable) {
		for(NSDictionary* aLightTable in [lightTablesController arrangedObjects]) {
			[aLightTable setValue:[NSNumber numberWithBool:NO] forKey:ZKMRNLightControllerTableSelectionKey];
		}
		
		[selectedLightTable setValue:[NSNumber numberWithBool:YES] forKey:ZKMRNLightControllerTableSelectionKey];
		
		//Save to User Defaults ...
		[[NSUserDefaultsController sharedUserDefaultsController] setValue:[lightTablesController arrangedObjects] forKeyPath:@"values.lightTables"]; 

		[[_zirkoniumSystem lightController] activeChanged];
	}
	
	/*
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
	*/
	
}



- (IBAction)allLightsOff:(id)sender
{
	
	LightController* lightController = [_zirkoniumSystem lightController];
	[lightController sendAllLightsOff];
}

#pragma mark _____ ZKMRNPreferencesControllerPrivate
- (void)setPreferencesToDefaultValues
{
	
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	
	//Device ...
	NSString* defaultDevice = [userDefaults stringForKey: @"Device"];
	if (nil == defaultDevice) {
		ZKMORAudioDevice* audioDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] defaultOutputDevice];
		defaultDevice = [audioDevice UID];
		[userDefaults setObject: defaultDevice forKey: @"Device"];
	} else {
		ZKMORAudioDevice* audioDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] audioDeviceForUID: defaultDevice];
		if (audioDevice) [self setAudioOutputDevice: audioDevice];
	}
	
	// Speaker Setup ...
	NSString* defaultSpeakerSetup = [userDefaults stringForKey: @"SpeakerSetup"];
	if (nil == defaultSpeakerSetup) {
		defaultSpeakerSetup = @"Octophonic";
		[userDefaults setObject: defaultSpeakerSetup forKey: @"SpeakerSetup"];
	}
	[_zirkoniumSystem setSpeakerSetup: [[_zirkoniumSystem studioSetupDocument] speakerSetupWithName: defaultSpeakerSetup]];
	
	// Room ...
	NSString* defaultRoom = [userDefaults stringForKey: @"Room"];
	if (nil == defaultRoom) {
		defaultRoom = @"Kubus";
		[userDefaults setObject: defaultRoom forKey: @"Room"];
	} else
	[_zirkoniumSystem setRoom: [[_zirkoniumSystem studioSetupDocument] roomWithName: defaultRoom]];
	
		
	// Patches ...
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
	
	// Loudspeaker Mode ... 
	// kZKMRNSystemLoudspeakerMode_Real or kZKMRNSystemLoudspeakerMode_Virtual	...
	int defaultLoudspeakerMode = [userDefaults integerForKey: @"LoudspeakerMode"];
	[_zirkoniumSystem setLoudspeakerMode: defaultLoudspeakerMode]; 
	// kZKMNRSpeakerLayoutSimulationMode_Headphones or kZKMNRSpeakerLayoutSimulationMode_5Dot0	...
	int defaultLoudspeakerSimulationMode = [userDefaults integerForKey: @"LoudspeakerSimulationMode"];
	[_zirkoniumSystem setLoudspeakerSimulationMode: defaultLoudspeakerSimulationMode];
	
	// Master Gain ...
	if(![userDefaults floatForKey: @"MasterGain"]) {
		[userDefaults setFloat:0.25 forKey: @"MasterGain"];
	}
		
	// Buffers ...
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
	
	// Light ...
	
	// set the interval *before* setting sending lighting
	/*
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
	*/
}


-(NSPredicate*) applicableOutputPatchesPredicate
{
	return [NSPredicate predicateWithFormat:@"isApplicable == YES"];
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

#pragma mark _____ NSTableViewDelegate OSC (JB)

-(void)tableViewSelectionDidChange:(NSNotification*)notification
{
	NSTableView* sender = (NSTableView*)[notification object];

	if([sender isEqualTo:oscTableView]) {
		//NSLog(@"OSC Table View Selection Did Change");
		if(_senderCount != [[_oscSenderArrayController arrangedObjects] count]) {
			_senderCount = [[_oscSenderArrayController arrangedObjects] count];
			[self updateOSCController];
		}
	}
	
	if([sender isEqualTo:lightTableView]) {
		//NSLog(@"Light Table View Selection Did Change");
		[[_zirkoniumSystem lightController] selectionChanged]; 
		
		[redView setNeedsDisplay:YES];
		[greenView setNeedsDisplay:YES];
		[blueView setNeedsDisplay:YES];
		[gradientView setNeedsDisplay:YES];
	}
}

#pragma mark _____ NSTabViewDelegate
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem { return YES; }

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem { }

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem { }

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView { }

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
	[[preferencesController outputPatches] rearrangeObjects];
}

@end

