//
//  ZKMRNPieceDocument.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

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
@class ZKMRNZirkoniumSystem, ZKMRNSpatializerView;
@interface ZKMRNPieceDocument : NSPersistentDocument {
	IBOutlet NSWindow*				mainWindow;
	IBOutlet NSTabView*				mainTabView;
	IBOutlet ZKMRNSpatializerView*	initialSpatializerView;
	IBOutlet ZKMRNSpatializerView*	spatializerView;
	IBOutlet NSArrayController*		graphChannelsController;
	IBOutlet NSArrayController*		fileSourcesController;
	IBOutlet NSArrayController*		eventsController;
	IBOutlet NSBrowser*				graphBrowser;
	
	IBOutlet NSWindow*				visualizerWindow;
	IBOutlet ZKMRNSpatializerView*	visualizerWindowView;

	ZKMORGraph*				_pieceGraph;
	NSMutableArray*			_pannerSources;
	ZKMORMixerMatrix*		_pieceMixer;
	ZKMRNZirkoniumSystem*	_system;
	Float64					_currentTime;
	BOOL					_isGraphOutOfSynch;
}

//  UI Actions
- (IBAction)togglePlay:(id)sender;
- (IBAction)toggleRecord:(id)sender;
- (IBAction)moveTransportToStart:(id)sender;
- (IBAction)exportToASCII:(id)sender;
- (IBAction)activateVisualizer:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;

//  Accessors
- (ZKMORGraph *)pieceGraph;
- (ZKMORMixerMatrix *)pieceMixer;
- (NSArray *)pannerSources;
- (NSManagedObject *)piecePatch;

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

- (BOOL)isInputOn;
- (void)setInputOn:(BOOL)isInputOn;

- (BOOL)isTestSourceOn;
- (void)setTestSourceOn:(BOOL)isTestSourceOn;

- (BOOL)isFixedDuration;
- (void)setFixedDuration:(BOOL)isFixedDuration;

- (Float64)currentTime;
	// is less than 0 if the piece is not fixed duration
- (Float64)duration;

- (float)currentPosition;
	// sets current time as a proportion of duration
- (void)setCurrentPosition:(float)pos;

- (unsigned)currentMM;
- (void)setCurrentMM:(unsigned)currentMM;
- (unsigned)currentSS;
- (void)setCurrentSS:(unsigned)currentSS;
- (unsigned)currentMS;
- (void)setCurrentMS:(unsigned)currentMS;

- (NSArray *)graphChannelSortDescriptors;
- (void)setGraphChannelSortDescriptors:(NSArray *)graphChannelSortDescriptors;

- (NSArray *)directOutSortDescriptors;
- (void)setDirectOutSortDescriptors:(NSArray *)directOutSortDescriptors;

- (NSArray *)eventSortDescriptors;
- (void)setEventSortDescriptors:(NSArray *)eventSortDescriptors;

- (ZKMRNZirkoniumSystem *)zirkoniumSystem;

//  Queries
- (BOOL)isPlaying;

//  Display Update
- (void)tick:(id)timer;

@end

@interface ZKMRNPieceDocument (ZKMRNPieceDocumentInternal)
- (NSArray *)inputSources;
- (NSArray *)testSources;
- (NSArray *)orderedGraphChannels;
- (NSArray *)orderedPositionEvents;
	// used by the system when the input patch changes
- (void)synchronizePatchToGraph;
@end

