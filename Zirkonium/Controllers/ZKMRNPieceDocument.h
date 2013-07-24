//
//  ZKMRNPieceDocument.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import "ZKMRNTimeWatch.h"
#import "ZKMRNSpatializerView.h"
#import "FileSourcesController.h"

// Tags for widgets that I support copying on
enum {
	kPieceDocumentUITag_EventTable = 101,
};

// Pboard types
extern NSString* ZKMRNSphericalEventPboardType;
extern NSString* ZKMRNCartesianEventPboardType;

///
///  ZKMRNPieceDocument
///
///  The class that represents an individual piece / composition.
///
@class ZKMRNZirkoniumSystem, ZKMRNSpatializerView, ZKMRNSpatialChordController;

@interface ZKMRNPieceDocument : NSPersistentDocument <ZKMRNDomeViewDelegate, FileSourcesControllerDelegate> {

	IBOutlet NSWindow*				mainWindow;
	IBOutlet NSTabView*				mainTabView;
	IBOutlet ZKMRNSpatializerView*	initialSpatializerView;
	IBOutlet ZKMRNSpatializerView*	spatializerView;
	IBOutlet ZKMRNSpatializerView*	chordSpatializerView;
	IBOutlet NSArrayController*		graphChannelsController;
	IBOutlet FileSourcesController*		fileSourcesController;
	IBOutlet NSArrayController*		eventsController;
	IBOutlet NSArrayController*		groupsController; 
	IBOutlet NSBrowser*				graphBrowser;
	IBOutlet NSPopUpButtonCell*		groupsCell;
	IBOutlet NSObjectController*		uiGraph; 
	IBOutlet NSButton* recordButton; 
	IBOutlet NSButton* playButton; 
	IBOutlet NSWindow*				visualizerWindow;
	IBOutlet ZKMRNSpatializerView*	visualizerWindowView;
	
	IBOutlet NSSlider*				timelineSlider;

		// Chords Control
	ZKMRNSpatialChordController		*_chordController;

	ZKMORGraph*				_pieceGraph;
	NSMutableArray*			_pannerSources;
	ZKMORMixerMatrix*		_pieceMixer;
	ZKMRNZirkoniumSystem*	_system;
	//Float64					_currentTime;
	BOOL					_isGraphOutOfSynch;
	
	ZKMRNTimeWatch*			_timeWatch; 
	
	BOOL _isRecording;
	BOOL _hasProcessedRecording; 
	
	BOOL _isPlaying; 
}

//  UI Actions
- (IBAction)togglePlay:(id)sender;
- (IBAction)toggleRecord:(id)sender;
- (IBAction)moveTransportToStart:(id)sender;
- (IBAction)exportToASCII:(id)sender;
- (IBAction)activateVisualizer:(id)sender;
- (IBAction)deactivateVisualizer:(id)sender; 
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)startChord:(id)sender;
- (IBAction)setChordNumberOfPointsTo1:(id)sender;
- (IBAction)setChordNumberOfPointsTo2:(id)sender;
- (IBAction)setChordNumberOfPointsTo3:(id)sender;
-(void)togglePlayButton:(BOOL)flag;
-(void)toggleRecordButton:(BOOL)flag; 
-(void)setHasProcessedRecording:(BOOL)flag; 
-(BOOL)hasProcessedRecording;
 
//  Accessors
- (ZKMORGraph *)pieceGraph;
- (ZKMORMixerMatrix *)pieceMixer;
- (NSArray *)pannerSources;
- (NSManagedObject *)piecePatch;

- (NSSet *)graphDirectOuts; //jens

//  Convenience Accessors
- (unsigned)numberOfChannels;
- (unsigned)numberOfDirectOuts;

//  Actions
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain;
- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain;
- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain;
- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain;

//  UI Accessors
- (float)fontSize;

-(IBAction)addChannel:(id)sender;
-(IBAction)removeChannel:(id)sender;
-(BOOL)canRemoveChannel;

- (BOOL)isInputOn;
- (void)setInputOn:(BOOL)isInputOn;

//- (BOOL)isExternalOn;
//- (void)setExternalOn:(BOOL)isExternalOn;

-(BOOL)isRecording; 

- (BOOL)isTestSourceOn;
- (void)setTestSourceOn:(BOOL)isTestSourceOn;

- (BOOL)isFixedDuration;
- (void)setFixedDuration:(BOOL)isFixedDuration;

-(ZKMRNTimeWatch*)timeWatch; 
- (void)synchronizePosition;
- (void)synchronizeCurrentTimeToGraph;

//- (Float64)currentTime;
	// is less than 0 if the piece is not fixed duration
//- (Float64)duration;

//- (float)currentPosition;
	// sets current time as a proportion of duration
//- (void)setCurrentPosition:(float)pos;

/*
- (unsigned)currentMM;
- (void)setCurrentMM:(unsigned)currentMM;
- (unsigned)currentSS;
- (void)setCurrentSS:(unsigned)currentSS;
- (unsigned)currentMS;
- (void)setCurrentMS:(unsigned)currentMS;

- (unsigned)currentMMToGo;
//- (void)setCurrentMMToGo:(unsigned)currentMMToGo;
- (unsigned)currentSSToGo;
//- (void)setCurrentSSToGo:(unsigned)currentSSToGo;
- (unsigned)currentMSToGo;
//- (void)setCurrentMSToGo:(unsigned)currentMSToGo;
*/

- (NSArray *)graphChannelSortDescriptors;
- (void)setGraphChannelSortDescriptors:(NSArray *)graphChannelSortDescriptors;

- (NSArray *)directOutSortDescriptors;
- (void)setDirectOutSortDescriptors:(NSArray *)directOutSortDescriptors;

- (NSArray *)eventSortDescriptors;
- (void)setEventSortDescriptors:(NSArray *)eventSortDescriptors;

- (NSArray *)orderedAudioSources;


- (ZKMRNZirkoniumSystem *)zirkoniumSystem;


//  Queries
- (BOOL)isPlaying;
- (NSString *)playButtonTitle;

//  Display Update
- (void)tick:(id)timer;

//TableView Selection 
-(void)tableViewSelectionDidChange:(NSNotification*)inNotification;

@end

@interface ZKMRNPieceDocument (ZKMRNPieceDocumentSpatialChords)

// Chord
- (NSUInteger)chordNumberOfPoints;
- (void)setChordNumberOfPoints:(NSUInteger)chordNumberOfPoints;
- (float)chordSpacing;
- (void)setChordSpacing:(float)chordSpacing;
- (float)chordTransitionTime;
- (void)setChordTransitionTime:(float)chordTransitionTime;

// Rotation
- (float)chordRotationSpeed;
- (void)setChordRotationSpeed:(float)chordRotationSpeed;
- (float)chordRotationTilt;
- (void)setChordRotationTilt:(float)chordRotationTilt;

// Tilt
- (float)chordTiltAzimuth;
- (void)setChordTiltAzimuth:(float)chordTiltAzimuth;
- (float)chordTiltZenith;
- (void)setChordTiltZenith:(float)chordTiltZenith;

@end

@interface ZKMRNPieceDocument (ZKMRNPieceDocumentInternal)
- (NSArray *)inputSources;
//- (NSArray *)externalSources; 
- (NSArray *)testSources;
- (NSArray *)orderedGraphChannels;
- (NSArray *)orderedPositionEvents;
	// used by the system when the input patch changes
- (void)synchronizePatchToGraph;
@end

