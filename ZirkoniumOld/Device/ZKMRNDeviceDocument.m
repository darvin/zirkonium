//
//  ZKMRNDeviceDocument.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import "ZKMRNDeviceDocument.h"
#import "ZKMRNZirkoniumUISystem.h"
#import "ZKMRNDeviceManager.h"
#import "ZKMRNGraph.h"
#import "ZKMRNGraphChannel.h"
#import "ZKMRNDomeView.h"
#import "ZKMRNPositionEvent.h"
#import "ZKMRNAudioSource.h"
#import "ZKMRNFileSource.h"
#import "ZKMRNFileV1Importer.h"
#import "ZKMRNManagedObjectExtensions.h"
#import "ZKMRNSpatializerView.h"

static NSString* kZKMRNPieceVersionKey = @"ZKMRNPieceVersionKey";
static unsigned kZKMRNPieceVersion = 1;

@interface ZKMRNDeviceDocument (ZKMRNPieceDocumentPrivate)
- (void)synchronizePannerSourcesWithSpatializerView;
- (void)activatePannerSources;
- (void)activateDirectOuts;
- (NSArray *)orderedAudioSources;
- (NSArray *)orderedDirectOuts;
- (void)synchronizeChannelsToMixer;
- (void)managedObjectContextChanged:(NSNotification *)notification;
@end

@implementation ZKMRNDeviceDocument
#pragma mark _____ NSPersistentDocument Overrides
- (void)dealloc
{
	if (_pannerSources) [_pannerSources release];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (id)init 
{
    if (!(self = [super init])) return nil;

	_system = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	_deviceManager = [_system deviceManager];
	_currentTime = 0.;
	_isGraphOutOfSynch = YES;
	_isEditingPiecePatch = NO;

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
    return @"ZKMRNDeviceDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib: windowController];
    // user interface preparation code
}


- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([@"numberOfDirectOuts" isEqualToString: keyPath]) {
		_isEditingPiecePatch = YES;
		[self equalizeNumberOfGraphChannels];
		_isEditingPiecePatch = NO;
	}
}

- (void)numberOfDirectOutsChanged:(NSNotification *)notification
{
	if ([notification object] != [self piecePatch]) return;
	
	_isEditingPiecePatch = YES;
	[self equalizeNumberOfGraphChannels];
	_isEditingPiecePatch = NO;
}

- (void)awakeFromNib
{
	[spatializerView setDelegate: self];
	[spatializerView setShowingInitial: NO];
	[spatializerView bind: @"speakerLayout" toObject: _system withKeyPath: @"speakerSetup.speakerLayout" options: nil];
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(managedObjectContextChanged:) name: NSManagedObjectContextObjectsDidChangeNotification object: [self managedObjectContext]];
	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(numberOfDirectOutsChanged:) name: ZKMRNGraphNumberOfDirectOutsChanged object: nil];
	[self synchronizePannerSourcesWithSpatializerView];
	
	[self activatePannerSources];
	[self activateDirectOuts];
	
	_isEditingPiecePatch = NO;
}

- (void)presentError:(NSError *)error modalForWindow:(NSWindow *)window delegate:(id)delegate didPresentSelector:(SEL)didPresentSelector contextInfo:(void *)contextInfo
{
	NSError* errorToPresent = error;
	BOOL isMultipleError = (NSCocoaErrorDomain == [error domain]) && (NSValidationMultipleErrorsError == [error code]);
	if (isMultipleError) {
		NSArray* errors = [[error userInfo] objectForKey: NSDetailedErrorsKey];
		if ([errors count] > 0) {
			errorToPresent = [errors objectAtIndex: 0];
			NSLog(@"Validation error on %@", [[errorToPresent userInfo] objectForKey: NSValidationObjectErrorKey]);
		}
	}
	[super presentError: errorToPresent modalForWindow: window delegate: delegate didPresentSelector: didPresentSelector contextInfo: contextInfo];
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

#pragma mark _____ UI Actions

#pragma mark _____ Accessors
- (ZKMORMixerMatrix *)deviceMixer { return [_deviceManager spatializationMixer]; }
- (NSArray *)pannerSources { return _pannerSources; }
- (ZKMRNGraph *)piecePatch 
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

- (BOOL)isSpatializerViewShowingInitial { return [spatializerView isShowingInitial]; }
- (void)setSpatializerViewShowingInitial:(BOOL)isSpatializerViewShowingInitial { [spatializerView setShowingInitial: isSpatializerViewShowingInitial]; }

- (ZKMRNDeviceManager *)deviceManager { return _deviceManager; }

- (unsigned)numberOfChannels { return [[[self piecePatch] valueForKey: @"numberOfChannels"] unsignedIntValue]; }
- (unsigned)numberOfDirectOuts { return [[[self piecePatch] valueForKey: @"numberOfDirectOuts"] unsignedIntValue]; }

#pragma mark _____ Actions
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain
{
	if (channel >= [_pannerSources count]) return;
	ZKMNRPannerSource* source = [_pannerSources objectAtIndex: channel];
	[source setCenter: center span: span gain: gain];
	[spatializerView setNeedsDisplay: YES];
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
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not find speaker near point { %.2f, %.2f, %.2f}"), sphericalCenter.azimuth, sphericalCenter.zenith, sphericalCenter.radius);
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

- (void)equalizeNumberOfGraphChannels
{
	unsigned oldNumChannels = [self numberOfChannels];
	unsigned numberOfDirectOuts = [self numberOfDirectOuts];
	unsigned total = [_deviceManager deviceNumberOfChannels];
	unsigned newNumChannels = total - numberOfDirectOuts;
	[[self piecePatch] setNumberOfChannels: [NSNumber numberWithInt: newNumChannels]];
	
	NSArray* orderedGraphChannels = [self orderedGraphChannels];
	unsigned i;
	for (i = oldNumChannels; i < newNumChannels; ++i) {
		id graphChannel = [orderedGraphChannels objectAtIndex: i];
		[graphChannel setValue: [graphChannel valueForKey: @"graphChannelNumber"] forKey: @"sourceChannelNumber"];
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

- (ZKMRNZirkoniumSystem *)zirkoniumSystem { return _system; }

#pragma mark _____ Queries
- (BOOL)isPlaying { return [_system isPlaying]; }

#pragma mark _____ Display Update
- (void)tick:(id)timer
{
	[spatializerView setNeedsDisplay: YES];
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

- (NSArray *)orderedGraphChannels
{
	NSSet* graphChannels = [[self piecePatch] valueForKey: @"graphChannels"];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"graphChannelNumber" ascending: YES];
	NSArray* orderedGraphChannels = [[graphChannels allObjects] sortedArrayUsingDescriptors: [NSArray arrayWithObject: sortDescriptor]];
	return orderedGraphChannels;
}

- (void)synchronizePatchToGraph
{
	[self synchronizeChannelsToMixer];
	_isGraphOutOfSynch = NO;
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
		unsigned index = [[channel valueForKey: @"graphChannelNumber"] unsignedIntValue];
		ZKMNRPannerSource* source = [channel pannerSource];
		[_pannerSources replaceObjectAtIndex: index withObject: source];
	}
	if (spatializerView) [spatializerView setPannerSources: _pannerSources];
	[self activatePannerSources];
}

- (void)activatePannerSources
{
	ZKMNRVBAPPanner* panner = [_deviceManager panner];
	[panner setActiveSources: _pannerSources];
	NSEnumerator* sources = [_pannerSources objectEnumerator];
	ZKMNRPannerSource* source;
	while (source = [sources nextObject]) [source moveToInitialPosition];
}

- (void)activateDirectOuts
{
	ZKMORMixerMatrix* spatializationMixer = [_deviceManager spatializationMixer];
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
		// tweak the device mixer to match my configuration
	ZKMORMixerMatrix* deviceMixer = [self deviceMixer];
	
	[deviceMixer setCrosspointsToZero];
	
	// the device manager's panner will set up the mixer coeffs for the panned sources (GraphChannels)
	[[_deviceManager panner] transferPanningToMixer];
	
	// set up the mixer for the direct outs
	NSManagedObject* source = [[self inputSources] lastObject];	
	NSEnumerator* directOuts = [[self orderedDirectOuts] objectEnumerator];
	unsigned numberOfChannels = [self numberOfChannels];
	unsigned numberOfSpeakers = [_deviceManager numberOfSpeakers];
	unsigned numberOfDirectOuts = [[self orderedDirectOuts] count];
	
	NSManagedObject* directOut;
	while (directOut = [directOuts nextObject]) {
		unsigned outputIndex = numberOfSpeakers + ([[directOut valueForKey: @"sourceChannelNumber"] unsignedIntValue] % numberOfDirectOuts) ;
		unsigned sourceNumberOfChannels = [[source valueForKey: @"numberOfChannels"] unsignedIntValue];
		unsigned inputIndex = (numberOfChannels + [[directOut valueForKey: @"directOutNumber"] unsignedIntValue]) % sourceNumberOfChannels;
		[deviceMixer setVolume: 1.f forCrosspointInput: inputIndex output: outputIndex];
	}
}

- (void)managedObjectContextChanged:(NSNotification *)notification
{
		// we are making changes, don't want to cause any confusion
	if (_isEditingPiecePatch) return;

	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* directOutChannelEntity = [NSEntityDescription entityForName: @"DirectOutChannel" inManagedObjectContext: moc];
	NSEntityDescription* piecePatchEntity = [NSEntityDescription entityForName: @"Graph" inManagedObjectContext: moc];
	BOOL directOutChannelsChanged = NO;
		
	NSDictionary* userInfo = [notification userInfo];
	NSEnumerator* objects;	
	NSManagedObject* object;
			// check the inserted objects
	objects  = [[userInfo objectForKey: NSInsertedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if (directOutChannelsChanged) break;
	}
		// check the deleted objects
	objects  = [[userInfo objectForKey: NSDeletedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if (directOutChannelsChanged) break;
	}
	
	BOOL graphChannelsWereCreatedOrDestroyed = directOutChannelsChanged;
	
		// check the modified objects
	objects  = [[userInfo objectForKey: NSUpdatedObjectsKey] objectEnumerator];
	while (object = [objects nextObject]) {
		if ([directOutChannelEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if ([piecePatchEntity isEqualTo: [object entity]]) directOutChannelsChanged = YES;
		if (directOutChannelsChanged) break;
	}
	
	if (graphChannelsWereCreatedOrDestroyed) [self synchronizePannerSourcesWithSpatializerView];
	_isGraphOutOfSynch = _isGraphOutOfSynch || directOutChannelsChanged;
		// synchronize right now -- don't wait to play
	if (_isGraphOutOfSynch) [self synchronizePatchToGraph];
}

#pragma mark _____ NSWindow Delegate 
- (void)windowWillClose:(NSNotification *)notification
{
	spatializerView = nil;
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
	[graphChannelsController setSelectedObjects: [NSArray arrayWithObject: [pannerSource tag]]];
}

- (void)view:(ZKMRNDomeView *)domeView movedPannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point
{
	if (![self isSpatializerViewShowingInitial]) return;
	ZKMRNGraphChannel* channel = [pannerSource tag];
	[channel setValue: [NSNumber numberWithFloat: point.azimuth] forKey: @"initialAzimuth"];
	[channel setValue: [NSNumber numberWithFloat: point.zenith] forKey: @"initialZenith"];
	[pannerSource setCenter: point];
}
- (void)view:(ZKMRNDomeView *)domeView finishedMovePannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point { }

@end
