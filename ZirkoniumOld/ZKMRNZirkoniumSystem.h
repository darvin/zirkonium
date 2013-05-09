//
//  ZKMRNZirkoniumSystem.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

enum {
	kZKMRNSystemLoudspeakerMode_Real = 0,
	kZKMRNSystemLoudspeakerMode_Virtual = 1
}; 

///
///  ZKMRNZirkoniumSystem
///
///  Object that manages global state in Zirkonium.
///
@class ZKMRNStudioSetupDocument, ZKMRNPreferencesController, ZKMRNOSCController, ZKMRNInputPatch, ZKMRNOutputPatch, ZKMRNDirectOutPatch, ZKMORLoggerClient;
@class ZKMRNSpeakerSetup, ZKMRNPieceDocument;
@class ZKMRNPreferencesController, ZKMRNOSCController, ZKMRNDeviceManager, ZKMRNAudioUnitController, ZKMRNLightController;
@interface ZKMRNZirkoniumSystem : NSObject  {
	//  UI State
	ZKMRNStudioSetupDocument*		_studioSetup;
	ZKMORLoggerClient*				_loggerClient;
	
	//  Internal State
	ZKMRNSpeakerSetup*		_speakerSetup;
	NSManagedObject*		_room;
	ZKMRNInputPatch*		_inputPatch;
	ZKMRNOutputPatch*		_outputPatch;
	ZKMRNDirectOutPatch*	_directOutPatch;
	float					_masterGain;
	unsigned				_filePlayerNumberOfBuffers;
	unsigned				_filePlayerBufferSize;
	unsigned				_sampleRateConverterQuality;
	unsigned				_loudspeakerMode;
	unsigned				_loudspeakerSimulationMode;
	
	//  Audio State
	ZKMORDeviceOutput*		_deviceOutput;
	ZKMORGraph*				_audioGraph;
	ZKMORMixerMatrix*		_spatializationMixer;
	ZKMNRSpeakerLayoutSimulator* _speakerLayoutSimulator;
	ZKMNRVBAPPanner*		_panner;
	ZKMNREventScheduler*	_scheduler;
	
	// UI Objects
	IBOutlet NSPanel*				aboutPanel;

	// External Interfaces
	ZKMRNPreferencesController*		_preferencesController;
	ZKMRNOSCController*				_oscController;
	ZKMRNDeviceManager*				_deviceManager;
	ZKMRNAudioUnitController*		_audioUnitController;
	ZKMRNLightController*			_lightController;

	
	//  Audio State
	ZKMRNPieceDocument*				_playingPiece;
	NSTimer*						_spatializationTimer;
	NSTimeInterval					_spatializationTimerInterval;

		/// can't necessarily tell from the device output if I'm playing or not -- I may
		/// keep the device output running in the background for better performance and only
		/// internally stop/start playing
	BOOL							_isPlaying;
	BOOL							_isTesting;
	
	BOOL							_isRecording;
	BOOL							_hasFileName;
	AudioStreamBasicDescription		_fileFormatDesc;
	ZKMORAudioFileRecorder*			_fileRecorder;
	
		// some versions are limited and don't include the studio setup.
	BOOL							_isStudioSetupSupported;
	
	//  Graphics State
	NSTimer*						_displayTimer;
	NSTimeInterval					_displayTimerInterval;
	NSTimer*						_loggerTimer;
}

//  Singleton
+ (ZKMRNZirkoniumSystem *)sharedZirkoniumSystem;

//  Accessors
- (ZKMORAudioDevice *)audioOutputDevice;
- (void)setAudioOutputDevice:(ZKMORAudioDevice *)audioOutputDevice;

- (ZKMRNSpeakerSetup *)speakerSetup;
- (void)setSpeakerSetup:(ZKMRNSpeakerSetup *)speakerSetup;

- (NSManagedObject *)room;
- (void)setRoom:(NSManagedObject *)room;

	/// kZKMRNSystemLoudspeakerMode_Real or kZKMRNSystemLoudspeakerMode_Virtual
- (unsigned)loudspeakerMode;
- (void)setLoudspeakerMode:(unsigned)loudspeakerMode;

	/// kZKMNRSpeakerLayoutSimulationMode_Headphones or kZKMNRSpeakerLayoutSimulationMode_5Dot0
- (unsigned)loudspeakerSimulationMode;
- (void)setLoudspeakerSimulationMode:(unsigned)loudspeakerSimulationMode;

- (ZKMRNInputPatch *)inputPatch;
- (void)setInputPatch:(ZKMRNInputPatch *)inputPatch;

- (ZKMRNOutputPatch *)outputPatch;
- (void)setOutputPatch:(ZKMRNOutputPatch *)outputPatch;

- (ZKMRNDirectOutPatch *)directOutPatch;
- (void)setDirectOutPatch:(ZKMRNDirectOutPatch *)directOutPatch;

- (float)masterGain;
- (void)setMasterGain:(float)masterGain;

- (unsigned)filePlayerNumberOfBuffers;
- (void)setFilePlayerNumberOfBuffers:(unsigned)filePlayerNumberOfBuffers;

- (unsigned)filePlayerBufferSize;
- (void)setFilePlayerBufferSize:(unsigned)filePlayerBufferSize;

- (unsigned)sampleRateConverterQuality;
- (void)setSampleRateConverterQuality:(unsigned)sampleRateConverterQuality;

- (unsigned)sampleRateConverterQualityUI;
- (void)setSampleRateConverterQualityUI:(unsigned)sampleRateConverterQualityUI;

- (NSTimeInterval)displayTimerInterval;
- (void)setDisplayTimerInterval:(NSTimeInterval)displayTimerInterval;

- (ZKMRNStudioSetupDocument *)studioSetupDocument;
- (ZKMRNPreferencesController *)preferencesController;
- (ZKMRNLightController *)lightController;
- (ZKMORLoggerClient *)loggerClient;

- (NSString *)zirkoniumVersionString;

// Actions
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain;
- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain;
- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain;
- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain;

@end

///
///  ZKMRNZirkoniumSystem (ZKMRNZirkoniumSystemAudio)
///
///  Methods for manipulating the audio global state.
///
@interface ZKMRNZirkoniumSystem (ZKMRNZirkoniumSystemAudio)

- (ZKMORDeviceOutput *)deviceOutput;
- (ZKMORDeviceInput *)deviceInput;
- (ZKMORGraph *)audioGraph;
- (ZKMORMixerMatrix *)spatializationMixer;
- (ZKMNRSpeakerLayoutSimulator *)speakerLayoutSimulator;
- (ZKMNRVBAPPanner *)panner;
- (ZKMNREventScheduler *)scheduler;
- (ZKMORClock *)clock;

- (BOOL)isPlaying;
- (void)setPlaying:(BOOL)isPlaying;

- (BOOL)isGraphTesting;
- (void)setGraphTesting:(BOOL)isGraphTesting;

- (BOOL)isRecording;
- (void)setRecording:(BOOL)isRecording;

@end

///
///  ZKMRNZirkoniumSystem (ZKMRNZirkoniumUISystem)
///
///  Methods for the UI
///
@interface ZKMRNZirkoniumSystem (ZKMRNZirkoniumUISystem)

//  UI Actions
- (IBAction)studioSetup:(id)sender;
- (IBAction)deviceSetup:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)showAboutBox:(id)sender;
- (IBAction)import:(id)sender;
- (IBAction)newDeviceSetup:(id)sender;

//  Accessors
- (ZKMRNPieceDocument *)playingPiece;
- (void)setPlayingPiece:(ZKMRNPieceDocument *)document;

- (ZKMRNDeviceManager *)deviceManager;
- (unsigned)deviceNumberOfChannels;
- (void)setDeviceNumberOfChannels:(unsigned)deviceNumberOfChannels;

	/// 0 is not logging, 1 is error ... 4 is debug
- (unsigned)loggingLevel;
- (void)setLoggingLevel:(unsigned)loggingLevel;

- (NSString *)playButtonTitle;
- (NSString *)recordButtonTitle;

@end

///
///  ZKMRNZirkoniumSystem (ZKMRNZirkoniumSystemInternal)
///
///  Subclasses may want to override these methods.
///
@interface ZKMRNZirkoniumSystem (ZKMRNZirkoniumSystemInternal)

- (NSString *)applicationSupportFolder;

- (void)initializeStudioSetup;
- (void)createStudioSetupURL:(NSURL *)studioURL;
- (void)synchronizeInputPatch;
- (void)synchronizeOutputPatch;
- (void)synchronizeDirectOutPatch;
- (void)synchronizeAudioGraph;
- (void)synchronizeRecorder;

@end

