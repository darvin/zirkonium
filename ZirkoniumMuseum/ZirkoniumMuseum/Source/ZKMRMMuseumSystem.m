//
//  ZKMRMMuseumSystem.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 17.07.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMMuseumSystem.h"
#import "ZKMMDPiece.h"
#import "ZKMRMPlaybackPiece.h"
#import "ZKMRNSpatializerView.h"
#import "ZKMRMTextLayerManager.h"
#import "ZKMRMUserWatchdog.h"
#import "ZKMRLPannerLight.h"
#import "ZKMRLMixerLight.h"
#import "ZKMRLOutputDMX.h"
#import "ZKMRMLightController.h"
#import "ItemView.h"

@interface  ZKMRMMuseumSystem (ZKMRMMuseumSystemManagedObjectModel)

- (NSManagedObjectModel *)playlistManagedObjectModel;
- (NSPersistentStoreCoordinator *)playlistPersistentStoreCoordinator;
- (NSManagedObjectContext *)playlistManagedObjectContext;
- (NSArray *)pieces;
- (NSArray *)piecesSortDescriptors;
- (void)startPieceAtIndex:(NSUInteger)index;
- (void)initializeStateFromPlaylist;
- (void)startRunning;

@end



@implementation ZKMRMMuseumSystem

@synthesize playbackMetadata, playbackPiece;
@synthesize piecesMetadata;
@synthesize mixerLight, pannerLight, outputDMX;
@synthesize playButtonFlag; 

- (void)dealloc
{
	[playlistManagedObjectModel release];
	[playlistPersistentStoreCoordinator release];
	[playlistManagedObjectContext release];
	[piecesMetadata release];
	[playbackPieces release];
	[textLayerManager release];
	[pannerLight release];
	[mixerLight release];
	[outputDMX release];
	[dummyTextLayer release]; 
	[super dealloc];
}

- (NSArray *)lampOrder
{
	// The lamp order is used to convert the DMX address of the lamps to
	// the numbering scheme used by Zirkonium.
	// The default implemented here is that the DMX address matches the
	// Zirkonium numbering.
	//
	NSMutableArray* lampOrderOneOffset = [NSMutableArray array];
//	NSUInteger i, count = 24;
//	for (i = 0; i < count; ++i) {
//		[lampOrder addObject: [NSNumber numberWithInt: i]];
//	}
	
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 7]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 4]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 12]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 8]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 9]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 1]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 5]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 2]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 10]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 6]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 11]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 3]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 19]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 20]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 21]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 22]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 13]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 14]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 15]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 16]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 17]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 18]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 23]];
	[lampOrderOneOffset addObject: [NSNumber numberWithInt: 24]];
	
	NSMutableArray* lampOrder = [NSMutableArray array];
	for (NSNumber* lampNumber in lampOrderOneOffset) {
		[lampOrder addObject: [NSNumber numberWithInt: [lampNumber intValue] - 1]];
	}

	return lampOrder;
}

- (void)createLightController
{
	// Initialize light state
	mixerLight = [[ZKMRLMixerLight alloc] init];
	outputDMX = [[ZKMRLOutputDMX alloc] init];
/*
	NSError* errorObject;
	if (![outputDMX setAddress: [outputDMX defaultLanBoxAddress] error: &errorObject])
		NSLog(@"Problems with LanBox: %@", errorObject);
*/

	[mixerLight setNumberOfOutputChannels: [[[self speakerSetup] speakerLayout] numberOfSpeakers]];
	[outputDMX setMixer: mixerLight];
	[outputDMX setLampOrder: [self lampOrder]];
	
	pannerLight = [[ZKMRLPannerLight alloc] init];
	[pannerLight bind: @"lampLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[pannerLight setMixer: mixerLight];
	
	_lightController = [[ZKMRMLightController alloc] initWithZirkoniumSystem:self];
}

- (void)awakeFromNib
{

	[self toggleFullScreen];

	[self createLightController];
		
	[super awakeFromNib];


	[gainSlider setFloatValue:1.0];

	dummyTextLayer = [textLayoutView.layer retain];
	
	userWatchdog = [[ZKMRMUserWatchdog alloc] init];
	
	// Enable Light Control
	[[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"LightEnabled"];

	// Wire up the spatializer view
	[spatializerView awakeFromNib];

	
	[spatializerView bind: @"speakerLayout" toObject: self withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	
	[self initializeStateFromPlaylist];
	
	
	
	
}

- (NSIndexSet *)playingIndices
{
	return [NSIndexSet indexSetWithIndex: playingIndex];
}

- (void)setPlayingIndices:(NSIndexSet *)playingIndices
{
	NSUInteger newIndex = [playingIndices firstIndex];
	if (newIndex < [playbackPieces count]) {
		playingIndex = newIndex;
		[self startPieceAtIndex: playingIndex];
	}
}

- (void)initializeStateFromPlaylist
{
	//NSLog(@"Initialize State From Playlist");
	
	NSString* playlistPath = [self playlistPath];
	NSString* mainDir = [playlistPath stringByDeletingLastPathComponent];
	
	NSFileManager* fileManager = [NSFileManager defaultManager];

	// initialize the arrays
	NSMutableArray* myPiecesMetadata = [[NSMutableArray alloc] init];
	playbackPieces = [[NSMutableArray alloc] init];
	for (ZKMMDPiece* piece in [self pieces]) {
		NSError* error;
		NSURL* pieceURL;
		if (!piece.path) continue;
		if ([piece.path isAbsolutePath])
			pieceURL = [NSURL fileURLWithPath: piece.path];
		else
			pieceURL = [NSURL fileURLWithPath: [mainDir stringByAppendingPathComponent: piece.path]];
		// Check that the file exists
		BOOL fileExists = [fileManager fileExistsAtPath: [pieceURL path]];
		if (!fileExists) {
			NSLog(@"ERROR: %@ does not exist.", pieceURL);
			continue;
		}
		ZKMRMPlaybackPiece* aPlaybackPiece = [[ZKMRMPlaybackPiece alloc] initWithContentsOfURL: pieceURL ofType: @"XML" error: &error];
		if (!aPlaybackPiece)
			NSLog(@"Failed to open %@ : %@\n%@", piece.title, pieceURL, error);
		else {
			piece.delegate = aPlaybackPiece;
		
			[myPiecesMetadata addObject: piece];
			[playbackPieces addObject: aPlaybackPiece];
			aPlaybackPiece.pieceGain = piece.masterGain;
			// give ownership to the array
			[aPlaybackPiece release];
		}
	}
	self.piecesMetadata = myPiecesMetadata;
}

- (void)startRunning
{
	NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:0];
	[self setPlayingIndices:indexSet];
}

- (IBAction)choosePlaylist:(id)sender
{
	int result;
	NSArray* fileTypes = [NSArray arrayWithObject: @"museumdom"];
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];

	[oPanel setAllowsMultipleSelection: NO];
	result = [oPanel runModalForDirectory: NSHomeDirectory() file: nil types: fileTypes];
	if (result != NSOKButton) return;
	
	NSArray* filenames = [oPanel filenames];
	if ([filenames count] < 1) return;
	
	NSString* filename = [filenames objectAtIndex: 0];
	[self setPlaylistPath: filename];
	[[NSDocumentController sharedDocumentController] 
		noteNewRecentDocumentURL: [NSURL fileURLWithPath: filename]];
		
	NSURL* url = [NSURL fileURLWithPath: filename];
	NSError* error;
	// remove existing presistent stores
	for (NSPersistentStore* store in [playlistPersistentStoreCoordinator persistentStores]) {
		if (![playlistPersistentStoreCoordinator removePersistentStore: store error: &error])
			[[NSApplication sharedApplication] presentError: error];
	}

	// add the new one
	if (![playlistPersistentStoreCoordinator addPersistentStoreWithType: NSXMLStoreType configuration: nil URL: url options: nil error: &error]){
		[[NSApplication sharedApplication] presentError: error];
	}
	
	[self initializeStateFromPlaylist];
}

- (void)toggleFullScreen
{
	NSDictionary* options = [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES] forKey: NSFullScreenModeAllScreens];
	if (nil == contentView) contentView = [mainWindow contentView];
	if ([contentView isInFullScreenMode]) {
		[contentView exitFullScreenModeWithOptions: options];
	} else {
		[contentView enterFullScreenMode: [NSScreen mainScreen] withOptions: options];
	}
	
	[[piecesTable window] makeFirstResponder: piecesTable];
	
	//[self startRunning];
}

- (NSString *)playlistPath 
{
	//NSLog(@"File: %@", [[NSUserDefaults standardUserDefaults] objectForKey: @"PlaylistPath"]);
	return [[NSUserDefaults standardUserDefaults] objectForKey: @"PlaylistPath"];
}

- (void)setPlaylistPath:(NSString *)playlistPath
{
	[[NSUserDefaults standardUserDefaults] setObject: playlistPath forKey: @"PlaylistPath"];
}

- (void)stopPlaying
{
	[self setPlaying: NO];
	[self setPlayingPiece: nil];
}

- (void)startPieceAtIndex:(NSUInteger)index
{
	[self stopPlaying];
			
	ItemView* selectedItemView = nil; 
	if([[collectionView subviews] count] > index) {
		selectedItemView = [[collectionView subviews] objectAtIndex:index];
		NSRect itemRect = [selectedItemView frame]; 
		[collectionView scrollRectToVisible:itemRect]; 
	}
	

	for(NSView* itemView in [collectionView subviews]) {
		BOOL selected = NO; 
		if(selectedItemView && [itemView isEqualTo:selectedItemView]) {
			selected = YES; 
		}
		[(ItemView*)itemView setSelected:selected];
	}
	
	
	ZKMRMPlaybackPiece* piece = [playbackPieces objectAtIndex: index];
	
	// Set File Firectory ...
	NSString* directory = [piece fileDirectory];
	if(directory) 
		[[NSFileManager defaultManager] changeCurrentDirectoryPath:directory]; 
	else 
		NSLog(@"Warning: No Directory specified!");
			
										
	self.playbackMetadata = [piecesMetadata objectAtIndex: index];
	self.playbackPiece = piece;
	
		
	if(!textLayerManager) {
		textLayerManager = [[ZKMRMTextLayerManager alloc] initWithLineWidth:textLayoutView.frame.size.width];
		textLayoutView.layer = textLayerManager.layer;
	}
	
	// Gain ...
	[self actionAdjustGain:gainSlider];
	
	// Piece Metadata ...
	[textLayerManager setPieceMetadata: playbackMetadata];
	
	// Light ...
	[_lightController loadLightTable:[playbackMetadata valueForKey:@"lightPresetName"]];

	[playbackPiece synchronizePannerSourcesWithSpatializerView];
	[spatializerView setPannerSources: [playbackPiece pannerSources]];
	[playbackPiece moveTransportToStart];
	[playbackPiece startPlaying];
	self.playButtonFlag = YES; 
	
	
}
 
- (void)playRandomPiece
{
	[self stopPlaying];

	NSUInteger newPlayingIndex = (playingIndex + 1) % [playbackPieces count];
	[self setPlayingIndices: [NSIndexSet indexSetWithIndex: newPlayingIndex]];
}

- (void)tick:(id)timer
{
	[super tick: timer];
	
	[pannerLight updatePanningToMixer];
	[outputDMX tick: timer];
	
	[spatializerView setNeedsDisplay: YES];
	
	if ([playbackPiece currentPosition] > 1.0) {
		[self playRandomPiece];
	}
	
	[playbackMetadata willChangeValueForKey:@"ellapsed"];
	[playbackMetadata didChangeValueForKey:@"ellapsed"];
}

#pragma mark -
#pragma mark User Interaction
#pragma mark -

-(IBAction)actionTimeline:(id)sender
{
	[playbackMetadata willChangeValueForKey:@"ellapsed"];
	[playbackMetadata didChangeValueForKey:@"ellapsed"];
	
	if (![self isPlaying]) {
		
		//[[self playingPiece] synchronizePatchToGraph];
		//[[self playingPiece] synchronizeCurrentTimeToGraph];
		//[[self playingPiece] addEventsToScheduler];
		//[[self playingPiece] activatePannerSources];
		//[[self playingPiece] activateDirectOuts];
		
		[[self scheduler] task: [self spatializationTimerInterval]];
		
		[spatializerView setNeedsDisplay: YES];
	}
}

-(IBAction)actionTogglePause:(id)sender
{
	if([self isPlaying]) {
		[self setPlaying:NO];
		self.playButtonFlag = NO; 
	}
	else {
		[self setPlaying:YES];
		self.playButtonFlag = YES; 
	}
}

-(IBAction)actionAdjustGain:(id)sender
{
	//NSLog(@"Master Gain: %f, Piece Gain: %f, User Gain: %f",  [self masterGain], [playbackMetadata.masterGain floatValue], [sender floatValue]);
	float gain = [self masterGain] * [playbackMetadata.masterGain floatValue] * [sender floatValue];	
	//NSLog(@"Gain: %f", gain);
	[_deviceOutput setVolume: gain];
}

#pragma mark ZKMRMMuseumSystemManagedObjectModel
- (NSManagedObjectModel *)playlistManagedObjectModel {

    if (playlistManagedObjectModel != nil) {
        return playlistManagedObjectModel;
    }
	
//	NSString* momPath = [[NSBundle mainBundle] pathForResource: @"ZKMMDDocument" ofType: @"mom"];
	NSString* momPath = [[NSBundle mainBundle] pathForResource: @"ZKMMDDocument" ofType: @"momd"];
    playlistManagedObjectModel = 
		[[NSManagedObjectModel alloc] 
			initWithContentsOfURL: [NSURL fileURLWithPath: momPath]];
    return playlistManagedObjectModel;
}

- (NSPersistentStoreCoordinator *)playlistPersistentStoreCoordinator {

    if (playlistPersistentStoreCoordinator != nil) {
        return playlistPersistentStoreCoordinator;
    }

    NSURL *url;
    NSError *error;
	NSDictionary *options = [NSDictionary dictionaryWithObject: [NSNumber numberWithBool:YES] forKey: NSMigratePersistentStoresAutomaticallyOption];
    
    playlistPersistentStoreCoordinator = 
		[[NSPersistentStoreCoordinator alloc] 
			initWithManagedObjectModel: [self playlistManagedObjectModel]];
			
	NSString* path = [self playlistPath];
	if (path) {
		url = [NSURL fileURLWithPath: path];
		if (![playlistPersistentStoreCoordinator addPersistentStoreWithType: NSXMLStoreType configuration: nil URL: url options: options error: &error]){
			[[NSApplication sharedApplication] presentError:error];
		}
	}

    return playlistPersistentStoreCoordinator;
}

- (NSManagedObjectContext *)playlistManagedObjectContext {

    if (playlistManagedObjectContext != nil) {
        return playlistManagedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self playlistPersistentStoreCoordinator];
    if (coordinator != nil) {
        playlistManagedObjectContext = [[NSManagedObjectContext alloc] init];
        [playlistManagedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return playlistManagedObjectContext;
}

- (NSArray *)pieces
{
	NSManagedObjectContext* moc = [self playlistManagedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"ZKMMDPiece" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	[request setSortDescriptors: [self piecesSortDescriptors]];
	
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	if (error) {
		[[NSApplication sharedApplication] presentError: error];
		return nil;
	}
	return array;
}

- (NSArray *)piecesSortDescriptors
{
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"title" ascending: YES];
	return [NSArray arrayWithObject: sortDescriptor];
}

#pragma mark Playback mode handling
- (void)activateAutomaticMode 
{

}

- (void)activateUserMode
{

}

@end
