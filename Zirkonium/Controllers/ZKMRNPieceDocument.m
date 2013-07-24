//
//  ZKMRNPieceDocument.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import "ZKMRNPieceDocument.h"
#import "ZKMRNZirkoniumUISystem.h"
#import "ZKMRNGraphChannel.h"
#import "ZKMRNSpatializerView.h"
#import "ZKMRNPositionEvent.h"
#import "ZKMRNAudioSource.h"
#import "ZKMRNFileSource.h"
#import "ZKMRNManagedObjectExtensions.h"
#import "ZKMRNChannelGroup.h"
#import "ZKMRNPieceDocumentWindowController.h"
#import "NSString+PathResolver.h"
#import "ZKMRNSpatialChordController.h"
#import "ZKMRNGraph.h"

static NSString* kZKMRNPieceVersionKey = @"ZKMRNPieceVersionKey";
static unsigned kZKMRNPieceVersion = 3;

static void print_stream_info (AudioStreamBasicDescription *stream)
{
  printf ("  mSampleRate = %f\n", stream->mSampleRate);
  printf ("  mFormatID = '%c%c%c%c'\n",
	  (char) (stream->mFormatID >> 24) & 0xff,
	  (char) (stream->mFormatID >> 16) & 0xff,
	  (char) (stream->mFormatID >> 8) & 0xff,
	  (char) (stream->mFormatID >> 0) & 0xff);

  printf ("  mFormatFlags: 0x%lx\n", stream->mFormatFlags);
  
#define doit(x) if (stream->mFormatFlags & x) { printf ("    " #x " (0x%x)\n", x); }
  doit (kAudioFormatFlagIsFloat);
  doit (kAudioFormatFlagIsBigEndian);
  doit (kAudioFormatFlagIsSignedInteger);
  doit (kAudioFormatFlagIsPacked);
  doit (kAudioFormatFlagIsAlignedHigh);
  doit (kAudioFormatFlagIsNonInterleaved);
  doit (kAudioFormatFlagsAreAllClear);
#undef doit

#define doit(x) printf ("  " #x " = %ld\n", stream->x)
  doit (mBytesPerPacket);
  doit (mFramesPerPacket);
  doit (mBytesPerFrame);
  doit (mChannelsPerFrame);
  doit (mBitsPerChannel);
#undef doit
}


//NSString* ZKMRNSphericalEventPboardType = @"ZKMRNSphericalEventPboardType";
//NSString* ZKMRNCartesianEventPboardType = @"ZKMRNCartesianEventPboardType";
NSString* ZKMRNEventArrayPboardType = @"ZKMRNEventArrayPboardType";

//  Internal Extensions to Conduits to Support Tree Controllers
@interface ZKMORConduit (ZKMORConduitTreeControllerSupport)
- (NSArray *)children;
- (NSString *)treeControlerString;
@end

@interface ZKMOROutputBus (ZKMORConduitTreeControllerSupport)
- (NSArray *)children;
- (NSString *)treeControlerString;
@end

@interface ZKMORGraph (ZKMORConduitTreeControllerSupport)
- (NSArray *)children;
@end

@interface ZKMRNPieceDocument (ZKMRNPieceDocumentPrivate)
//- (void)privateSetCurrentTime:(Float64)currentTime;
- (void)synchronizePannerSourcesWithSpatializerView;
- (void)activatePannerSources;
- (void)activateDirectOuts;
- (void)addEventsToScheduler;
- (NSArray *)orderedDirectOuts;
- (void)synchronizeChannelsToMixer;
- (void)managedObjectContextChanged:(NSNotification *)notification;
- (void)refreshEvents;
@end

@implementation ZKMRNPieceDocument
#pragma mark _____ NSPersistentDocument Overrides
- (void)dealloc
{
	if ([_system playingPiece] == self) {
		[_system setPlaying: NO];
		[_system setPlayingPiece: nil];
	}
		
	if (_pieceGraph) [_pieceGraph release];
	if (_pannerSources) [_pannerSources release];
	if (_timeWatch) [_timeWatch release];
	
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (id)init 
{
    if (!(self = [super init])) return nil;

	// returns global zirkonium system pointer
	_system = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	_pieceGraph = [[ZKMORGraph alloc] init];
	_pieceMixer = [[ZKMORMixerMatrix alloc] init];
	//_currentTime = 0.;
	_isGraphOutOfSynch = YES;
	
	_timeWatch  = [[ZKMRNTimeWatch alloc] initWithPiece:self];
	_chordController = [[ZKMRNSpatialChordController alloc] initWithPieceDocument: self];
	
    return self;
}

- (id)managedObjectModel
{
	NSBundle *bundle = [NSBundle mainBundle];
    NSString *modelPath = [bundle pathForResource: @"PieceDocument" ofType: @"momd"];
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL: [NSURL fileURLWithPath: modelPath]];
	
    return managedObjectModel;
}


// From NSDocument Reference: You can override this method to perform initialization that must be done when creating 
// new documents but should not be done when opening existing documents. 
// Your override should typically invoke super, or at least it must invoke init, the NSDocument designated initializer,
// to initialize the NSDocument private instance variables.

- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
	if (!(self = [super initWithType: typeName error: outError])) return nil;
	
	// we are creating a new empty document -- generate a Graph object
	NSManagedObjectContext* moc = [self managedObjectContext];
	[[moc undoManager] disableUndoRegistration];
	[NSEntityDescription
		insertNewObjectForEntityForName: @"Graph"
		inManagedObjectContext: [self managedObjectContext]];
	[moc processPendingChanges];
	[[moc undoManager] enableUndoRegistration];
	
	[self synchronizePatchToGraph];
	return self;
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
		// cd to the import path so file manager operations work correctly
	NSString* parentDir = [[absoluteURL path] stringByDeletingLastPathComponent];
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: parentDir];
	
	NSError* theError = nil;
	NSDictionary* metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:typeName URL:absoluteURL error:&theError];
	
	BOOL versionNeedsGraphChannelIndex = NO; 
	
	NSError* error = nil;
		
	if (kZKMRNPieceVersion != [[metadata valueForKey: kZKMRNPieceVersionKey] unsignedIntValue]) {
		// Upgrade the piece
		
		versionNeedsGraphChannelIndex = YES; 

		// Update metadata of older files (PieceVersion 1 and 2) ...
		
		// try to overwrite the metadata so this file can be opened ...
		
		NSString *legacyMetadataPath = [[NSBundle mainBundle] pathForResource:@"MetadataExample" ofType:@"zrkpxml"];
		id destinationMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:typeName URL:[NSURL fileURLWithPath:legacyMetadataPath] error:&error]; 
		
		NSLog(@"%@", legacyMetadataPath);
		int newVersion = [[destinationMetadata valueForKey: kZKMRNPieceVersionKey] unsignedIntValue]; 
		NSLog(@"Metadata New Version Key:%d", newVersion);
		
		//NSDictionary *destinationMetadata = [NSDictionary dictionaryWithContentsOfFile:legacyMetadataPath];
		
		// backup a copy ...
		NSString *originalPath = [absoluteURL path];
		NSString *legacyPath = [NSString stringWithFormat:@"%@~.%@", [originalPath stringByDeletingPathExtension],[originalPath pathExtension]];
				
		BOOL success;
		success = [[NSFileManager defaultManager] moveItemAtPath: originalPath toPath: legacyPath error: &error];
		
		if(!success) { NSLog(@"Backup not successful %@", error); return nil; }
		
		if (![NSPersistentStoreCoordinator setMetadata:destinationMetadata forPersistentStoreOfType:typeName URL:[NSURL fileURLWithPath:legacyPath isDirectory:NO] error:&error]) {
			NSLog(@"Could not update metadata ...");
			NSLog(@"Error: %@ (%d)", [error domain], [error code]);
			NSAlert *theAlert = [NSAlert alertWithError:error];
			[theAlert runModal]; // Ignore return value.
		} else {
			NSLog(@"Succesfully updated Metadata of File to new Version: %d", newVersion);
		}	
		
		// recreate original file from backup ...
		NSLog(@"Recreating Original From Backup!");
		success = [[NSFileManager defaultManager] moveItemAtPath: legacyPath toPath: originalPath error: &error];
		NSLog(@"Done!");
				
		if(!success) { NSLog(@"Recreation of Backup not successfull"); return nil; }
	}
	
	if (!(self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError])) {
		NSLog(@"Open Error! : %@", *outError);
		return nil;
	}
	
	if (versionNeedsGraphChannelIndex) {
		id aChannel; 
		NSArray* graphChannels = [self orderedGraphChannels];
		unsigned int index = 0;
		for(aChannel in graphChannels) {
			[aChannel setValue:[NSNumber numberWithUnsignedInt:index] forKey:@"graphChannelIndex"];
			index++; 
		}

		// Re-save document ...
		if(![self saveToURL:absoluteURL ofType:typeName forSaveOperation:NSSaveOperation error:&error])
		{
			NSLog(@"Save Document Error!");
			NSAlert *theAlert = [NSAlert alertWithError:error];
			[theAlert runModal]; // Ignore return value.
		} else {
			//[self saveDocument:self];
		}
	}
	
	[self synchronizePatchToGraph];
		
	return self;
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error
{	
    NSMutableDictionary *newStoreOptions =
		(storeOptions == nil) ?
			[NSMutableDictionary dictionary] :
			[storeOptions mutableCopy];
			
    [newStoreOptions setObject: [NSNumber numberWithBool: YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
    [newStoreOptions setObject: [NSNumber numberWithBool: YES] forKey:NSInferMappingModelAutomaticallyOption];

    BOOL success = [super configurePersistentStoreCoordinatorForURL:url ofType:fileType modelConfiguration:configuration storeOptions:newStoreOptions error:error];
	if (!success) {
		if (error) NSLog(@"Could not open file %@ : %@", url, *error);
		return success;
	}
	
	// set the version number for a new document
	NSPersistentStoreCoordinator* psc = [[self managedObjectContext] persistentStoreCoordinator];
	id pStore = [psc persistentStoreForURL: url];
	
	NSMutableDictionary* metadata = [[psc metadataForPersistentStore: pStore] mutableCopy];
	[metadata setObject: [NSNumber numberWithInt: kZKMRNPieceVersion] forKey: kZKMRNPieceVersionKey];
	[psc setMetadata: metadata forPersistentStore: pStore];
	[metadata release];
	
	return success;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)outError
{
	//NSString* parentDir = [[absoluteURL path] stringByDeletingLastPathComponent];
	//[[NSFileManager defaultManager] changeCurrentDirectoryPath: parentDir];

	// set the metadata for an existing document
	NSPersistentStoreCoordinator* psc = [[self managedObjectContext] persistentStoreCoordinator];
	id pStore = [psc persistentStoreForURL: absoluteURL];
	
	NSMutableDictionary* metadata = [[psc metadataForPersistentStore: pStore] mutableCopy];
	[metadata setObject: [NSNumber numberWithInt: kZKMRNPieceVersion] forKey: kZKMRNPieceVersionKey];
	[psc setMetadata: metadata forPersistentStore: pStore];
	[metadata release];
	
	return [super writeToURL: absoluteURL ofType: typeName forSaveOperation: saveOperation originalContentsURL: absoluteOriginalContentsURL error: outError];
}

-(void)makeWindowControllers
{
	ZKMRNPieceDocumentWindowController *windowController = [[ZKMRNPieceDocumentWindowController alloc] initWithWindowNibName:@"ZKMRNPieceDocument" owner:self];
    [windowController autorelease];
    [self addWindowController:windowController];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib: windowController];
    // user interface preparation code
	[spatializerView setDelegate: self];
	[initialSpatializerView setDelegate: self];
	[chordSpatializerView setDelegate: self];
	
	initialSpatializerView.useCamera = YES;
	spatializerView.useCamera = YES;
	visualizerWindowView.useCamera = YES;
	chordSpatializerView.useCamera = YES;
	
	[spatializerView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[initialSpatializerView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[visualizerWindowView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[chordSpatializerView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	
	
	//[spatializerView setShowingMesh:YES];
	
	initialSpatializerView.isShowingInitial = YES; 
	
	//[visualizerWindowView setShowingMesh:YES];
	
	[visualizerWindowView setViewType:kDomeView3DPreviewType]; //FullscreenType];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(managedObjectContextChanged:) name: NSManagedObjectContextObjectsDidChangeNotification object: [self managedObjectContext]];
	
	[self synchronizePannerSourcesWithSpatializerView];
	
	[mainWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
}

- (void)awakeFromNib
{
}

-(NSArray*)groupsContent
{
	NSMutableArray* newArray = [NSMutableArray arrayWithArray:[groupsController arrangedObjects]];
	
	id anObject;
	BOOL containsDummy = NO; 
	for(anObject in newArray) {
		if([[anObject valueForKey:@"displayString"] isEqualToString:@"-"]) {
			containsDummy = YES;
			break;
		}
	}

	if(!containsDummy) {
		id noValueObject = [NSEntityDescription insertNewObjectForEntityForName:@"ChannelGroup" inManagedObjectContext:[self managedObjectContext]];
		[noValueObject setValue:@"-" forKey:@"name"];
	
		[newArray addObject: noValueObject];
	}
	
	return newArray;
}




- (void)presentError:(NSError *)error modalForWindow:(NSWindow *)window delegate:(id)delegate didPresentSelector:(SEL)didPresentSelector contextInfo:(void *)contextInfo
{
	NSError* errorToPresent = error;
	BOOL isMultipleError = (NSCocoaErrorDomain == [error domain]) && (NSValidationMultipleErrorsError == [error code]);
	if (isMultipleError) {
		NSArray* errors = [[error userInfo] objectForKey: NSDetailedErrorsKey];
		if ([errors count] > 0) errorToPresent = [errors objectAtIndex: 0];
	}
	[super presentError: errorToPresent modalForWindow: window delegate: delegate didPresentSelector: didPresentSelector contextInfo: contextInfo];
}

- (void)initializeSpatialChordsState
{
	[self setChordNumberOfPoints: [[self orderedGraphChannels] count]];
	[self setChordSpacing: 1.f];
	[self setChordTransitionTime: 10.f];
}


#pragma mark _____ UI Actions
- (IBAction)togglePlay:(id)sender
{	
	if (![_system isPlaying]) {
		[self willChangeValueForKey: @"playButtonTitle"];
		[self willChangeValueForKey: @"isPlaying"];
		[_system willChangeValueForKey: @"isPlaying"];
			
		if([_system isRecording] && !_isRecording) {
			[_system setRecording: NO];
		}	
		
		if (_isGraphOutOfSynch) [self synchronizePatchToGraph];
		[_system setPlayingPiece: self];
		[self synchronizeCurrentTimeToGraph];		
		[[_system clock] setCurrentTimeSeconds: [_timeWatch currentTime]];
		[self addEventsToScheduler];
		[self activatePannerSources];
		[self activateDirectOuts];
		[self initializeSpatialChordsState];
		[_system setPlaying: YES];
		[spatializerView setPieceIsPlaying:YES];
		[visualizerWindowView setPieceIsPlaying:YES];
		[self setHasProcessedRecording:YES];
	
		[_system didChangeValueForKey: @"isPlaying"];
		[self didChangeValueForKey: @"isPlaying"];
		[self didChangeValueForKey: @"playButtonTitle"];
		
		[self togglePlayButton:YES];

		_isPlaying = YES; 
		
	} else {
	
		if(_isPlaying) {
			[self willChangeValueForKey: @"playButtonTitle"];
			[self willChangeValueForKey: @"isPlaying"];
			[_system willChangeValueForKey: @"isPlaying"];		

			[_system setPlaying: NO];
			[spatializerView setPieceIsPlaying:NO];
			[visualizerWindowView setPieceIsPlaying:NO];
		
			[_system didChangeValueForKey: @"isPlaying"];
			[self didChangeValueForKey: @"isPlaying"];
			[self didChangeValueForKey: @"playButtonTitle"];

			[self togglePlayButton:NO];
			
			_isPlaying = NO; 
		}
	}
	
}

-(void)togglePlayButton:(BOOL)flag
{
	if(flag) {
		[playButton setImage:[NSImage imageNamed:@"Stop.png"]];
	} else {
		[playButton setImage:[NSImage imageNamed:@"Play.png"]];
	}
}

- (IBAction)toggleRecord:(id)sender {

	if (![_system isRecording]) {
		[_system setCurrentPieceDocument:self];
		[_system setPlayingPiece:self];

		[_system setRecording: YES];
		_isRecording = YES;
		[self setHasProcessedRecording:NO];
		
	} else {
		if(_isRecording) {
			[_system setRecording: NO];
			_isRecording = NO; 
		}
	
	}
}

-(void)toggleRecordButton:(BOOL)flag
{
	if(flag) {
		[recordButton setImage:[NSImage imageNamed:@"RecordOn.png"]];
	} else {
		[recordButton setImage:[NSImage imageNamed:@"RecordOff.png"]];
	}
}

-(BOOL)isRecording
{
	return _isRecording; 
}

-(void)setHasProcessedRecording:(BOOL)flag
{
	_hasProcessedRecording = flag; 
}

-(BOOL)hasProcessedRecording
{
	return _hasProcessedRecording; 
}


- (IBAction)moveTransportToStart:(id)sender
{
	if(![self isPlaying]) {
		[_timeWatch setCurrentPosition:0.];
		[timelineSlider setObjectValue:[NSNumber numberWithFloat:0.0f]];
	}
}

- (IBAction)exportToASCII:(id)sender
{
	NSMutableDictionary* dictionaryRepresentation = [NSMutableDictionary dictionary];
	NSEnumerator* audioSources = [[self orderedAudioSources] objectEnumerator];
	NSMutableArray* sourcesDictArray = [NSMutableArray array];
	NSManagedObject* audioSource;
	while (audioSource = [audioSources nextObject]) {
		NSDictionary* sourceDictRep = [audioSource dictionaryRepresentation];
		NSArray* typedSourceArray = 
			[NSArray arrayWithObjects: 
				[[audioSource entity] name], [NSNumber numberWithInt: (int) audioSource], sourceDictRep, nil];
		[sourcesDictArray addObject: typedSourceArray];
	}
	[dictionaryRepresentation setValue: sourcesDictArray forKey: @"sources"];
	
	NSEnumerator* ids = [[self orderedGraphChannels] objectEnumerator];
	NSMutableArray* idsArray = [NSMutableArray array];
	ZKMRNGraphChannel* channel;
	while (channel = [ids nextObject]) {
		NSArray* idArrayRep = 
			[NSArray arrayWithObjects: 
				[channel valueForKey: @"graphChannelNumber"], [NSNumber numberWithInt: (int) [channel valueForKey: @"source"]], 
				[channel valueForKey: @"sourceChannelNumber"], nil];
		[idsArray addObject: idArrayRep];
	}
	[dictionaryRepresentation setValue: idsArray forKey: @"ids"];	
}

- (IBAction)activateVisualizer:(id)sender
{
	[visualizerWindow makeKeyAndOrderFront: sender];
	[[visualizerWindow contentView] enterFullScreenMode:[NSScreen mainScreen] withOptions:nil];
}

- (IBAction)deactivateVisualizer:(id)sender 
{
	[[visualizerWindow contentView] exitFullScreenModeWithOptions:nil];
	[visualizerWindow close];
}

#pragma mark -

-(IBAction)addChannel:(id)sender
{
	if([uiGraph content])
		[[uiGraph content] addChannel];
}

-(IBAction)removeChannel:(id)sender
{
	if([uiGraph content]) {
		NSNumber* channelNumber = [[[graphChannelsController selectedObjects] objectAtIndex:0] valueForKey:@"graphChannelNumber"];
		[[uiGraph content] removeChannelWithNumber:channelNumber];
	}
}

-(BOOL)canRemoveChannel
{
	if([uiGraph content])
		return [[uiGraph content] canRemoveChannel]; 
	else
		return NO; 
}

#pragma mark -

- (IBAction)copy:(id)sender
{
	NSArray* windowControllers = [self windowControllers];
	if (!windowControllers || [windowControllers count] < 1) return;
	id responder = [[[windowControllers objectAtIndex: 0] window] firstResponder];
	if (!responder || ![responder isKindOfClass: [NSView class]]) return;
	
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	int tag = [(NSView *)responder tag];
	switch (tag) {
		case kPieceDocumentUITag_EventTable:
		{
			ZKMRNEvent* mo;	
			NSArray* selectedObjects = [eventsController selectedObjects];
			unsigned i, count = [selectedObjects count];
			NSMutableArray* plist = [NSMutableArray arrayWithCapacity: count];
			for (i = 0; i < count; ++i) {
				mo = [selectedObjects objectAtIndex: i];
				[plist addObject: [mo dictionaryRepresentation]];
			}
			[pboard declareTypes: [NSArray arrayWithObjects: ZKMRNEventArrayPboardType, NSStringPboardType, nil] owner: self];
			[pboard setPropertyList: plist forType: ZKMRNEventArrayPboardType];
			[pboard setString: [NSString stringWithFormat: @"EventArray %@", plist] forType: NSStringPboardType];
		}	break;
		default:
			break;
	}
}

- (IBAction)paste:(id)sender
{
	NSArray* windowControllers = [self windowControllers];
	if (!windowControllers || [windowControllers count] < 1) return;
	id responder = [[[windowControllers objectAtIndex: 0] window] firstResponder];
	if (!responder || ![responder isKindOfClass: [NSView class]]) return;
	
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	NSManagedObjectContext* moc = [self managedObjectContext];	
	int tag = [(NSView *)responder tag];
	switch (tag) {
		NSManagedObject* mo;
		NSArray* eventList;
		case kPieceDocumentUITag_EventTable:
		{
			NSString* availableType = [pboard availableTypeFromArray: [NSArray arrayWithObjects: ZKMRNEventArrayPboardType, nil]];
			if (!availableType) break;
			eventList = [pboard propertyListForType: ZKMRNEventArrayPboardType];
			unsigned i, count = [eventList count];
			for (i = 0; i < count; ++i) {
				NSDictionary* dictRepresentation = [eventList objectAtIndex: i];
				NSString* eventType = [dictRepresentation objectForKey: @"eventType"];
				if ([@"ZKMRNCartesianEvent" isEqualToString: eventType]) {
					mo = [NSEntityDescription insertNewObjectForEntityForName: @"CartesianEvent" inManagedObjectContext: moc];
					[mo setFromDictionaryRepresentation: dictRepresentation];
					[eventsController addObject: mo];
				} else if ([@"ZKMRNPositionEvent" isEqualToString: eventType]) {
					mo = [NSEntityDescription insertNewObjectForEntityForName: @"PositionEvent" inManagedObjectContext: moc];
					[mo setFromDictionaryRepresentation: dictRepresentation];
					[eventsController addObject: mo];
				} else {
					ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Paste of unknown event type"));
				}
			}
		}	break;
		default:
			break;
	}
}

- (IBAction)startChord:(id)sender
{
	[_chordController startChord];
}

- (IBAction)setChordNumberOfPointsTo1:(id)sender { [self setChordNumberOfPoints: 1]; }
- (IBAction)setChordNumberOfPointsTo2:(id)sender { [self setChordNumberOfPoints: 2]; }
- (IBAction)setChordNumberOfPointsTo3:(id)sender { [self setChordNumberOfPoints: 3]; }

#pragma mark _____ Accessors
- (NSSet*)graphDirectOuts {
	return [[self piecePatch] valueForKey:@"directOutChannels"];
}

- (ZKMORGraph *)pieceGraph { return _pieceGraph; }
- (ZKMORMixerMatrix *)pieceMixer { return _pieceMixer; }
- (NSArray *)pannerSources { return _pannerSources; }
- (NSManagedObject *)piecePatch 
{ 
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"Graph" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return [array lastObject];
}

- (unsigned)numberOfChannels { return [[[self piecePatch] valueForKey: @"numberOfChannels"] unsignedIntValue]; }
- (unsigned)numberOfDirectOuts { return [[[self piecePatch] valueForKey: @"numberOfDirectOuts"] unsignedIntValue]; }

#pragma mark _____ Actions
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain
{
	if (channel >= [_pannerSources count]) return;
	ZKMNRPannerSource* source = [_pannerSources objectAtIndex: channel];
	if ([self isPlaying]) {
		[source setCenter: center span: span gain: gain];
		
		// no need to update the display -- that will happen in due time.
		// TODO RECORD -- Record the event if we are recording		
	} else {
		[source setInitialCenter: center span: span gain: gain];
		[initialSpatializerView	setNeedsDisplay: YES];
	}
}

- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain
{
	// find the nearest speaker
	ZKMNRSpeakerPosition* speakerPos = [[_system panner] speakerClosestToPoint: center];
	if (!speakerPos) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find speaker near point { %.2f, %.2f, %.2f}"), center.azimuth, center.zenith, center.radius);
		return;
	}

	// pan to that speaker
	ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
	[self panChannel: channel az: [speakerPos coordPlatonic] span: span gain: gain];
}

- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain
{
	ZKMNRSphericalCoordinate sphericalCenter = ZKMNRPlanarCoordinateLiftedToSphere(center);
	// find the nearest speaker
	ZKMNRSpeakerPosition* speakerPos = [[_system panner] speakerClosestToPoint: sphericalCenter];
	if (!speakerPos) {
//		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find speaker near point { %.2f, %.2f, %.2f}"), sphericalCenter.azimuth, sphericalCenter.zenith, sphericalCenter.radius);
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find speaker near point { %.2f, %.2f, %.2f}"), center.x, center.y, center.z);
		return;
	}

	// pan to that speaker
	ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
	[self panChannel: channel az: [speakerPos coordPlatonic] span: span gain: gain];
}

- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain
{
	if (channel >= [_pannerSources count]) return;
	ZKMNRPannerSource* source = [_pannerSources objectAtIndex: channel];
	[source setCenterRectangular: center span: span gain: gain];
	[spatializerView setNeedsDisplay: YES];
}

#pragma mark _____ UI Accessors
- (float)fontSize { return 11.f; }

- (BOOL)isInputOn 
{
	NSArray* array = [self inputSources];
	if (!array) return NO;
	return [array count] > 0;
}

- (void)setInputOn:(BOOL)isInputOn
{
	if (isInputOn) {
		id input = 
		[NSEntityDescription
		 insertNewObjectForEntityForName: @"InputSource"
		 inManagedObjectContext: [self managedObjectContext]];
		[input setValue: @"Input" forKey: @"name"];
	} else {
		NSManagedObjectContext* moc = [self managedObjectContext];
		NSArray* array = [self inputSources];
		NSEnumerator* arrayEnumerator = [array objectEnumerator];
		NSManagedObject* managedObject;
		while (managedObject = [arrayEnumerator nextObject]) {
			[moc deleteObject: managedObject];
		}	
	}
}

/*
- (BOOL)isExternalOn 
{
	NSArray* array = [self externalSources];
	if (!array) return NO;
	return [array count] > 0;
}

- (void)setExternalOn:(BOOL)isExternalOn
{
	if (isExternalOn) {
		id external = 
		[NSEntityDescription
		 insertNewObjectForEntityForName: @"ExternalSource"
		 inManagedObjectContext: [self managedObjectContext]];
		[external setValue: @"External" forKey: @"name"];
	} else {
		NSManagedObjectContext* moc = [self managedObjectContext];
		NSArray* array = [self externalSources];
		NSEnumerator* arrayEnumerator = [array objectEnumerator];
		NSManagedObject* managedObject;
		while (managedObject = [arrayEnumerator nextObject]) {
			[moc deleteObject: managedObject];
		}	
	}
}
*/


- (BOOL)isTestSourceOn
{
	NSArray* array = [self testSources];
	if (!array) return NO;
	return [array count] > 0;
}

- (void)setTestSourceOn:(BOOL)isTestSourceOn
{
	if (isTestSourceOn) {
		id testSource = 
			[NSEntityDescription
				insertNewObjectForEntityForName: @"TestSource"
				inManagedObjectContext: [self managedObjectContext]];
		[testSource setValue: @"Test Tone" forKey: @"name"];
	} else {
		NSManagedObjectContext* moc = [self managedObjectContext];
		NSArray* array = [self testSources];
		NSEnumerator* arrayEnumerator = [array objectEnumerator];
		NSManagedObject* managedObject;
		while (managedObject = [arrayEnumerator nextObject]) {
			[moc deleteObject: managedObject];
		}	
	}
}

- (BOOL)isFixedDuration
{
	// if the only input sources are files, then the piece is of fixed duration
	NSArray* sources = [self orderedAudioSources];
	unsigned i, sourcesCount = [sources count];	
	if (!sources || (sourcesCount < 1)) {
		return 0;
	}

	for (i = 0; i < sourcesCount; i++)
		if (![[sources objectAtIndex: i] isKindOfClass: [ZKMRNFileSource class]]) return NO;
	
	return YES;
}

- (void)setFixedDuration:(BOOL)isFixedDuration { }

-(ZKMRNTimeWatch*)timeWatch 
{
	return _timeWatch; 
}

-(void)synchronizePosition
{
	// for live update of glView ...
	if (_isGraphOutOfSynch) {
		[self synchronizePatchToGraph];
	}
	
	// set me as playing piece ...
	[_system setPlayingPiece: self];
	
	// synchronize time to graph ... ?
	[self synchronizeCurrentTimeToGraph];
	
	// set the clock ...
	[[_system clock] setCurrentTimeSeconds: [_timeWatch currentTime]];

	//prepare events and sources ...
	[self addEventsToScheduler];
	[self activatePannerSources];
	[self activateDirectOuts];
	
	// do the task for current time ...
	[[_system scheduler] task: [_system spatializationTimerInterval]];
	
	// update the view ...
	if(![self isPlaying])
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ZKMRNSpatializerViewShouldUpdate" object:nil]; 
}
- (NSArray *)graphChannelSortDescriptors
{
	NSSortDescriptor* sortDesc = [[NSSortDescriptor alloc] initWithKey: @"graphChannelNumber" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: sortDesc];
	[sortDesc release];
	return descriptors;
}
- (void)setGraphChannelSortDescriptors:(NSArray *)graphChannelSortDescriptors { }  // Ignore

- (NSArray *)directOutSortDescriptors
{
	NSSortDescriptor* sortDesc = [[NSSortDescriptor alloc] initWithKey: @"directOutNumber" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: sortDesc];
	[sortDesc release];
	return descriptors;
}
- (void)setDirectOutSortDescriptors:(NSArray *)directOutSortDescriptors { }

- (NSArray *)eventSortDescriptors
{
	NSSortDescriptor* timeDesc = [[NSSortDescriptor alloc] initWithKey: @"startTime" ascending: YES];
	NSSortDescriptor* targetDesc = [[NSSortDescriptor alloc] initWithKey: @"container.displayString" ascending: YES];	
	NSArray* descriptors = [NSArray arrayWithObjects: timeDesc, targetDesc, nil];
	[timeDesc release]; [targetDesc release];
	return descriptors;
}
- (void)setEventSortDescriptors:(NSArray *)eventSortDescriptors { }  // Ignore
- (ZKMRNZirkoniumSystem *)zirkoniumSystem { return _system; }

#pragma mark _____ Queries
- (BOOL)isPlaying { return [_system isPlaying]; }

- (NSString *)playButtonTitle { return ([self isPlaying]) ? @"Stop" : @"Play"; }

- (NSPredicate *)filteredGroupsPredicate
{
	return [NSPredicate predicateWithFormat:@"displayString != %@", @"-"];
}

#pragma mark _____ Display Update
- (void)tick:(id)timer
{
	if([self isFixedDuration])
	{
		//automatically stop at end
		if([_timeWatch currentTime]<=[_timeWatch duration]) {
			[_timeWatch setCurrentTime: [[_system clock] currentTimeSeconds]];
		}
		else {
			[_timeWatch setCurrentTime: [_timeWatch duration]];
			[self togglePlay:self];
		}
	} else {
		[_timeWatch setCurrentTime: [[_system clock] currentTimeSeconds]];
	}
	[timelineSlider setObjectValue:[NSNumber numberWithFloat:[_timeWatch currentPosition]]];
	
	[spatializerView setNeedsDisplay: YES];
	[initialSpatializerView setNeedsDisplay: YES];
	[visualizerWindowView setNeedsDisplay: YES];
	[chordSpatializerView setNeedsDisplay: YES];
}

#pragma mark _____ ZKMRNPieceDocumentInternal
- (NSArray *)inputSources
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"InputSource" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return array;
}

/*
- (NSArray *)externalSources
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"ExternalSource" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return array;
}
*/


- (NSArray *)testSources
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"TestSource" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return array;
}

- (NSArray *)orderedGraphChannels
{
	NSSet* graphChannels = [[self piecePatch] valueForKey: @"graphChannels"];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"graphChannelNumber" ascending: YES];
	NSArray* orderedGraphChannels = [[graphChannels allObjects] sortedArrayUsingDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	return orderedGraphChannels;
}

- (void)synchronizePatchToGraph
{
	NSArray* sources = [self orderedAudioSources];
	if (!sources || ([sources count] < 1)) {
		[_pieceGraph beginPatching];
			[_pieceMixer uninitialize];
			[_pieceMixer setNumberOfOutputBuses: 1];
			[_pieceMixer setNumberOfInputBuses: 1];
			[_pieceGraph setHead: _pieceMixer];
			[_pieceGraph disconnectOutputToInputBus: [_pieceMixer inputBusAtIndex: 0]];
			[_pieceGraph initialize];
		[_pieceGraph endPatching];
		[graphBrowser reloadColumn: 0];
		[_pieceMixer willChangeValueForKey: @"children"];
		[_pieceMixer didChangeValueForKey: @"children"];		
		return;
	}

	unsigned i, sourcesCount = [sources count];
	[_pieceGraph beginPatching];
		[_pieceMixer uninitialize];
		[_pieceMixer setNumberOfOutputBuses: 1];
		AudioStreamBasicDescription streamFormat = [[_pieceMixer outputBusAtIndex: 0] streamFormat];
		ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, [self numberOfChannels] + [self numberOfDirectOuts]);
		[[_pieceMixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
		//print_stream_info(&streamFormat);
		[_pieceMixer setNumberOfInputBuses: sourcesCount];
		[_pieceGraph setHead: _pieceMixer];
		for (i = 0; i < sourcesCount; i++) {
			if ([[sources objectAtIndex: i] isConduitValid]) {
				ZKMORConduit* conduit = [[sources objectAtIndex: i] conduit]; 
				[_pieceGraph patchBus: [conduit outputBusAtIndex: 0] into: [_pieceMixer inputBusAtIndex: i]];
			} else {
				[_pieceGraph disconnectOutputToInputBus: [_pieceMixer inputBusAtIndex: i]];
			}
		}
		[_pieceGraph initialize];
	[_pieceGraph endPatching];
	
	[self synchronizeChannelsToMixer];
	
	[graphBrowser reloadColumn: 0];
	[_pieceMixer willChangeValueForKey: @"children"];
	[_pieceMixer didChangeValueForKey: @"children"];
	_isGraphOutOfSynch = NO;
}

- (void)synchronizeCurrentTimeToGraph
{
	NSArray* sources = [self orderedAudioSources];
	if (!sources || ([sources count] < 1)) return;

	unsigned i, count = [sources count];
		// pause the graph while we are doing this work
	[_pieceGraph beginPatching];
		for (i = 0; i < count; i++) {
			if ([[sources objectAtIndex: i] isConduitValid]) {
				ZKMRNAudioSource* source = [sources objectAtIndex: i];
				[source setCurrentTime: [_timeWatch currentTime]];
			}
		}
	[_pieceGraph endPatching];
}

- (NSArray *)orderedAudioSources
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entityDesc = [NSEntityDescription entityForName: @"AudioSource" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entityDesc];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"name" ascending: YES];
	[request setSortDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	[sortDescriptor release];
	NSError* error = nil;
	NSArray* orderedAudioSources = [moc executeFetchRequest: request error: &error];
	if (!orderedAudioSources) NSLog(@"Error fetching sources %@", error);
	[request release];
	return orderedAudioSources;
}

#pragma mark _____ ZKMRNPieceDocumentPrivate

- (void)synchronizePannerSourcesWithSpatializerView
{
	NSSet* graphChannelSet = [[self piecePatch] valueForKey: @"graphChannels"];
	if (_pannerSources) [_pannerSources release];
	// initialize the pannerSources array
	unsigned i, count = [graphChannelSet count];
	_pannerSources = [[NSMutableArray alloc] initWithCapacity: count];
	for (i = 0; i < count; i++) [_pannerSources addObject: [NSNull null]];
	
	NSEnumerator* graphChannels = [graphChannelSet objectEnumerator];
	ZKMRNGraphChannel* channel;
	while (channel = [graphChannels nextObject]) {
		unsigned index = [[channel valueForKey: @"graphChannelIndex"] unsignedIntValue]; //number to index (JB)
		ZKMNRPannerSource* source = [channel pannerSource];
		[_pannerSources replaceObjectAtIndex: index withObject: source];
	}
	if (spatializerView) [spatializerView setPannerSources: _pannerSources];
	if (initialSpatializerView) [initialSpatializerView setPannerSources: _pannerSources];
	if (visualizerWindowView) [visualizerWindowView setPannerSources: _pannerSources];
	if (chordSpatializerView) [chordSpatializerView setPannerSources: _pannerSources];
	if ([_system isPlaying]) [self activatePannerSources];
}

- (void)activatePannerSources
{
	ZKMNRVBAPPanner* panner = [_system panner];
	[panner setActiveSources: _pannerSources];
	NSEnumerator* sources = [_pannerSources objectEnumerator];
	ZKMNRPannerSource* source;
	while (source = [sources nextObject]) [source moveToInitialPosition];
}

- (void)activateDirectOuts
{
	ZKMORMixerMatrix* spatializationMixer = [_system spatializationMixer];
	unsigned numberOfSpeakers = [[_system speakerSetup] numberOfSpeakers];
	unsigned numberOfChannels = [self numberOfChannels];
	unsigned i;

	NSEnumerator* directOuts = [[self orderedDirectOuts] objectEnumerator];
	NSManagedObject* directOut;
	for (i = 0; directOut = [directOuts nextObject]; ++i) {
		unsigned outputIndex = numberOfSpeakers + [[directOut valueForKey: @"directOutNumber"] unsignedIntValue];
		unsigned sourceIndex = numberOfChannels + i;
		[spatializationMixer setVolume: 1.f forCrosspointInput: sourceIndex output: outputIndex];
	}
}

- (void)addEventsToScheduler
{
	ZKMNREventScheduler* scheduler = [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] scheduler];
	[scheduler unscheduleAllEvents];
	NSEnumerator* positionEvents = [[self orderedPositionEvents] objectEnumerator];
	ZKMRNEvent* event;
	while (event = [positionEvents nextObject]) {
		[event scheduleEvents: scheduler];
	}
}

- (NSArray *)orderedPositionEvents
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entityDesc = [NSEntityDescription entityForName: @"Event" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entityDesc];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"startTime" ascending: YES];
	[request setSortDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	[sortDescriptor release];
	NSError* error = nil;
	NSArray* orderedPositionEvents = [moc executeFetchRequest: request error: &error];
	if (!orderedPositionEvents) NSLog(@"Error fetching position events %@", error);
	[request release];
	return orderedPositionEvents;
}



- (NSArray *)orderedDirectOuts
{
	NSSet* directOutChannels = [[self piecePatch] valueForKey: @"directOutChannels"];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"directOutNumber" ascending: YES];
	NSArray* orderedDirectOuts = [[directOutChannels allObjects] sortedArrayUsingDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	return orderedDirectOuts;
}

- (void)synchronizeChannelsToMixer
{
	[_pieceMixer setInputsAndOutputsOn];
	[_pieceMixer setCrosspointsToZero];
	NSEnumerator* graphChannels = [[self orderedGraphChannels] objectEnumerator];
	NSArray* sources = [self orderedAudioSources];
	NSManagedObject* graphChannel;
	while (graphChannel = [graphChannels nextObject]) {
		unsigned outputIndex = [[graphChannel valueForKey: @"graphChannelIndex"] unsignedIntValue];	//number to index (JB)
		NSManagedObject* source;
		if (!(source = [graphChannel valueForKey: @"source"])) continue;
		
		unsigned sourceIndex = [sources indexOfObject: source];
		unsigned sourceNumberOfChannels = [[source valueForKey: @"numberOfChannels"] unsignedIntValue];
		ZKMORMixerMatrixInputBus* inputBus = (ZKMORMixerMatrixInputBus *)[_pieceMixer inputBusAtIndex: sourceIndex];
		unsigned inputIndex = [inputBus mixerBusZeroOffset] + ([[graphChannel valueForKey: @"sourceChannelNumber"] unsignedIntValue] % sourceNumberOfChannels);
		[_pieceMixer setVolume: 1.f forCrosspointInput: inputIndex output: outputIndex];
	}
	
	NSEnumerator* directOuts = [[self orderedDirectOuts] objectEnumerator];
	unsigned numberOfChannels = [self numberOfChannels];
	sources = [self orderedAudioSources];
	NSManagedObject* directOut;
	while (directOut = [directOuts nextObject]) {
		unsigned outputIndex = numberOfChannels + [[directOut valueForKey: @"directOutNumber"] unsignedIntValue];	
		NSManagedObject* source;
		if (!(source = [directOut valueForKey: @"source"])) continue;
		
		unsigned sourceIndex = [sources indexOfObject: source];
		unsigned sourceNumberOfChannels = [[source valueForKey: @"numberOfChannels"] unsignedIntValue];
		ZKMORMixerMatrixInputBus* inputBus = (ZKMORMixerMatrixInputBus *)[_pieceMixer inputBusAtIndex: sourceIndex];
		unsigned inputIndex = [inputBus mixerBusZeroOffset] + ([[directOut valueForKey: @"sourceChannelNumber"] unsignedIntValue] % sourceNumberOfChannels);
		[_pieceMixer setVolume: 1.f forCrosspointInput: inputIndex output: outputIndex];
	}
}


- (void)managedObjectContextChanged:(NSNotification *)notification
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* audioSourceEntity = [NSEntityDescription entityForName: @"AudioSource" inManagedObjectContext: moc];
	NSEntityDescription* graphChannelEntity = [NSEntityDescription entityForName: @"GraphChannel" inManagedObjectContext: moc];
	NSEntityDescription* directOutChannelEntity = [NSEntityDescription entityForName: @"DirectOutChannel" inManagedObjectContext: moc];
	NSEntityDescription* eventEntity = [NSEntityDescription entityForName: @"Event" inManagedObjectContext: moc];
	BOOL audioSourcesChanged = NO, graphChannelsChanged = NO, directOutChannelsChanged = NO, eventChanged = NO;
		
	NSDictionary* userInfo = [notification userInfo];
	NSEnumerator* objects;	
	NSManagedObject* object;
			// check the inserted objects
	objects  = [[userInfo objectForKey: NSInsertedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([[audioSourceEntity subentities] containsObject: [object entity]]) audioSourcesChanged = YES;
		if ([graphChannelEntity isEqualTo: [object entity]]) graphChannelsChanged = YES;
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if ([[eventEntity subentities] containsObject: [object entity]]) eventChanged = YES;
	}
		// check the deleted objects
	objects  = [[userInfo objectForKey: NSDeletedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([[audioSourceEntity subentities] containsObject: [object entity]]) audioSourcesChanged = YES;
		if ([graphChannelEntity isEqualTo: [object entity]]) graphChannelsChanged = YES;
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if ([[eventEntity subentities] containsObject: [object entity]]) eventChanged = YES;		
	}
	
	BOOL graphChannelsWereCreatedOrDestroyed = graphChannelsChanged;
	
		// check the modified objects
	objects  = [[userInfo objectForKey: NSUpdatedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([[audioSourceEntity subentities] containsObject: [object entity]]) audioSourcesChanged = YES;
		if ([graphChannelEntity isEqualTo: [object entity]]) graphChannelsChanged = YES;
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if ([[eventEntity subentities] containsObject: [object entity]]) eventChanged = YES;
	}
	
	if (graphChannelsWereCreatedOrDestroyed) [self synchronizePannerSourcesWithSpatializerView];
	
	_isGraphOutOfSynch = _isGraphOutOfSynch || audioSourcesChanged || graphChannelsChanged || directOutChannelsChanged;
	if (eventChanged) {
		[self refreshEvents];
	}
	if (audioSourcesChanged) {
		// the argument doesn't matter -- this is just to trigger a refresh
		[self setFixedDuration: [self isFixedDuration]];
	}
	
	if(directOutChannelsChanged)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ZKMRNOutputPatchChangedNotification" object:nil];

}

- (void)refreshEvents
{
	[self addEventsToScheduler];
}

#pragma mark -
#pragma mark File Sources Array Controller Delegate
#pragma mark -

-(BOOL)canAddFileSource
{
	if([self fileURL]) 
		return YES;
	
	NSInteger returnValue = NSRunAlertPanel(@"Document unsaved!", @"Please save document before adding file sources. This ensures that relative filepaths are handled correctly.", @"OK", @"Cancel", nil);
	
	if(returnValue==NSAlertDefaultReturn) {

		// Launch Save Panel ...		
		[self saveDocument:self];
		
	} 
	
	return NO; 
}

#pragma mark -
#pragma mark Drag and Drop
#pragma mark -

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
	
	
	BOOL lookingAtSources = [@"sources" isEqualTo: [[mainTabView selectedTabViewItem] identifier]];
	NSMutableArray* sources = (lookingAtSources) ? [NSMutableArray arrayWithArray: [fileSourcesController selectedObjects]] : [NSMutableArray array];	
	unsigned sourcesCount = [sources count];
	NSArray* files = [pboard propertyListForType: NSFilenamesPboardType];
	unsigned filesCount = [files count];

	if(![self canAddFileSource])
		return NO; 
	
	
	
	while (sourcesCount < filesCount) {
		id addedSource = [NSEntityDescription insertNewObjectForEntityForName: @"FileSource" inManagedObjectContext: [self managedObjectContext]];
		[fileSourcesController addObject: addedSource];
		[sources addObject: addedSource];
		++sourcesCount;
	}
	


	unsigned i;
	for (i = 0; i < sourcesCount; i++) {
		if (i < filesCount) {
			ZKMRNFileSource* source = [sources objectAtIndex: i];
			NSString* audioPath = [files objectAtIndex: i]; 
			NSString* documentPath = [[self fileURL] path]; 
			
			NSString* audioDir		= [audioPath stringByDeletingLastPathComponent];
			NSString* documentDir	= [documentPath stringByDeletingLastPathComponent];	
			
			[[NSFileManager defaultManager] changeCurrentDirectoryPath: documentDir];		
			
			NSString* audioFilename = [audioPath lastPathComponent];
			
			NSString* relativePath; 
						
			BOOL sameDir = [audioDir isEqualToString:documentDir]; 

			if(!sameDir) {
				relativePath = [NSString stringWithFormat:@"%@/%@", [audioDir relativePathFromBaseDirPath:documentDir], audioFilename];
			} else {
				relativePath = audioFilename; 
			}
			
			[source setPath: relativePath];
		}
	}
	
	
	[mainTabView selectFirstTabViewItem: sender];
	
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{

}

#pragma mark -
#pragma mark Events TableView Delegate Methods
#pragma mark -

-(void)tableViewSelectionDidChange:(NSNotification*)inNotification
{
	if([self isPlaying]) return; 
	
	NSTableView* eventsTable = [inNotification object];
	unsigned int index; 
	index = ([eventsTable numberOfSelectedRows]==0) ? 0 : [[eventsTable selectedRowIndexes] lastIndex];
	
	//forward selectedObject to Piece Document
	int  startMM = 0, startSS = 0, startMS = 0; 
	if([eventsTable numberOfSelectedRows]!=0)
	{
		NSArray* selectedObjects = [eventsController selectedObjects];
		ZKMRNEvent* lastEvent = [selectedObjects lastObject];
		
		startMM  = [[lastEvent startTimeMM] intValue];
		startSS  = [[lastEvent startTimeSS] intValue];
		startMS  = [[lastEvent startTimeMS] intValue];
	}
	
	float timeInS = startMM * 60.0f + startSS + (startMS / 1000.0);
	
	if([_timeWatch duration] <= 0.0)
		return;
	
	[_timeWatch setCurrentPosition:(timeInS / [_timeWatch duration])];
}


#pragma mark _____ NSWindow Delegate 
- (void)windowWillClose:(NSNotification *)notification
{
	spatializerView = nil;
	initialSpatializerView = nil;
	visualizerWindowView = nil;
	chordSpatializerView = nil;
	[mainWindow unregisterDraggedTypes];
	if (self == [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] currentPieceDocument])
		[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] setCurrentPieceDocument: nil];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] setCurrentPieceDocument:self];
}

#pragma mark -
#pragma mark ZKMRNPieceDocumentSpatialChords

- (NSUInteger)chordNumberOfPoints { return [_chordController chordNumberOfPoints]; }
- (void)setChordNumberOfPoints:(NSUInteger)chordNumberOfPoints { [_chordController setChordNumberOfPoints: chordNumberOfPoints]; }
- (float)chordSpacing { return [_chordController chordSpacing]; }
- (void)setChordSpacing:(float)chordSpacing { [_chordController setChordSpacing: chordSpacing]; }
- (float)chordTransitionTime { return [_chordController chordTransitionTime]; }
- (void)setChordTransitionTime:(float)chordTransitionTime { [_chordController setChordTransitionTime: chordTransitionTime]; }



#pragma mark -
#pragma mark SpatializerViewDelegate

- (void)view:(ZKMRNDomeView *)domeView selectedPannerSource:(ZKMNRPannerSource *)pannerSource 
{
	if (domeView == spatializerView) return;
	[graphChannelsController setSelectedObjects: [NSArray arrayWithObject: [pannerSource tag]]];
}

- (void)view:(ZKMRNDomeView *)domeView movedPannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point
{
	if (domeView == spatializerView) return;
	ZKMRNGraphChannel* channel = [pannerSource tag];
	[channel setValue: [NSNumber numberWithFloat: point.azimuth] forKey: @"initialAzimuth"];
	[channel setValue: [NSNumber numberWithFloat: point.zenith] forKey: @"initialZenith"];
	[pannerSource setCenter: point];
}
- (void)view:(ZKMRNDomeView *)domeView finishedMovePannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point { }

#pragma mark _____ NSBrowserDelegate
- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column
{
	int numberOfRows = (0 == column) ? [_pieceMixer numberOfInputBuses] : 0;
	return numberOfRows;
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
	NSBrowserCell* browserCell = (NSBrowserCell *)cell;
	[browserCell setLeaf: YES];
	if (0 == column) {
		ZKMORConduitBus* bus = [_pieceGraph sourceForInputBus: [_pieceMixer inputBusAtIndex: row]];
		[browserCell setTitle: [NSString stringWithFormat: @"%@:%u", [bus conduit], [bus busNumber]]];
	}
}

#pragma mark -
#pragma mark NSDocument Overrides
// Fix for a bug. See: http://lists.apple.com/archives/Cocoa-dev/2007/Nov/msg00158.html
- (IBAction)saveDocument:(id)sender
{
    if ([[self managedObjectContext] hasChanges]) {
		[super saveDocument:sender];
    }
}

@end

@implementation ZKMORConduit (ZKMORConduitTreeControllerSupport)
- (NSArray *)children
{
	NSMutableArray* children = [NSMutableArray array];
	unsigned i, count = [self numberOfInputBuses];
	for (i = 0; i < count; i++) {
		ZKMOROutputBus* sourceBus = [[self graph] sourceForInputBus: [self inputBusAtIndex: i]];
		if (sourceBus) [children addObject: sourceBus];
	}
	return children;
}
- (NSString *)treeControlerString
{
	NSString* classString = NSStringFromClass([self class]);
	return  [NSString stringWithFormat: @"<%@:0x%x>", classString, (unsigned)self];
}
@end

@implementation ZKMOROutputBus (ZKMORConduitTreeControllerSupport)
- (NSArray *)children
{
	NSArray* children = [[self conduit] children];
	return children;
}
- (NSString *)treeControlerString
{
	NSString* classString = NSStringFromClass([[self conduit] class]);
	return  [NSString stringWithFormat: @"<%@:0x%x>:%u", classString, (unsigned)[self conduit], [self busNumber]];
}
@end


@implementation ZKMORGraph (ZKMORConduitTreeControllerSupport)
- (NSArray *)children
{
	if (![self head]) return nil;
	
	NSArray* children = [NSArray arrayWithObject: [self head]];
	return children;
}
@end
