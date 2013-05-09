//
//  ZKMRNFileV1Importer.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 06.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNFileV1Importer.h"
#import "ZKMRNPieceDocument.h"
#import "ZKMRNFileSource.h"
#import "ZKMRNPositionEvent.h"

static ZKMRNFileV1Importer* sSharedFileImporter = NULL;

@interface ZKMRNFileV1Importer (ZKMRNFileV1ImporterPrivate)

@end

@implementation ZKMRNFileV1Importer

#pragma mark _____ Singleton
+ (ZKMRNFileV1Importer *)sharedFileImporter 
{ 
	if (!sSharedFileImporter) {
		sSharedFileImporter = [[ZKMRNFileV1Importer alloc] init];
	}
	return sSharedFileImporter; 
}

#pragma mark _____ Actions
- (void)run
{
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	[oPanel setAllowsMultipleSelection: NO];
	NSArray* fileTypes = [NSArray arrayWithObject: @"zrknx"];
	int result = [oPanel runModalForTypes: fileTypes];
	if (result != NSOKButton) return;
	
	NSString* path = [oPanel filename];
	NSError* error = nil;
	ZKMRNPieceDocument* doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay: YES error: &error];
	if (!doc) {
		if (error) [[NSApplication sharedApplication] presentError: error];
		return;
	}
	
		// cd to the import path so file manager operations work correctly
	NSString* parentDir = [path stringByDeletingLastPathComponent];
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: parentDir];

	[self importPath: path intoDocument: doc];
}

- (void)importPath:(NSString *)path intoDocument:(ZKMRNPieceDocument *)document;
{
	NSFileWrapper* fileWrapper = [[NSFileWrapper alloc] initWithPath: path];
	NSDictionary* packageDict = [fileWrapper fileWrappers];
	NSFileWrapper* timelineWrapper = [packageDict objectForKey: @"timeline"];
	NSData* timelineData = [timelineWrapper regularFileContents];

	NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData: timelineData];
	[unarchiver setDelegate: self];
	[unarchiver setClass: [ZKMRNFileV1PannerEvent class] forClassName: @"ZKMNRPannerEvent"];

	id timeline = [[unarchiver decodeObjectForKey: @"Timeline"] retain];
	
//	[timeline dumpToConsole: 0];
	[timeline setUpImportIntoDocument: document];
	[timeline importIntoDocument: document];
	
	[unarchiver finishDecoding];
	[unarchiver release];
	[fileWrapper release];
	[timeline release];
}

#pragma mark _____ NSKeyedUnarchiverDelegate
- (Class)unarchiver:(NSKeyedUnarchiver *)unarchiver cannotDecodeObjectOfClassName:(NSString *)name originalClasses:(NSArray *)classNames
{
	if ([name isEqualToString: @"ZKMNREvent"])
		return [ZKMRNFileV1Event class];
	if ([name isEqualToString: @"ZKMNRTimeline"])
		return [ZKMRNFileV1Timeline class];
	if ([name isEqualToString: @"ZKMNRTimelineTrack"])
		return [ZKMRNFileV1TimelineTrack class];
	if ([name isEqualToString: @"ZKMNRSpatializedTimeline"])
		return [ZKMRNFileV1SpatializedTimeline class];
	if ([name isEqualToString: @"ZKMNRSpatializedTimelineTrack"])
		return [ZKMRNFileV1TimelineTrack class];
		
	if ([name isEqualToString: @"ZKMNRAudioInputEvent"])
		return [ZKMRNFileV1InputEvent class];
	if ([name isEqualToString: @"ZKMNRJackInputEvent"])
		return [ZKMRNFileV1InputEvent class];
		
	if ([name isEqualToString: @"ZKMNRFileReaderEvent"])
		return [ZKMRNFileV1FileReaderEvent class];
	if ([name isEqualToString: @"ZKMNRSchedulableFileReader"])
		return [ZKMRNFileV1FileReaderEvent class];
		
	return nil;
}

- (id)unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(id)object
{
	return object;
}


// notification
- (void)unarchiver:(NSKeyedUnarchiver *)unarchiver willReplaceObject:(id)object withObject:(id)newObject
{

}

- (void)unarchiverWillFinish:(NSKeyedUnarchiver *)unarchiver
{

}

- (void)unarchiverDidFinish:(NSKeyedUnarchiver *)unarchiver
{

}


@end


@implementation ZKMRNFileV1Event
- (void)dealloc
{
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [self init])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {
		startTime  = [aDecoder decodeDoubleForKey: @"SecondsRangeStart"];
		duration = [aDecoder decodeDoubleForKey: @"SecondsRangeDuration"];
	}
	
	return self;
}
- (void)dumpToConsole:(int)indent { }
- (void)setUpImportIntoDocument:(ZKMRNPieceDocument *)document { }
- (void)importIntoDocument:(ZKMRNPieceDocument *)document { }
- (NSComparisonResult)compare:(ZKMRNFileV1Event *)otherEvent
{
	if (startTime < otherEvent->startTime) return NSOrderedAscending;
	if (startTime > otherEvent->startTime) return NSOrderedDescending;
	return NSOrderedSame;
}
@end

@implementation ZKMRNFileV1Timeline
- (void)dealloc
{
	if (tracks) [tracks release];
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder: aDecoder])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {
		tracks = [aDecoder decodeObjectForKey: @"Tracks"];
		[tracks retain];
	} 
	
	return self;
}
- (void)dumpToConsole:(int)indent
{
	printf("Timeline 0x%x {\n", self);
	unsigned i, count = [tracks count];
	for (i = 0; i < count; i++) {
		[[tracks objectAtIndex: i] dumpToConsole: indent + 1];
	}
	printf("}\n");
	fflush(stdout);
}

- (void)setUpImportIntoDocument:(ZKMRNPieceDocument *)document
{
	unsigned i, count = [tracks count];
	for (i = 0; i < count; i++) {
		[[tracks objectAtIndex: i] setUpImportIntoDocument: document];
	}
}

- (void)importIntoDocument:(ZKMRNPieceDocument *)document
{
	unsigned i, count = [tracks count];
	for (i = 0; i < count; i++) {
		[[tracks objectAtIndex: i] importIntoDocument: document];
	}
}
@end

@implementation ZKMRNFileV1TimelineTrack
- (void)dealloc
{
	if (events) [events release];
	if (ids) [ids release];
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder: aDecoder])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {
		if ([aDecoder containsValueForKey: @"UnorderedSchedulables"])
			events = [aDecoder decodeObjectForKey: @"UnorderedSchedulables"];
		else
			events = [aDecoder decodeObjectForKey: @"UnorderedEvents"];
		// sort events
		events = [events sortedArrayUsingSelector: @selector(compare:)];
		[events retain];
	}
	
	ids = [[NSMutableArray alloc] init];

	return self;
}
- (void)dumpToConsole:(int)indent
{
	printf("\tTrack 0x%x {\n", self);
	unsigned i, count = [events count];
	for (i = 0; i < count; i++) {
		[[events objectAtIndex: i] dumpToConsole: indent + 1];
	}
	printf("\t}\n");
}

- (void)setUpImportIntoDocument:(ZKMRNPieceDocument *)document
{
	// Remember how many graph channels there are right now
	NSManagedObject* piecePatch = [document piecePatch];
	NSNumber* oldNumberOfChannels = [piecePatch valueForKey: @"numberOfChannels"];

	unsigned i, count = [events count];
	for (i = 0; i < count; i++) {
		[[events objectAtIndex: i] setUpImportIntoDocument: document];
	}

	// Check how many channels were created and store the new ones away
	NSArray* orderedGraphChannels = [document orderedGraphChannels];
	unsigned olNumCh = [oldNumberOfChannels unsignedIntValue];
	count = [orderedGraphChannels count];
	for (i = olNumCh ; i < count; i++) {
		[ids addObject: [orderedGraphChannels objectAtIndex: i]];
	}
	
	
	count = [events count];
	ZKMRNFileV1Event *currentEvent = nil;
	for (i = 1; i < count; i++) {
		currentEvent = [events objectAtIndex: i];
		if ([currentEvent isKindOfClass: [ZKMRNFileV1PannerEvent class]]) {
			[(ZKMRNFileV1PannerEvent *) currentEvent takePrevEndPointFrom: events index: i];
		}
	}
}

- (void)importIntoDocument:(ZKMRNPieceDocument *)document
{	
	unsigned i, count = [events count];
	for (i = 0; i < count; i++) {
		[[events objectAtIndex: i] importIntoDocument: document];
	}
}

- (NSArray *)ids { return ids; }
@end

@implementation ZKMRNFileV1SpatializedTimeline

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder: aDecoder])) {
		[self release];
		return nil;
	}

	return self;
}
@end

@implementation ZKMRNFileV1InputEvent

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder: aDecoder])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {
		numberOfOutputChannels = [aDecoder decodeIntForKey: @"NumberOfOutputChannels"];
	}

	return self;
}
- (void)dumpToConsole:(int)indent
{
	printf("\t\tInputEvent 0x%x { {%.2f %.2f} %u }\n", self, startTime, duration, numberOfOutputChannels);
}

- (void)setUpImportIntoDocument:(ZKMRNPieceDocument *)document
{
	[document setInputOn: YES];
	NSEnumerator* inputSources = [[document inputSources] objectEnumerator];
	id input = [inputSources nextObject];
	[input setValue: [NSNumber numberWithInt: numberOfOutputChannels] forKey: @"numberOfChannels"];

	// create graph channels for each of the input channels
	NSManagedObject* piecePatch = [document piecePatch];
	NSNumber* oldNumberOfChannels = [piecePatch valueForKey: @"numberOfChannels"];

		// add the new channels
	[piecePatch setValue: [NSNumber numberWithInt: [oldNumberOfChannels intValue] + numberOfOutputChannels] forKey: @"numberOfChannels"];
		// bind them to the input

	NSArray* orderedGraphChannels = [document orderedGraphChannels];
	unsigned olNumCh = [oldNumberOfChannels unsignedIntValue];
	unsigned i;
	for (i = 0 ; i < numberOfOutputChannels; i++) {
		id graphChannel = [orderedGraphChannels objectAtIndex: i + olNumCh];
		[graphChannel setValue: [NSNumber numberWithInt: i] forKey: @"sourceChannelNumber"];
		[graphChannel setValue: input forKey: @"source"];
	}
}

- (NSComparisonResult)compare:(ZKMRNFileV1Event *)otherEvent
{
	if ([otherEvent isKindOfClass: [ZKMRNFileV1PannerEvent class]]) return NSOrderedAscending;
	return [super compare: otherEvent];
}
@end


@implementation ZKMRNFileV1FileReaderEvent
- (void)dealloc
{
	if (pathURL) [pathURL release];
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder: aDecoder])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {
		pathURL = [aDecoder decodeObjectForKey: @"FilePathURL"];
		
		// try to locate the file...
		NSFileManager* fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath: [pathURL path]]) {
			CFURLRef pathURLRef = (CFURLRef) pathURL;
			NSString* fileName = (NSString*) CFURLCopyLastPathComponent(pathURLRef);
			if ([fileManager fileExistsAtPath: fileName]) {
				// pathURL isn't owned by us -- don't release
				pathURL = [NSURL fileURLWithPath: fileName];
			}
		}
		[pathURL retain];
	}

	return self;
}

- (void)dumpToConsole:(int)indent
{
	printf("\t\tFileReaderEvent 0x%x { {%.2f %.2f} %s }\n", self, startTime, duration, [[pathURL path] cString]);
}

- (void)setUpImportIntoDocument:(ZKMRNPieceDocument *)document
{
	NSManagedObjectContext* moc = [document managedObjectContext];
	ZKMRNFileSource* fileSource =  [NSEntityDescription insertNewObjectForEntityForName: @"FileSource" inManagedObjectContext: moc];
	[fileSource setValue: [pathURL path] forKey: @"path"];
	
	// create graph channels for each of the file's channels
	unsigned numberOfOutputChannels = [[fileSource valueForKey: @"numberOfChannels"] unsignedIntValue];
	NSManagedObject* piecePatch = [document piecePatch];
	NSNumber* oldNumberOfChannels = [piecePatch valueForKey: @"numberOfChannels"];

		// add the new channels
	[piecePatch setValue: [NSNumber numberWithInt: [oldNumberOfChannels intValue] + numberOfOutputChannels] forKey: @"numberOfChannels"];
		// bind them to the fileSource
	NSArray* orderedGraphChannels = [document orderedGraphChannels];
	unsigned olNumCh = [oldNumberOfChannels unsignedIntValue];
	unsigned i;
	for (i = 0 ; i < numberOfOutputChannels; i++) {
		id graphChannel = [orderedGraphChannels objectAtIndex: i + olNumCh];
		[graphChannel setValue: [NSNumber numberWithInt: i] forKey: @"sourceChannelNumber"];
		[graphChannel setValue: fileSource forKey: @"source"];
	}
}

- (NSComparisonResult)compare:(ZKMRNFileV1Event *)otherEvent
{
	if ([otherEvent isKindOfClass: [ZKMRNFileV1PannerEvent class]]) return NSOrderedAscending;
	return [super compare: otherEvent];
}
@end

@implementation ZKMRNFileV1PannerEvent
- (void)dealloc
{
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [super initWithCoder: aDecoder])) {
		[self release];
		return nil;
	}
	
	if ([aDecoder allowsKeyedCoding]) {
		_track = [[aDecoder decodeObjectForKey: @"Track"] retain];
		_channel = [aDecoder decodeIntForKey: @"Channel"];
		_startGain = [aDecoder decodeFloatForKey: @"StartGain"];
		_endGain = [aDecoder decodeFloatForKey: @"EndGain"];
	}
	
	_startPoint = ZKMNRSphericalCoordinateDecode(@"StartPoint", aDecoder);
	_startSpan = ZKMNRSphericalCoordinateSpanDecode(@"StartSpan", aDecoder);
	_endPoint = ZKMNRSphericalCoordinateDecode(@"EndPoint", aDecoder);
	_endSpan = ZKMNRSphericalCoordinateSpanDecode(@"EndSpan", aDecoder);

	return self;
}

- (void)dumpToConsole:(int)indent
{
	printf("\t\tPannerEvent 0x%x { {%.2f %.2f} %u {%.2f->%.2f} {%.2f->%.2f} }\n", self, startTime, duration, _channel, _startPoint.azimuth, _endPoint.azimuth, _startPoint.zenith, _endPoint.zenith);
}

- (void)importIntoDocument:(ZKMRNPieceDocument *)document
{

	id container = [[_track ids] objectAtIndex: _channel];
	
	if (0. == startTime) {
		// this contains initial information
		if (0. == duration) {
			// extract the initial information
			[container setValue: [NSNumber numberWithFloat: _endPoint.azimuth] forKey: @"initialAzimuth"];
			[container setValue: [NSNumber numberWithFloat: _endPoint.zenith] forKey: @"initialZenith"];
			[container setValue: [NSNumber numberWithFloat: _endGain] forKey: @"initialGain"];
			// we're done
			return;
		}
		// extract the initial information, but create an event as well
		[container setValue: [NSNumber numberWithFloat: _startPoint.azimuth] forKey: @"initialAzimuth"];
		[container setValue: [NSNumber numberWithFloat: _startPoint.zenith] forKey: @"initialZenith"];
		[container setValue: [NSNumber numberWithFloat: _startGain] forKey: @"initialGain"];
	}
	
	NSManagedObjectContext* moc = [document managedObjectContext];
	ZKMRNPositionEvent* event =  [NSEntityDescription insertNewObjectForEntityForName: @"PositionEvent" inManagedObjectContext: moc];
	[event setValue: container forKey: @"container"];
	
	if (_hasPrevEndPoint && ((_startPoint.azimuth != _prevEndPoint.azimuth) || (_startPoint.zenith != _prevEndPoint.zenith))) {
		ZKMRNPositionEvent* correctionEvent =  [NSEntityDescription insertNewObjectForEntityForName: @"PositionEvent" inManagedObjectContext: moc];
		[correctionEvent setValue: container forKey: @"container"];
		[correctionEvent setValue: [NSNumber numberWithDouble: startTime] forKey: @"startTime"];
		[correctionEvent setValue: [NSNumber numberWithDouble: 0.01] forKey: @"duration"];

		float deltaAzimuth = _startPoint.azimuth - _prevEndPoint.azimuth;
		float deltaZenith = _startPoint.zenith - _prevEndPoint.zenith;	
		[correctionEvent setValue: [NSNumber numberWithFloat: deltaAzimuth] forKey: @"deltaAzimuth"];
		[correctionEvent setValue: [NSNumber numberWithFloat: deltaZenith] forKey: @"deltaZenith"];

		[correctionEvent setValue: [NSNumber numberWithFloat: _startSpan.zenithSpan] forKey: @"height"];
		[correctionEvent setValue: [NSNumber numberWithFloat: _startSpan.azimuthSpan] forKey: @"width"];
		[correctionEvent setValue: [NSNumber numberWithFloat: _startGain] forKey: @"gain"];

		[event setValue: [NSNumber numberWithDouble: startTime + 0.01] forKey: @"startTime"];
		[event setValue: [NSNumber numberWithDouble: duration - 0.01] forKey: @"duration"];
	} else {
		[event setValue: [NSNumber numberWithDouble: startTime] forKey: @"startTime"];
		[event setValue: [NSNumber numberWithDouble: duration] forKey: @"duration"];
	}

	float deltaAzimuth = _endPoint.azimuth - _startPoint.azimuth;
	float deltaZenith = _endPoint.zenith - _startPoint.zenith;	
	[event setValue: [NSNumber numberWithFloat: deltaAzimuth] forKey: @"deltaAzimuth"];
	[event setValue: [NSNumber numberWithFloat: deltaZenith] forKey: @"deltaZenith"];
	
	[event setValue: [NSNumber numberWithFloat: _endSpan.zenithSpan] forKey: @"height"];
	[event setValue: [NSNumber numberWithFloat: _endSpan.azimuthSpan] forKey: @"width"];
	[event setValue: [NSNumber numberWithFloat: _endGain] forKey: @"gain"];
}

- (NSComparisonResult)compare:(ZKMRNFileV1Event *)otherEvent
{
	if (![otherEvent isKindOfClass: [ZKMRNFileV1PannerEvent class]]) return NSOrderedDescending;
	return [super compare: otherEvent];
}

- (void)takePrevEndPointFrom:(NSArray *)events index:(unsigned)index
{
	_hasPrevEndPoint = NO;
	id prevEvent;
	int i;
	for (i = index - 1; i > -1; --i) {
		prevEvent = [events objectAtIndex: i];
		if ([prevEvent isKindOfClass: [ZKMRNFileV1PannerEvent class]]) {
			if (((ZKMRNFileV1PannerEvent *) prevEvent)->_channel == _channel) {
				_hasPrevEndPoint = YES;			
				_prevEndPoint = ((ZKMRNFileV1PannerEvent *)prevEvent)->_endPoint;
				break;
			}
		}
	}
}
@end
