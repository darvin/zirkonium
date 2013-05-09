//
//  ZKMRNInterfaceDocument.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

///
///  ZKMRNInterfaceDocument
///
///  The class that represents an individual piece / composition.
///
@class ZKMRNZirkoniumUISystem, ZKMRNSpatializerView;
@interface ZKMRNInterfaceDocument : NSPersistentDocument {
	IBOutlet NSWindow*				mainWindow;
	IBOutlet NSTabView*				mainTabView;
	IBOutlet ZKMRNSpatializerView*	initialSpatializerView;
	IBOutlet ZKMRNSpatializerView*	spatializerView;
	IBOutlet NSArrayController*		graphChannelsController;

	ZKMORGraph*				_pieceGraph;
	NSMutableArray*			_pannerSources;
	ZKMORMixerMatrix*		_pieceMixer;
	ZKMRNZirkoniumUISystem*	_system;
	Float64					_currentTime;
	BOOL					_isGraphOutOfSynch;
}

//  UI Actions
- (IBAction)togglePlay:(id)sender;
- (IBAction)moveTransportToStart:(id)sender;
- (IBAction)exportToASCII:(id)sender;

//  Accessors
- (ZKMORGraph *)pieceGraph;
- (ZKMORMixerMatrix *)pieceMixer;
- (NSArray *)pannerSources;
- (NSManagedObject *)piecePatch;

//  Convenience Accessors
- (unsigned)numberOfChannels;
- (unsigned)numberOfDirectOuts;

//  Actions
- (void)panChannel:(unsigned)channel center:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain;

//  UI Accessors
- (float)fontSize;

- (BOOL)isInputOn;
- (void)setInputOn:(BOOL)isInputOn;

- (BOOL)isTestSourceOn;
- (void)setTestSourceOn:(BOOL)isTestSourceOn;

- (BOOL)isFixedDuration;
- (void)setFixedDuration:(BOOL)isFixedDuration;

- (Float64)currentTime;

- (unsigned)currentHH;
- (void)setCurrentHH:(unsigned)currentHH;
- (unsigned)currentMM;
- (void)setCurrentMM:(unsigned)currentMM;
- (unsigned)currentSS;
- (void)setCurrentSS:(unsigned)currentSS;

- (NSArray *)graphChannelSortDescriptors;
- (void)setGraphChannelSortDescriptors:(NSArray *)graphChannelSortDescriptors;

- (NSArray *)directOutSortDescriptors;
- (void)setDirectOutSortDescriptors:(NSArray *)directOutSortDescriptors;

- (NSArray *)eventSortDescriptors;
- (void)setEventSortDescriptors:(NSArray *)eventSortDescriptors;

- (ZKMRNZirkoniumUISystem *)zirkoniumSystem;

//  Queries
- (BOOL)isPlaying;

//  Display Update
- (void)tick:(id)timer;

@end

@interface ZKMRNInterfaceDocument (ZKMRNPieceDocumentInternal)
- (NSArray *)inputSources;
- (NSArray *)testSources;
- (NSArray *)orderedGraphChannels;
- (NSArray *)orderedPositionEvents;
	// used by the system when the input patch changes
- (void)synchronizePatchToGraph;
@end

