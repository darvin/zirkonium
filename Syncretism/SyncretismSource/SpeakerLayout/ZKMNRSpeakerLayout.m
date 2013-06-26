//
//  ZKMNRSpeakerLayout.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 24.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRSpeakerLayout.h"
#import "ZKMORLogger.h"
#import "ZKMORUtilities.h"


@implementation ZKMNRSpeakerPosition
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_ringNumber = -1;
	_layoutIndex = -1;
	_tag = nil;
	
	return self;
}

#pragma mark _____ Accessors
- (int)ringNumber { return _ringNumber; }
- (int)layoutIndex { return _layoutIndex; }

- (ZKMNRSphericalCoordinate)coordPlatonic { return _coordPlatonic; }
- (void)setCoordPlatonic:(ZKMNRSphericalCoordinate)coordPlatonic { _coordPlatonic = coordPlatonic; _coordPlatonic.radius = 1.f;}

- (ZKMNRSphericalCoordinate)coordPhysical { return _coordPhysical; }
- (void)setCoordPhysical:(ZKMNRSphericalCoordinate)coordPhysical 
{ 
	_coordPhysical = coordPhysical;
	_coordRectangular = ZKMNRSphericalCoordinateToRectangular(_coordPhysical);
}

- (ZKMNRRectangularCoordinate)coordRectangular { return _coordRectangular; }
- (void)setCoordRectangular:(ZKMNRRectangularCoordinate)coordRectangular 
{ 
	_coordRectangular = coordRectangular; 
	_coordPhysical = ZKMNRRectangularCoordinateToSpherical(_coordRectangular);
}

- (id)tag { return _tag; }
- (void)setTag:(id)tag { _tag = tag; }

#pragma mark _____ Comparison
- (NSComparisonResult)compare:(ZKMNRSpeakerPosition *)otherPosition
{
	// I am smaller than the argument if:
	//		-- my ring number is less than the other ring number
	//		-- my azimuth is greater  than the other azimuth
	//		-- my zenith is greater than the other zenith
	unsigned otherRingNumber = otherPosition->_ringNumber;
	float azimuth = _coordPlatonic.azimuth;
	float zenith = _coordPlatonic.zenith;	
	float otherAzimuth = otherPosition->_coordPlatonic.azimuth;
	float otherZenith = otherPosition->_coordPlatonic.zenith;
	
	// ring number gets priority
	if (_ringNumber < otherRingNumber) {
		return NSOrderedAscending;
	} else if (_ringNumber > otherRingNumber) {
		return NSOrderedDescending;
	}
	
	// ring number is the same
	if (azimuth > otherAzimuth) {
		// order our speakers from -1 (directly behind, left) to +1 (directly behind, right)
		// in clockwise order (in our Euclidian coord system, positive angles are counter-clockwise).
		return NSOrderedAscending;
	} else if (azimuth < otherAzimuth) {
		return NSOrderedDescending;
	}
	
	// ring number and azimuth are the same -- this shouldn't happen
	if (zenith < otherZenith) {
		return NSOrderedAscending;
	} else if (zenith < otherZenith) {
		return NSOrderedDescending;
	}

	return NSOrderedSame;
}

#pragma mark _____ Actions
- (void)computeCoordPlatonicFromPhysical
{
	_coordPlatonic.azimuth = _coordPhysical.azimuth;
	_coordPlatonic.zenith = _coordPhysical.zenith;
	_coordPlatonic.radius = 1.f;
}

#pragma mark _____ Serialization
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary* speakerPos = [NSMutableDictionary dictionary];
	
	[speakerPos setValue: [NSNumber numberWithFloat: _coordPlatonic.azimuth] forKey: @"PlatonicAzimuth"];
	[speakerPos setValue: [NSNumber numberWithFloat: _coordPlatonic.zenith] forKey: @"PlatonicZenith"];
	
	[speakerPos setValue: [NSNumber numberWithFloat: _coordPhysical.azimuth] forKey: @"PhysicalAzimuth"];
	[speakerPos setValue: [NSNumber numberWithFloat: _coordPhysical.zenith] forKey: @"PhysicalZenith"];
	[speakerPos setValue: [NSNumber numberWithFloat: _coordPhysical.radius] forKey: @"PhysicalRadius"];

	return speakerPos;
}

- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation
{
	ZKMNRSphericalCoordinate coordPlatonic;
	ZKMNRSphericalCoordinate coordPhysical;	
	coordPlatonic.azimuth = [[dictionaryRepresentation valueForKey: @"PlatonicAzimuth"] floatValue];
	coordPlatonic.zenith = [[dictionaryRepresentation valueForKey: @"PlatonicZenith"] floatValue];
	
	coordPhysical.azimuth = [[dictionaryRepresentation valueForKey: @"PhysicalAzimuth"] floatValue];
	coordPhysical.zenith = [[dictionaryRepresentation valueForKey: @"PhysicalZenith"] floatValue];
	coordPhysical.radius = [[dictionaryRepresentation valueForKey: @"PhysicalRadius"] floatValue];
	[self setCoordPlatonic: coordPlatonic];
	[self setCoordPhysical: coordPhysical];
}

#pragma mark _____ ZKMNRSpeakerPositionInternal
- (void)setRingNumber:(unsigned)ringNumber { _ringNumber = ringNumber; }
- (void)setLayoutIndex:(unsigned)layoutIndex { _layoutIndex = layoutIndex; }

#pragma mark _____ NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	ZKMNRSphericalCoordinateEncode(_coordPlatonic, @"Platonic", aCoder);
	ZKMNRSphericalCoordinateEncode(_coordPhysical, @"Physical", aCoder);	
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [self init])) {
		[self release];
		return nil;
	}
	
	_coordPlatonic = ZKMNRSphericalCoordinateDecode(@"Platonic", aDecoder);
	_coordPhysical = ZKMNRSphericalCoordinateDecode(@"Physical", aDecoder);	
	_coordRectangular	= ZKMNRSphericalCoordinateToRectangular(_coordPhysical);
	
	return self;
}

@end

@implementation ZKMNRSpeakerLayout

- (void)dealloc
{
	if (_speakerLayoutName) [_speakerLayoutName release];
	if (_numberOfSpeakersPerRing) [_numberOfSpeakersPerRing release];
	if (_speakerPositions) [_speakerPositions release];
	if (_speakerPositionRings) [_speakerPositionRings release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	_speakerLayoutName = nil;
	_numberOfSpeakersPerRing = [[NSMutableArray alloc] init];
	_speakerPositions = [[NSMutableArray alloc] init];
	_speakerPositionRings = [[NSMutableArray alloc] init];
	_isMutable = YES;
	
	return self;
}

#pragma mark _____ Accessors
- (NSString *)speakerLayoutName { return _speakerLayoutName; }
- (void)setSpeakerLayoutName:(NSString *)speakerLayoutName
{
	if (_speakerLayoutName != speakerLayoutName) {
		if (_speakerLayoutName) [_speakerLayoutName release]; _speakerLayoutName = nil;
		if (speakerLayoutName) 
			_speakerLayoutName = [[NSString alloc] initWithString: speakerLayoutName];
	}
}

- (NSArray *)speakerPositionRings { return _speakerPositionRings; }
- (void)setSpeakerPositionRings:(NSArray *)speakerPositionRings
{
	[self beginEditing];
	unsigned i, count = [speakerPositionRings count];
	[self setNumberOfRings: count];

	for (i = 0; i < count; i++) {
		// copy the positions
		[[self ringAtIndex: i] addObjectsFromArray: [speakerPositionRings objectAtIndex: i]];
	}
	[self endEditing];
}

- (NSArray *)speakerPositions { return _speakerPositions; }

- (NSArray *)numberOfSpeakersPerRing { return _numberOfSpeakersPerRing; }

- (unsigned)numberOfRings { return [_speakerPositionRings count]; }
- (unsigned)numberOfSpeakers { return [_speakerPositions count]; }

#pragma mark _____ Serialization
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableArray* speakerRingDicts = [NSMutableArray array];
	NSEnumerator* speakerRings = [[self speakerPositionRings] objectEnumerator];
	NSArray* speakerRing;
	while (speakerRing = [speakerRings nextObject]) {
		NSMutableArray* speakerDicts = [NSMutableArray array];
		NSEnumerator* speakers = [speakerRing objectEnumerator];
		ZKMNRSpeakerPosition* speaker;
		while (speaker = [speakers nextObject])
			[speakerDicts addObject: [speaker dictionaryRepresentation]];
		[speakerRingDicts addObject: speakerDicts];
	}
	return 
		[NSDictionary dictionaryWithObjectsAndKeys: 
			speakerRingDicts, @"Speakers", 
			[self speakerLayoutName], @"SpeakerLayoutName", nil];
}

- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation
{
	NSMutableArray* speakerRings = [NSMutableArray array];
	NSEnumerator* speakerRingDicts = [[dictionaryRepresentation valueForKey: @"Speakers"] objectEnumerator];
	NSArray* speakerRing;
	while (speakerRing = [speakerRingDicts nextObject]) {
		NSMutableArray* ring = [NSMutableArray array];
		NSEnumerator* speakerDicts = [speakerRing objectEnumerator];
		NSDictionary* speakerDict;
		while (speakerDict = [speakerDicts nextObject]) {
			ZKMNRSpeakerPosition* speaker = [[ZKMNRSpeakerPosition alloc] init];
			[speaker setFromDictionaryRepresentation: speakerDict];
			[ring addObject: speaker];
			[speaker release];
		}
		[speakerRings addObject: ring];
	}
	[self setSpeakerPositionRings: speakerRings];
	[self setSpeakerLayoutName: [dictionaryRepresentation valueForKey: @"SpeakerLayoutName"]];
}

#pragma mark _____ Queries
- (BOOL)isPlanar
{
	if([_speakerPositionRings count]<2) {
		return YES;
	}

	// allCoplanar ?
	unsigned i, count = [_speakerPositions count];
	float z;
	for (i = 0; i < count; i++) {
		ZKMNRRectangularCoordinate coord = [[_speakerPositions objectAtIndex: i] coordRectangular];
		if(i==0) z = coord.z;
		
		if (coord.z != z) {
			return NO;
		}
	}
		
	return YES;
}

- (BOOL)hasBottomHemisphere
{
	if([_speakerPositionRings count]<2) {
		return NO;
	}

	// any speakers below z = 0?
	unsigned i, count = [_speakerPositions count];
	for (i = 0; i < count; i++) {
		ZKMNRRectangularCoordinate coord = [[_speakerPositions objectAtIndex: i] coordRectangular];
		if (coord.z < 0.f) return YES;
	}
		
	return NO;
}

#pragma mark _____ ZKMNRSpeakerLayoutEditing
- (void)beginEditing 
{ 
	// clear the existing state
	[_numberOfSpeakersPerRing removeAllObjects];
	[_speakerPositionRings removeAllObjects];
	[_speakerPositions removeAllObjects];
}
- (void)endEditing
{
	unsigned i, count = [self numberOfRings];
	unsigned layoutIndex = 0;
	for (i = 0; i < count; i++) {
		NSMutableArray* ring = [self ringAtIndex: i];
		[_numberOfSpeakersPerRing addObject: [NSNumber numberWithUnsignedInt: [ring count]]];
		
		// sort them
		[ring sortUsingSelector: @selector(compare:)];
		
		// let the positions know which ring they are in and where in the ring they are
		unsigned j, ringCount = [ring count];
		for (j = 0; j < ringCount; j++) {
			ZKMNRSpeakerPosition* pos = [ring objectAtIndex: j];
			[pos setRingNumber: i];
			[pos setLayoutIndex: layoutIndex++];
		}
		[_speakerPositions addObjectsFromArray: ring];
	}
}

//  Editing
- (void)setNumberOfRings:(unsigned)numberOfRings
{
	unsigned i, count = numberOfRings;
	for (i = 0; i < count; ++i) {
		NSMutableArray* ring = [[NSMutableArray alloc] init];
		[_speakerPositionRings addObject: ring];
		[ring release];
	}
}

- (NSMutableArray *)ringAtIndex:(unsigned)idx
{
	return [_speakerPositionRings objectAtIndex: idx];
}

#pragma mark _____ NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	if ([aCoder allowsKeyedCoding]) {
		[aCoder encodeObject: _speakerLayoutName forKey: @"SpeakerLayoutName"];
		[aCoder encodeObject: _speakerPositionRings forKey: @"SpeakerPositionRings"];
	} else {
		[aCoder encodeObject: _speakerLayoutName];	
		[aCoder encodeObject: _speakerPositionRings];
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (!(self = [self init])) {
		[self release];
		return nil;
	}

	NSString* layoutName; NSArray* positionRings;
	if ([aDecoder allowsKeyedCoding]) {
		layoutName = [aDecoder decodeObjectForKey: @"SpeakerLayoutName"];
		positionRings = [aDecoder decodeObjectForKey: @"SpeakerPositionRings"];
	} else {
		layoutName = [aDecoder decodeObject];
		positionRings = [aDecoder decodeObject];
	}
	
	[self setSpeakerLayoutName: layoutName];
	[self setSpeakerPositionRings: positionRings];	
	
	return self;
}

#pragma mark _____ ZKMORConduitLogging
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	unsigned numRings = [self numberOfRings];
	unsigned numSpeakers = [self numberOfSpeakers];
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(level, source, CFSTR("%@%s%@ name: %@, number of rings: %u number of speakers: %u"), tag, indentStr, self, [self speakerLayoutName], numRings, numSpeakers);
}

@end
