//
//  ZKMRMPlaybackPiece.m
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 20.07.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMRMPlaybackPiece.h"
#import "ZKMRNZirkoniumUISystem.h"
#import "ZKMRNGraphChannel.h"
#import "ZKMRNSpatializerView.h"
#import "ZKMRNPositionEvent.h"
#import "ZKMRNAudioSource.h"
#import "ZKMRNFileSource.h"
#import "ZKMRNManagedObjectExtensions.h"
#import <Syncretism/ZKMNRValueTransformer.h>

//static NSString* kZKMRNPieceVersionKey = @"ZKMRNPieceVersionKey";
//static unsigned kZKMRNPieceVersion = 1;

@interface ZKMRMPlaybackPiece (ZKMRMPlaybackPiecePrivate)
- (void)privateSetCurrentTime:(Float64)currentTime;
- (void)privateSetCurrentTimeFromPosition:(Float64)currentTime;
- (void)activatePannerSources;
- (void)activateDirectOuts;
- (void)addEventsToScheduler;
- (NSArray *)orderedAudioSources;
- (NSArray *)orderedDirectOuts;
- (void)synchronizeChannelsToMixer;
- (void)synchronizeCurrentTimeToGraph;
- (void)managedObjectContextChanged:(NSNotification *)notification;
- (void)refreshEvents;
@end

@interface ZKMRMPlaybackPiece (ZKMRMPlaybackPieceMOC)
- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectContext *)managedObjectContext;

@end

@implementation ZKMRMPlaybackPiece

@synthesize pieceGain;

- (void)dealloc
{
	if (((ZKMRMPlaybackPiece *)[_system playingPiece]) == self) {
		[_system setPlaying: NO];
		[_system setPlayingPiece: nil];
	}
		
	if (_pieceGraph) [_pieceGraph release];
	if (_pannerSources) [_pannerSources release];
	if (managedObjectContext) [managedObjectContext release];
	if (persistentStoreCoordinator) [persistentStoreCoordinator release];
	if (managedObjectModel) [managedObjectModel release];
	if (pieceURL) [pieceURL release];
	if (pieceGain) [pieceGain release];

	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (id)init 
{
    if (!(self = [super init])) return nil;

	_system = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	_pieceGraph = [[ZKMORGraph alloc] init];
	_pieceMixer = [[ZKMORMixerMatrix alloc] init];
	_currentTime = 0.;
	_isGraphOutOfSynch = YES;

    return self;
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
		// cd to the import path so file manager operations work correctly
	NSString* parentDir = [[absoluteURL path] stringByDeletingLastPathComponent];
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: parentDir];
	
	if (!(self = [self init])) return nil;
	
	pieceURL = [absoluteURL copy];
	
	[self synchronizePatchToGraph];

/*		
	NSPersistentStoreCoordinator* psc = [[self managedObjectContext] persistentStoreCoordinator];
	id pStore = [psc persistentStoreForURL: absoluteURL];

	NSDictionary* metadata = [psc metadataForPersistentStore: pStore];
	if (kZKMRNPieceVersion != [[metadata valueForKey: kZKMRNPieceVersionKey] unsignedIntValue]) {
		NSLog(@"Opening object with unknown version %@", [metadata valueForKey: kZKMRNPieceVersionKey]);
	}
*/

	return self;
}


- (void)presentError:(NSError *)error modalForWindow:(NSWindow *)window delegate:(id)delegate didPresentSelector:(SEL)didPresentSelector contextInfo:(void *)contextInfo
{
	NSError* errorToPresent = error;
	BOOL isMultipleError = (NSCocoaErrorDomain == [error domain]) && (NSValidationMultipleErrorsError == [error code]);
	if (isMultipleError) {
		NSArray* errors = [[error userInfo] objectForKey: NSDetailedErrorsKey];
		if ([errors count] > 0) errorToPresent = [errors objectAtIndex: 0];
	}
}

- (void)presentError:(NSError *)error
{
	[[NSApplication sharedApplication] presentError: error];
}

#pragma mark ZKMRMPlaybackPieceMOC
- (NSManagedObjectModel *)managedObjectModel {

    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
	NSString* pieceMOMPath = [[NSBundle mainBundle] pathForResource: @"PieceDocument" ofType: @"momd"];
	NSString* inputMOMPath = [[NSBundle mainBundle] pathForResource: @"InputSetup" ofType: @"momd"];
	NSString* studioMOMPath = [[NSBundle mainBundle] pathForResource: @"StudioSetup" ofType: @"momd"];
	NSArray* models = [NSArray
		arrayWithObjects:
			[[NSManagedObjectModel alloc] initWithContentsOfURL: [NSURL fileURLWithPath: pieceMOMPath]],
			[[NSManagedObjectModel alloc] initWithContentsOfURL: [NSURL fileURLWithPath: inputMOMPath]],
			[[NSManagedObjectModel alloc] initWithContentsOfURL: [NSURL fileURLWithPath: studioMOMPath]],
			nil];
    managedObjectModel = [NSManagedObjectModel modelByMergingModels: models];
	[managedObjectModel retain];
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {

    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }

    NSError *error;
    
    persistentStoreCoordinator = 
		[[NSPersistentStoreCoordinator alloc] 
			initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType: NSXMLStoreType configuration: nil URL: pieceURL options: nil error: &error]){
        [[NSApplication sharedApplication] presentError:error];
    }    

    return persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext {

    if (managedObjectContext != nil) {
        return managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
}

#pragma mark _____ UI Actions
- (void)startPlaying
{
	if (![_system isPlaying]) {
		if (_isGraphOutOfSynch) [self synchronizePatchToGraph];
		[_system setPlayingPiece: (ZKMRNPieceDocument *) self];
		[self synchronizeCurrentTimeToGraph];		
		[self addEventsToScheduler];
		[self activatePannerSources];
		[self activateDirectOuts];
		[_system setPlaying: YES];
		if (pieceGain)
			[_pieceMixer setMasterVolume: [pieceGain floatValue]];
	}
}

- (void)moveTransportToStart
{
	[self privateSetCurrentTime: 0.];
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];
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

#pragma mark _____ UI Accessors
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

- (Float64)currentTime { return _currentTime; }
- (Float64)duration
{
		// not a fixed-duration piece, return something < 0
	if (![self isFixedDuration]) return -1.;
		// no sources, so the duration is 0
	NSArray* sources = [self orderedAudioSources];
	if (!sources || ([sources count] < 1)) {
		return 0;
	}
	
	Float64 duration = 0.;
	unsigned i, sourcesCount = [sources count];
	for (i = 0; i < sourcesCount; i++) {
		// if the piece is fixed duration, all sources are File Sources
		double fileDuration = [[(ZKMRNFileSource *) [sources objectAtIndex: i] duration] doubleValue];
		if (fileDuration > duration) duration = fileDuration;
	}
	
	return duration;
}

- (float)currentPosition
{
	if (![self isFixedDuration]) return 0.f;
	
	return [self currentTime] / [self duration];
}

- (void)setCurrentPosition:(float)pos;
{
	if (![self isFixedDuration]) return;
	
	pos = ZKMORClamp(pos, 0.f, 1.f);
	[self privateSetCurrentTimeFromPosition: pos * [self duration]];
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];
}

- (unsigned)currentMM
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	return mm; 
}
- (void)setCurrentMM:(unsigned)currentMM
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	MMSSMSToSeconds(currentMM, ss, ms, &_currentTime);
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];
}

- (unsigned)currentSS
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	return ss; 
}
- (void)setCurrentSS:(unsigned)currentSS
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	MMSSMSToSeconds(mm, currentSS, ms, &_currentTime);
	if ([self isPlaying]) [self synchronizeCurrentTimeToGraph];	
}

- (unsigned)currentMS
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	return ms; 
}
- (void)setCurrentMS:(unsigned)currentMS 
{ 
	Float64 now = _currentTime;
	unsigned mm, ss, ms; SecondsToMMSSMS(now, &mm, &ss, &ms);
	MMSSMSToSeconds(mm, ss, currentMS, &_currentTime);
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
- (ZKMRNZirkoniumSystem *)zirkoniumSystem { return _system; }

#pragma mark _____ Queries
- (BOOL)isPlaying { return [_system isPlaying]; }

#pragma mark _____ Display Update
- (void)tick:(id)timer
{
//	[spatializerView setNeedsDisplay: YES];
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
	[self willChangeValueForKey: @"currentPosition"];
	[self willChangeValueForKey: @"currentHH"];
	[self willChangeValueForKey: @"currentMM"];
	[self willChangeValueForKey: @"currentSS"];
	_currentTime = currentTime;
	[self didChangeValueForKey: @"currentPosition"];	
	[self didChangeValueForKey: @"currentHH"];
	[self didChangeValueForKey: @"currentMM"];
	[self didChangeValueForKey: @"currentSS"];
}

- (void)privateSetCurrentTimeFromPosition:(Float64)currentTime
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
//	if (spatializerView) [spatializerView setPannerSources: _pannerSources];
//	if ([_system isPlaying]) [self activatePannerSources];
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
		unsigned inputIndex = [inputBus mixerBusZeroOffset] + ([[directOut valueForKey: @"sourceChannelNumber"] unsignedIntValue] % sourceNumberOfChannels);
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
	[[_system clock] beginScrubbing];
	[[_system clock] setCurrentTimeSeconds: _currentTime];
	[[_system clock] endScrubbing];	
}

- (void)refreshEvents
{
	[self addEventsToScheduler];
}

@end
