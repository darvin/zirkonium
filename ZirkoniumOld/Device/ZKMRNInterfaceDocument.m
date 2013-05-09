//
//  ZKMRNInterfaceDocument.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import "ZKMRNInterfaceDocument.h"
#import "ZKMRNZirkoniumUISystem.h"
#import "ZKMRNGraphChannel.h"
#import "ZKMRNDomeView.h"
#import "ZKMRNPositionEvent.h"
#import "ZKMRNAudioSource.h"
#import "ZKMRNFileSource.h"
#import "ZKMRNFileV1Importer.h"
#import "ZKMRNManagedObjectExtensions.h"

static NSString* kZKMRNPieceVersionKey = @"ZKMRNPieceVersionKey";
static unsigned kZKMRNPieceVersion = 1;

@interface ZKMRNInterfaceDocument (ZKMRNPieceDocumentPrivate)
- (void)privateSetCurrentTime:(Float64)currentTime;
- (void)synchronizePannerSourcesWithSpatializerView;
- (void)activatePannerSources;
- (void)activateDirectOuts;
- (void)addEventsToScheduler;
- (NSArray *)orderedAudioSources;
- (NSArray *)orderedDirectOuts;
- (void)synchronizeChannelsToMixer;
- (void)synchronizeCurrentTimeToGraph;
- (void)managedObjectContextChanged:(NSNotification *)notification;
@end

@implementation ZKMRNInterfaceDocument
#pragma mark _____ NSPersistentDocument Overrides
- (void)dealloc
{
	if (_pieceGraph) [_pieceGraph release];
	if (_pannerSources) [_pannerSources release];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (id)init 
{
    if (!(self = [super init])) return nil;

	_system = (ZKMRNZirkoniumUISystem *) [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	_pieceGraph = [[ZKMORGraph alloc] init];
	_pieceMixer = [[ZKMORMixerMatrix alloc] init];
	_currentTime = 0.;
	_isGraphOutOfSynch = YES;

    return self;
}

- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
	if (!(self = [super initWithType: typeName error: outError])) return nil;
	
	// we are creating a new empty document -- generate a Graph object
	[NSEntityDescription
		insertNewObjectForEntityForName: @"Graph"
		inManagedObjectContext: [self managedObjectContext]];
	
	[self synchronizePatchToGraph];
	return self;
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
		// cd to the import path so file manager operations work correctly
	NSString* parentDir = [[absoluteURL path] stringByDeletingLastPathComponent];
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: parentDir];
	
	if (!(self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError])) return nil;
	
	[self synchronizePatchToGraph];
	
	NSPersistentStoreCoordinator* psc = [[self managedObjectContext] persistentStoreCoordinator];
	id pStore = [psc persistentStoreForURL: absoluteURL];
	
	NSDictionary* metadata = [psc metadataForPersistentStore: pStore];
	if (kZKMRNPieceVersion != [[metadata valueForKey: kZKMRNPieceVersionKey] unsignedIntValue]) {
		NSLog(@"Opening object with unknown version %@", [metadata valueForKey: kZKMRNPieceVersionKey]);
	}
	return self;
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType error:(NSError **)error
{
	BOOL success = [super configurePersistentStoreCoordinatorForURL: url ofType: fileType error: error];
	if (!success) return NO;

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
	// set the metadata for an existing document
	NSPersistentStoreCoordinator* psc = [[self managedObjectContext] persistentStoreCoordinator];
	id pStore = [psc persistentStoreForURL: absoluteURL];
	
	NSMutableDictionary* metadata = [[psc metadataForPersistentStore: pStore] mutableCopy];
	[metadata setObject: [NSNumber numberWithInt: kZKMRNPieceVersion] forKey: kZKMRNPieceVersionKey];
//	[metadata setObject: keywords forKey: kMDItemKeywords];
//  kMDItemTitle, kMDItemDurationSeconds, kMDItemCodecs, kMDItemTotalBitRate, kMDItemAudioBitRate, kMDItemWhereFroms
	[psc setMetadata: metadata forPersistentStore: pStore];
	[metadata release];
	
	return [super writeToURL: absoluteURL ofType: typeName forSaveOperation: saveOperation originalContentsURL: absoluteOriginalContentsURL error: outError];
}

- (NSString *)windowNibName 
{
    return @"ZKMRNInterfaceDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib: windowController];
    // user interface preparation code
}


- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{

}

- (void)awakeFromNib
{
	[spatializerView setDelegate: self];
	[initialSpatializerView setDelegate: self];
	[initialSpatializerView setShowingInitial: YES];
	[spatializerView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[initialSpatializerView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(managedObjectContextChanged:) name: NSManagedObjectContextObjectsDidChangeNotification object: [self managedObjectContext]];
	[self synchronizePannerSourcesWithSpatializerView];
	
	[mainWindow registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}

#pragma mark _____ UI Actions
- (IBAction)togglePlay:(id)sender
{
	if (![_system isPlaying]) {
		if (_isGraphOutOfSynch) [self synchronizePatchToGraph];
		[_system setPlayingPiece: self];
		[self synchronizeCurrentTimeToGraph];		
		[[_system clock] setCurrentTimeSeconds: _currentTime];
		[self addEventsToScheduler];
		[self activatePannerSources];
		[self activateDirectOuts];
		[_system setPlaying: YES];
	} else {
		[_system setPlaying: NO];
	}
}

- (IBAction)moveTransportToStart:(id)sender
{
	[self privateSetCurrentTime: 0.];
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];
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
	NSLog(@"\n%@", dictionaryRepresentation);
}

#pragma mark _____ Accessors
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
- (void)panChannel:(unsigned)channel center:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain
{
	if (channel >= [_pannerSources count]) return;
	ZKMNRPannerSource* source = [_pannerSources objectAtIndex: channel];
	if ([self isPlaying]) {
		[source setCenter: center span: span gain: gain];
		// TODO -- Record the event if we are recording
		[spatializerView setNeedsDisplay: YES];
	} else {
		[source setInitialCenter: center span: span gain: gain];
		[initialSpatializerView	setNeedsDisplay: YES];
	}
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
	NSNumber* duration = [[self piecePatch] valueForKey: @"duration"];
	return (duration != nil) && ([duration doubleValue] > 0.);
}

- (void)setFixedDuration:(BOOL)isFixedDuration
{
	NSNumber* duration;
	if (isFixedDuration) {
		NSArray* events = [self orderedPositionEvents];
		if ((events == nil) || ([events count] < 1))
			duration = [NSNumber numberWithDouble: 0.];
		else {
			ZKMRNPositionEvent* lastEvent = [events objectAtIndex: [events count] - 1];
			duration = 
				[NSNumber numberWithDouble:
					[[lastEvent valueForKey: @"startTime"] doubleValue] +
					[[lastEvent valueForKey: @"duration"] doubleValue]];
		}
	} else 
		duration = nil;
	[[self piecePatch] setValue: duration forKey: @"duration"];
}

- (Float64)currentTime { return _currentTime; }

- (unsigned)currentHH 
{ 
	Float64 now = _currentTime;
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(now, &hh, &mm, &ss, &ms);
	return hh; 
}
- (void)setCurrentHH:(unsigned)currentHH 
{ 
	Float64 now = _currentTime;
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(now, &hh, &mm, &ss, &ms);
	HHMMSSMSToSeconds(currentHH, mm, ss, ms, &_currentTime);
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];
}

- (unsigned)currentMM 
{ 
	Float64 now = _currentTime;
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(now, &hh, &mm, &ss, &ms);
	return mm; 
}
- (void)setCurrentMM:(unsigned)currentMM 
{ 
	Float64 now = _currentTime;
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(now, &hh, &mm, &ss, &ms);
	HHMMSSMSToSeconds(hh, currentMM, ss, ms, &_currentTime);
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];	
}

- (unsigned)currentSS
{ 
	Float64 now = _currentTime;
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(now, &hh, &mm, &ss, &ms);
	return ss; 
}
- (void)setCurrentSS:(unsigned)currentSS 
{ 
	Float64 now = _currentTime;
	unsigned hh, mm, ss, ms; SecondsToHHMMSSMS(now, &hh, &mm, &ss, &ms);
	HHMMSSMSToSeconds(hh, mm, currentSS, 0, &_currentTime);
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];	
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
- (ZKMRNZirkoniumUISystem *)zirkoniumSystem { return _system; }

#pragma mark _____ Queries
- (BOOL)isPlaying { return [_system isPlaying]; }

#pragma mark _____ Display Update
- (void)tick:(id)timer
{
	[spatializerView setNeedsDisplay: YES];
	[initialSpatializerView setNeedsDisplay: YES];
	[self privateSetCurrentTime: [[_system clock] currentTimeSeconds]];
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
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entityDesc = [NSEntityDescription entityForName: @"GraphChannel" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entityDesc];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"graphChannelNumber" ascending: YES];
	[request setSortDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	[sortDescriptor release];
	NSError* error = nil;
	NSArray* orderedGraphChannels = [moc executeFetchRequest: request error: &error];
	if (!orderedGraphChannels) NSLog(@"Error fetching sources %@", error);
	[request release];
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
	
	[_pieceMixer willChangeValueForKey: @"children"];
	[_pieceMixer didChangeValueForKey: @"children"];
	_isGraphOutOfSynch = NO;
}

#pragma mark _____ ZKMRNPieceDocumentPrivate
- (void)privateSetCurrentTime:(Float64)currentTime
{
	[self willChangeValueForKey: @"currentHH"];
	[self willChangeValueForKey: @"currentMM"];
	[self willChangeValueForKey: @"currentSS"];
	_currentTime = currentTime;
	[self didChangeValueForKey: @"currentHH"];
	[self didChangeValueForKey: @"currentMM"];
	[self didChangeValueForKey: @"currentSS"];
}

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
		unsigned index = [[channel valueForKey: @"graphChannelNumber"] unsignedIntValue];
		ZKMNRPannerSource* source = [channel pannerSource];
		[_pannerSources replaceObjectAtIndex: index withObject: source];
	}
	if (spatializerView) [spatializerView setPannerSources: _pannerSources];
	if (initialSpatializerView) [initialSpatializerView setPannerSources: _pannerSources];
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
	ZKMRNPositionEvent* event;
	while (event = [positionEvents nextObject]) {
		[event scheduleEvents: scheduler];
	}
}

- (NSArray *)orderedPositionEvents
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entityDesc = [NSEntityDescription entityForName: @"PositionEvent" inManagedObjectContext: moc];
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

- (NSArray *)orderedDirectOuts
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entityDesc = [NSEntityDescription entityForName: @"DirectOutChannel" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entityDesc];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"directOutNumber" ascending: YES];
	[request setSortDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	[sortDescriptor release];
	NSError* error = nil;
	NSArray* orderedDirectOuts = [moc executeFetchRequest: request error: &error];
	if (!orderedDirectOuts) NSLog(@"Error fetching direct outs %@", error);
	[request release];
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
		unsigned outputIndex = [[graphChannel valueForKey: @"graphChannelNumber"] unsignedIntValue];	
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
		unsigned inputIndex = [inputBus mixerBusZeroOffset] + ([[graphChannel valueForKey: @"sourceChannelNumber"] unsignedIntValue] % sourceNumberOfChannels);
		[_pieceMixer setVolume: 1.f forCrosspointInput: inputIndex output: outputIndex];
	}
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
				[source setCurrentTime: _currentTime];
			}
		}
	[_pieceGraph endPatching];
}

- (void)managedObjectContextChanged:(NSNotification *)notification
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* audioSourceEntity = [NSEntityDescription entityForName: @"AudioSource" inManagedObjectContext: moc];
	NSEntityDescription* graphChannelEntity = [NSEntityDescription entityForName: @"GraphChannel" inManagedObjectContext: moc];
	NSEntityDescription* directOutChannelEntity = [NSEntityDescription entityForName: @"DirectOutChannel" inManagedObjectContext: moc];
	BOOL audioSourcesChanged = NO, graphChannelsChanged = NO, directOutChannelsChanged = NO;
		
	NSDictionary* userInfo = [notification userInfo];
	NSEnumerator* objects;	
	NSManagedObject* object;
			// check the inserted objects
	objects  = [[userInfo objectForKey: NSInsertedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([[audioSourceEntity subentities] containsObject: [object entity]]) audioSourcesChanged = YES;
		if ([graphChannelEntity isEqualTo: [object entity]]) graphChannelsChanged = YES;
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if (audioSourcesChanged || graphChannelsChanged || directOutChannelsChanged) break;
	}
		// check the deleted objects
	objects  = [[userInfo objectForKey: NSDeletedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([[audioSourceEntity subentities] containsObject: [object entity]]) audioSourcesChanged = YES;
		if ([graphChannelEntity isEqualTo: [object entity]]) graphChannelsChanged = YES;
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if (audioSourcesChanged || graphChannelsChanged || directOutChannelsChanged) break;
	}
	
	BOOL graphChannelsWereCreatedOrDestroyed = graphChannelsChanged;
	
		// check the modified objects
	objects  = [[userInfo objectForKey: NSUpdatedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([[audioSourceEntity subentities] containsObject: [object entity]]) audioSourcesChanged = YES;
		if ([graphChannelEntity isEqualTo: [object entity]]) graphChannelsChanged = YES;
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if (audioSourcesChanged || graphChannelsChanged || directOutChannelsChanged) break;
	}
	
	if (graphChannelsWereCreatedOrDestroyed) [self synchronizePannerSourcesWithSpatializerView];
	
	_isGraphOutOfSynch = _isGraphOutOfSynch || audioSourcesChanged || graphChannelsChanged || directOutChannelsChanged;
}

#pragma mark _____ NSWindow Delegate 
- (void)windowWillClose:(NSNotification *)notification
{
	spatializerView = nil;
	initialSpatializerView = nil;
	[mainWindow unregisterDraggedTypes];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
	return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{

}

#pragma mark _____ ZKMRNSpatializerViewDelegate
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

@end
