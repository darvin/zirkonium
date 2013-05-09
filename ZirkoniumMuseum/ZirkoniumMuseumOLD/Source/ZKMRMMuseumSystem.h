//
//  ZKMRMMuseumSystem.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 17.07.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRNZirkoniumUISystem.h"


@class ZKMRNSpatializerView, ZKMRMPlaybackPiece, ZKMMDPiece;
@class ZKMRMTextLayerManager;
@class ZKMRLPannerLight, ZKMRLMixerLight, ZKMRLOutputDMX;
@class ZKMRMUserWatchdog;
@class ZKMRNLightController;
@interface ZKMRMMuseumSystem : ZKMRNZirkoniumUISystem {

	// GUI State
	IBOutlet ZKMRNSpatializerView*	spatializerView;
	IBOutlet NSView*				textLayoutView;
	IBOutlet NSTableView*			piecesTable;
	IBOutlet NSView*				positionSliderView;
	IBOutlet NSWindow*				mainWindow;
	NSView*							contentView;
	ZKMRMTextLayerManager*			textLayerManager;
	
	NSManagedObjectModel*			playlistManagedObjectModel;
	NSPersistentStoreCoordinator*	playlistPersistentStoreCoordinator;
	NSManagedObjectContext*			playlistManagedObjectContext;
	
	NSMutableArray*					piecesMetadata;
	NSMutableArray*					playbackPieces;
	
	ZKMMDPiece*						playbackMetadata;
	ZKMRMPlaybackPiece*				playbackPiece;
	NSUInteger						playingIndex;
	
	// Light State
	ZKMRLPannerLight*				pannerLight;
	ZKMRLMixerLight*				mixerLight;
	ZKMRLOutputDMX*					outputDMX;
	
	// Tracks user actions
	ZKMRMUserWatchdog*				userWatchdog;
	
	ZKMRNLightController*			_lightController;
}

@property(retain, nonatomic) ZKMMDPiece* playbackMetadata;
@property(retain, nonatomic) ZKMRMPlaybackPiece* playbackPiece;
@property(retain, nonatomic) NSArray* piecesMetadata;
@property(copy, nonatomic) NSIndexSet* playingIndices;
@property(readonly) ZKMRLMixerLight* mixerLight;
@property(readonly) ZKMRLPannerLight* pannerLight;
@property(readonly) ZKMRLOutputDMX* outputDMX;

// UI Actions
- (IBAction)choosePlaylist:(id)sender;

- (NSString *)playlistPath;
- (void)setPlaylistPath:(NSString *)playlistPath;

// Playback mode handling
- (void)activateAutomaticMode;
- (void)activateUserMode;

@end
