//
//  ZKMNRSpeakerLayoutTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 25.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRSpeakerLayoutTest.h"

static BOOL FloatsAreEffectivelyEqual(float float1, float float2)
{
	return fabsf(float2 - float1) < 0.001;
}


@implementation ZKMNRSpeakerLayoutTest

- (void)testSpeakerLayout
{
	NSMutableArray* speakers = [NSMutableArray arrayWithCapacity: 4];

	// set speaker positions
	ZKMNRRectangularCoordinateCPP	physicalRect;
	ZKMNRSpeakerPosition* position;
	
	// left front
	physicalRect.x = 1.f;
	physicalRect.y = 1.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordRectangular: physicalRect];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
				
	// right front
	physicalRect.x = 1.f;
	physicalRect.y = -1.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordRectangular: physicalRect];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	// left rear
	physicalRect.x = -1.f;
	physicalRect.y = 1.f;
	physicalRect.z = 0.0f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordRectangular: physicalRect];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
				
	// right rear
	physicalRect.x = -1.f;
	physicalRect.y = -1.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordRectangular: physicalRect];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setSpeakerLayoutName: @"Quadraphonic"];
	[layout setSpeakerPositionRings: [NSArray arrayWithObject: speakers]];
	
	STAssertEquals([layout numberOfRings], (unsigned) 1, @"Quadrophonic layout should have 1 ring");
	STAssertEquals([layout numberOfSpeakers], (unsigned) 4, @"Quadrophonic layout should have 4 speakers");
	
	STAssertEquals([[layout numberOfSpeakersPerRing] objectAtIndex: 0], [NSNumber numberWithUnsignedInt: 4], @"Quadrophonic layout should have 4 speakers in 1 ring");
	
	// check the positions
	ZKMNRSphericalCoordinateCPP	platonic;


	position = [[layout speakerPositions] objectAtIndex: 0];
	STAssertEquals([position ringNumber], (int) 0, @"All quad speakers should be in ring number 0");
	physicalRect = [position coordRectangular];
	BOOL isLeftRear = FloatsAreEffectivelyEqual(physicalRect.x, -1.f) && FloatsAreEffectivelyEqual(physicalRect.y, 1.f);
	STAssertTrue(isLeftRear, @"Speaker 0 rectangular should be {-1.f, 1.f}, not {%.2f, %.2f}", physicalRect.x, physicalRect.y);
	platonic = [position coordPlatonic];
	isLeftRear = FloatsAreEffectivelyEqual(platonic.azimuth, 0.75f) && FloatsAreEffectivelyEqual(platonic.zenith, 0.f) && FloatsAreEffectivelyEqual(platonic.radius, 1.f);
	STAssertTrue(isLeftRear, @"Speaker 0 platonic should be {0.75f, 0.f}, not {%.2f, %.2f}", platonic.azimuth, platonic.zenith);
	
	position = [[layout speakerPositions] objectAtIndex: 1];
	STAssertEquals([position ringNumber], (int) 0, @"All quad speakers should be in ring number 0");
	physicalRect = [position coordRectangular];
	BOOL isLeftFront = FloatsAreEffectivelyEqual(physicalRect.x, 1.f) && FloatsAreEffectivelyEqual(physicalRect.y, 1.f);
	STAssertTrue(isLeftFront, @"Speaker 1 rectangular should be {1.f, 1.f}, not {%.2f, %.2f}", physicalRect.x, physicalRect.y);
	platonic = [position coordPlatonic];
	isLeftFront = FloatsAreEffectivelyEqual(platonic.azimuth, 0.25f) && FloatsAreEffectivelyEqual(platonic.zenith, 0.f) && FloatsAreEffectivelyEqual(platonic.radius, 1.f);
	STAssertTrue(isLeftFront, @"Speaker 1 platonic should be {0.25f, 0.f}, not {%.2f, %.2f}", platonic.azimuth, platonic.zenith);
	
	position = [[layout speakerPositions] objectAtIndex: 2];
	STAssertEquals([position ringNumber], (int) 0, @"All quad speakers should be in ring number 0");
	physicalRect = [position coordRectangular];
	BOOL isRightFront = FloatsAreEffectivelyEqual(physicalRect.x, 1.f) && FloatsAreEffectivelyEqual(physicalRect.y, -1.f);
	STAssertTrue(isRightFront, @"Speaker 2 rectangular should be {1.f, -1.f}, not {%.2f, %.2f}", physicalRect.x, physicalRect.y);
	platonic = [position coordPlatonic];
	isRightFront = FloatsAreEffectivelyEqual(platonic.azimuth, -0.25f) && FloatsAreEffectivelyEqual(platonic.zenith, 0.f) && FloatsAreEffectivelyEqual(platonic.radius, 1.f);
	STAssertTrue(isRightFront, @"Speaker 2 platonic should be {-0.25f, 0.f}, not {%.2f, %.2f}", platonic.azimuth, platonic.zenith);
	
	position = [[layout speakerPositions] objectAtIndex: 3];
	STAssertEquals([position ringNumber], (int) 0, @"All quad speakers should be in ring number 0");
	physicalRect = [position coordRectangular];
	BOOL isRightRear = FloatsAreEffectivelyEqual(physicalRect.x, -1.f) && FloatsAreEffectivelyEqual(physicalRect.y, -1.f);
	STAssertTrue(isRightRear, @"Speaker 3 rectangular should be {-1.f, -1.f}, not {%.2f, %.2f}", physicalRect.x, physicalRect.y);
	platonic = [position coordPlatonic];
	isRightRear = FloatsAreEffectivelyEqual(platonic.azimuth, -0.75f) && FloatsAreEffectivelyEqual(platonic.zenith, 0.f) && FloatsAreEffectivelyEqual(platonic.radius, 1.f);
	STAssertTrue(isRightRear, @"Speaker 3 platonic should be {-0.75f, 0.f}, not {%.2f, %.2f}", platonic.azimuth, platonic.zenith);
	
	[layout release];
}

- (ZKMNRSpeakerLayout *)fiveDot0Layout
{
	NSMutableArray* speakers = [NSMutableArray arrayWithCapacity: 5];

	// set speaker positions
	ZKMNRSphericalCoordinate	coord = { 0.f, 0.f, 1.f };
	ZKMNRSpeakerPosition*		position;
	
	// left front
	coord.azimuth = 30.f / 180.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];

				
	// right front
	coord.azimuth = -30.f / 180.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	// center
	coord.azimuth = 0.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	// left rear
	coord.azimuth = 110.f / 180.f;		
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
				
	// right rear
	coord.azimuth = -110.f / 180.f;		
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setSpeakerLayoutName: @"5.0"];
	[layout setSpeakerPositionRings: [NSArray arrayWithObject: speakers]];
	return [layout autorelease];
}

- (void)testSerialization
{
	ZKMNRSpeakerLayout* fiveDot0Layout = [self fiveDot0Layout];
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setFromDictionaryRepresentation: [fiveDot0Layout dictionaryRepresentation]];
	
	NSEnumerator* speakerPositions = [[layout speakerPositions] objectEnumerator];
	ZKMNRSpeakerPosition* layoutPosition;
	unsigned i;
	for (i = 0; layoutPosition = [speakerPositions nextObject]; ++i) {
		ZKMNRSpeakerPosition* pos = [[fiveDot0Layout speakerPositions] objectAtIndex: i];
		STAssertEquals([layoutPosition coordPlatonic].azimuth, [pos coordPlatonic].azimuth,
			@"Platonic azimuth does not match");
		STAssertEquals([layoutPosition coordPlatonic].zenith, [pos coordPlatonic].zenith,
			@"Platonic zenith does not match");
			
		STAssertEquals([layoutPosition coordPhysical].azimuth, [pos coordPhysical].azimuth,
			@"Physical azimuth does not match");
		STAssertEquals([layoutPosition coordPhysical].zenith, [pos coordPhysical].zenith,
			@"Physical zenith does not match");
		STAssertEquals([layoutPosition coordPhysical].radius, [pos coordPhysical].radius,
			@"Physical radius does not match");
			
		STAssertEquals([layoutPosition coordRectangular].x, [pos coordRectangular].x,
			@"Physical x does not match");
		STAssertEquals([layoutPosition coordRectangular].y, [pos coordRectangular].y,
			@"Physical y does not match");
		STAssertEquals([layoutPosition coordRectangular].z, [pos coordRectangular].z,
			@"Physical z does not match");
	}
	
	[layout release];
}

@end
