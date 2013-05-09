//
//  ZKMRNPreferencesController.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import "OSCController.h"

@class ZKMRNZirkoniumSystem, ZKMRNInputPatch, ZKMRNOutputPatch; //ZKMRNDirectOutPatch;
@class ZKMRNSpeakerSetup, ZKMRNSpeakerSetupView;
@class ZKMRNSpatializerView, ZKMRNDomeView;
//@class ZKMRNDeviceManager;
@class ZKMRNLightTableView; 
@class ZKMRNGradientView;
@class ZKMRNTestSourceController;


@interface ZKMRNPreferencesController : NSWindowController <ZKMRNDomeViewDelegate> {
	IBOutlet NSPopUpButton * recordingOutputButton;
	
	IBOutlet ZKMRNSpeakerSetupView*		domeView;
	//IBOutlet ZKMRNSpeakerSetupView*		outputMapDomeView;
	IBOutlet ZKMRNSpatializerView*		spatializerView;
	IBOutlet NSArrayController*			outputMapSpeakersController;
	IBOutlet NSArrayController*			outputPatches; 
	IBOutlet NSTextView*				logTextView;
	IBOutlet NSTabView*					mainTabView;
	IBOutlet NSTabViewItem*				lightTab;
	
	IBOutlet NSTableView*				oscTableView; 
	IBOutlet NSTableView*				lightTableView; 
	
	IBOutlet ZKMRNLightTableView*		redView;
	IBOutlet ZKMRNLightTableView*		greenView;
	IBOutlet ZKMRNLightTableView*		blueView;
	IBOutlet ZKMRNGradientView*			gradientView;
	
	IBOutlet NSArrayController*			lightTablesController;
	
	IBOutlet ZKMRNTestSourceController*  testSourceController;
	
	
	//ZKMORGraph*					_testGraph;
	//ZKMNRPannerSource*			_testPannerSource;
	/*
	ZKMORMixerMatrix*			_testMixer;
		/// test sources: 0 == pink noise, 1 == white noise
	unsigned					_testSourceIndex;
	float						_testSourceVolume;
	NSIndexSet*					_testSourceOutputs;
	*/
	BOOL						_isTestingPanner;
	
	
	ZKMRNZirkoniumSystem*		_zirkoniumSystem;
	ZKMORAudioHardwareSystem*	_audioHardwareSystem;
	NSPredicate*				_speakersPredicate;
	//BOOL						_showLightTab;
	
	//NSMutableArray*				_deviceDocumentPaths;
	
	bool _showSpeakersNumbering;
	int  _speakersNumberingMode;
	
	// OSC (JB) ...
	IBOutlet NSTableView*		 _oscSenderTableView; 
	
	IBOutlet NSArrayController*  _oscSenderArrayController;
	//NSManagedObject*	_oscConfiguration; 
	//NSManagedObject*	_oscReceiver; 
	
	OSCController* _oscController;
	int  _senderCount;  
}

//  Initialization
- (id)initWithZirkoniumSystem:(ZKMRNZirkoniumSystem *)system;


-(void)initializeDefaults;

//  UI Accessors

-(IBAction)actionEnableTesting:(id)sender;

-(OSCController*)oscController;
-(NSArrayController*)outputPatches; 

// @David
-(IBAction)recordingOutputButtonChanged:(id)sender;

-(IBAction)actionIntervalChange:(id)sender;
-(IBAction)actionEnableChange:(id)sender; 
-(IBAction)actionInPortChange:(id)sender; 
-(IBAction)actionOutPortChange:(id)sender; 
-(IBAction)actionAddressChange:(id)sender; 
-(IBAction)actionAddSender:(id)sender;
-(IBAction)actionRemoveSender:(id)sender;
-(void)updateOSCController;

- (NSManagedObject *)oscConfiguration;
- (NSManagedObject *)oscReceiver;

//- (void)setOscConfiguration:(NSManagedObject *)oscConfiguration;
//- (void)setOscReceiver:(NSManagedObject *)oscReceiver;

- (float)fontSize;
- (ZKMORAudioHardwareSystem *)audioHardwareSystem;
- (NSArray *)audioOutputDevices;
- (ZKMORAudioDevice *)audioOutputDevice;
- (void)setAudioOutputDevice:(ZKMORAudioDevice *)audioOutputDevice;

- (ZKMRNSpeakerSetup *)speakerSetup;
- (void)setSpeakerSetup:(ZKMRNSpeakerSetup *)speakerSetup;

- (NSManagedObject *)room;
- (void)setRoom:(NSManagedObject *)room;

- (ZKMRNInputPatch *)inputPatch;
- (void)setInputPatch:(ZKMRNInputPatch *)inputPatch;

- (ZKMRNOutputPatch *)outputPatch;
- (void)setOutputPatch:(ZKMRNOutputPatch *)outputPatch;

//- (ZKMRNDirectOutPatch *)directOutPatch;
//- (void)setDirectOutPatch:(ZKMRNDirectOutPatch *)directOutPatch;

- (NSNumber*)masterGain;
- (void)setMasterGain:(NSNumber*)masterGain;

- (int)filePlayerNumberOfBuffers;
- (void)setFilePlayerNumberOfBuffers:(int)filePlayerNumberOfBuffers;

- (int)filePlayerBufferSize;
- (void)setFilePlayerBufferSize:(int)filePlayerBufferSize;

- (int)sampleRateConverterQuality;
- (void)setSampleRateConverterQuality:(int)sampleRateConverterQuality;

- (NSTimeInterval)displayTimerInterval;
- (void)setDisplayTimerInterval:(NSTimeInterval)displayTimerInterval;

	/// kZKMRNSystemLoudspeakerMode_Real or kZKMRNSystemLoudspeakerMode_Virtual
- (int)loudspeakerMode;
- (void)setLoudspeakerMode:(unsigned)loudspeakerMode;
	/// change the mode, but don't save the change
- (void)setLoudspeakerModeTemporary:(unsigned)loudspeakerMode;

	/// kZKMNRSpeakerLayoutSimulationMode_Headphones or kZKMNRSpeakerLayoutSimulationMode_5Dot0
- (unsigned)loudspeakerSimulationMode;
- (void)setLoudspeakerSimulationMode:(unsigned)loudspeakerSimulationMode;

/*
- (BOOL)isSendingLighting;
- (void)setSendingLighting:(BOOL)isSendingLighting;

- (NSTimeInterval)lightTimerInterval;
- (void)setLightTimerInterval:(NSTimeInterval)lightTimerInterval;

- (float)lightGain;
- (void)setLightGain:(float)lightGain;
*/
	/// return the file player buffer size * number of buffers, converted to millisecs
- (int)filePlayerBufferDuration;

//- (BOOL)isShowingSpeakerMesh;
//- (void)setShowingSpeakerMesh:(BOOL)isShowingSpeakerMesh;

- (int)loggingLevel;
- (void)setLoggingLevel:(int)loggingLevel;
//- (NSAttributedString *)logText;

- (ZKMRNZirkoniumSystem *)zirkoniumSystem;
- (NSManagedObjectContext *)managedObjectContext;

- (NSArray *)speakerSetupSortDescriptors;
- (void)setSpeakerSetupSortDescriptors:(NSArray *)speakerSetupSortDescriptors;

//- (ZKMRNDeviceManager *)deviceManager;
//- (NSMutableArray *)deviceDocumentPaths;
//- (void)setDeviceDocumentPaths:(NSArray *)deviceDocumentPaths;
//- (void)initializeDeviceDocumentPaths;

//  UI Actions
- (IBAction)configureAudioOutputDevice:(id)sender;
- (IBAction)clearLog:(id)sender;
- (IBAction)refreshLog:(id)sender;



- (IBAction)revertLightTable:(id)sender;
- (IBAction)saveLightTable:(id)sender;
//- (IBAction)defaultLightTable:(id)sender;
- (IBAction)actionEnteredLightTableName:(id)sender;

- (IBAction)loadLightTable:(id)sender;

- (IBAction)addLightTable:(id)sender;
- (IBAction)removeLightTable:(id)sender;

- (IBAction)allLightsOff:(id)sender;

//- (IBAction)addDeviceDocument:(id)sender;

- (IBAction)openStudioEditor:(id)sender;

//  Testing Accessors
/*
- (ZKMORGraph *)testGraph;

- (unsigned)testSourceIndex;
- (void)setTestSourceIndex:(unsigned)testSourceIndex;

- (float)testSourceVolume;
- (void)setTestSourceVolume:(float)testSourceVolume;

- (NSIndexSet *)testSourceOutputs;
- (void)setTestSourceOutputs:(NSIndexSet *)testSourceOutputs;

- (BOOL)isGraphTesting;
- (void)setGraphTesting:(BOOL)isGraphTesting;

- (ZKMNRPannerSource *)testPannerSource;
*/
//  ZKMRNSpeakerSetupViewDelegate
//- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition;

//  Display Update
- (void)tick:(id)timer;

@end

///
///  ZKMRNOutputMapSpeakersController
///
///  This object creates the connection between the speakers and the output map.
///
///  This is necessary to populate the table because the controller needs create a connection between
///  two different kinds of objects, which is not possible to create a simple binding in the UI. 
///
@interface ZKMRNOutputMapSpeakersController : NSArrayController {
	IBOutlet ZKMRNPreferencesController*	preferencesController;
	IBOutlet NSArrayController*				outputPatches;
	IBOutlet NSTableView*					tableView;
}

@end

///
///  ZKMRNDeviceDocumentPath
///
///  Used to keep track of the available Device Document files.
///
/*
@interface ZKMRNDeviceDocumentPath : NSObject {
	NSString*	_path;
	BOOL		_isDefault;
	ZKMRNPreferencesController*		_controller;
}

//  Initialization
- (id)initWithPath:(NSString *)path controller:(ZKMRNPreferencesController *)controller;

//  Accessors
- (NSString *)path;
- (BOOL)isDefault;
- (void)setDefault:(BOOL)isDefault;

@end
*/
