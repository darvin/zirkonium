//
//  ZKMRMPlaybackPiece.h
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 20.07.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import "ZKMMDPiece.h"

@class ZKMRNZirkoniumSystem;
@interface ZKMRMPlaybackPiece : NSObject <ZKMMDPieceDelegate> {
	NSManagedObjectContext*			managedObjectContext;
	NSPersistentStoreCoordinator*	persistentStoreCoordinator;
	NSManagedObjectModel*			managedObjectModel;
	NSURL*							pieceURL;
	
	ZKMORGraph*				_pieceGraph;
	NSMutableArray*			_pannerSources;
	ZKMORMixerMatrix*		_pieceMixer;
	ZKMRNZirkoniumSystem*	_system;
	Float64					_currentTime;
	BOOL					_isGraphOutOfSynch;
	
	NSNumber*				pieceGain;
}

@property(copy) NSNumber* pieceGain;

- (void)startPlaying;
- (void)moveTransportToStart;

//  Accessors
- (ZKMORGraph *)pieceGraph;
- (ZKMORMixerMatrix *)pieceMixer;
- (NSArray *)pannerSources;
- (NSManagedObject *)piecePatch;
- (NSString*)fileDirectory; 

//  Convenience Accessors
- (unsigned)numberOfChannels;
- (unsigned)numberOfDirectOuts;

- (BOOL)isFixedDuration;
- (void)setFixedDuration:(BOOL)isFixedDuration;

- (Float64)currentTime;
	// is less than 0 if the piece is not fixed duration
- (Float64)duration;
- (NSString*)durationString;

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

@end

@interface ZKMRMPlaybackPiece (ZKMRMPlaybackPieceInternal)
- (NSArray *)inputSources;
- (NSArray *)testSources;
- (NSArray *)orderedGraphChannels;
- (NSArray *)orderedPositionEvents;
	// used by the system when the input patch changes
- (void)synchronizePatchToGraph;
- (void)synchronizePannerSourcesWithSpatializerView;
@end