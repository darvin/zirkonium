//
//  ZKMNRPannerTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 09.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRPannerTest.h"


@implementation ZKMNRPannerTest

- (void)addToSpeakers:(NSMutableArray *)speakers speakerWithCoordinate:(ZKMNRRectangularCoordinate *)physicalRect
{
	ZKMNRSpeakerPosition *position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordRectangular: *physicalRect];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
}

- (void)addQuadraphonicGroupToSpeakers:(NSMutableArray *)speakers zCoord:(float)z scale:(float)xyScale
{
	ZKMNRRectangularCoordinate	physicalRect;
	physicalRect.z = z;
	
	// left front
	physicalRect.x = 1.f * xyScale;
	physicalRect.y = 1.f * xyScale;
	[self addToSpeakers: speakers speakerWithCoordinate: &physicalRect];
				
	// right front
	physicalRect.x = 1.f * xyScale;
	physicalRect.y = -1.f * xyScale;
	[self addToSpeakers: speakers speakerWithCoordinate: &physicalRect];
	
	// left rear
	physicalRect.x = -1.f * xyScale;
	physicalRect.y = 1.f * xyScale;
	[self addToSpeakers: speakers speakerWithCoordinate: &physicalRect];
				
	// right rear
	physicalRect.x = -1.f * xyScale;
	physicalRect.y = -1.f * xyScale;
	[self addToSpeakers: speakers speakerWithCoordinate: &physicalRect];
}

- (ZKMNRSpeakerLayout *)quadraphonicLayout
{
	NSMutableArray* speakers = [NSMutableArray arrayWithCapacity: 4];
	
	[self addQuadraphonicGroupToSpeakers: speakers zCoord: 0.f scale: 1.f];
	
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setSpeakerLayoutName: @"Quadraphonic"];
	[layout setSpeakerPositionRings: [NSArray arrayWithObject: speakers]];
	return layout;
}

- (ZKMNRSpeakerLayout *)sphereLayout
{
	NSMutableArray* topRing = [NSMutableArray arrayWithCapacity: 4];
	[self addQuadraphonicGroupToSpeakers: topRing zCoord: 0.5f scale: 0.5f];

	NSMutableArray* centerRing = [NSMutableArray arrayWithCapacity: 4];
	[self addQuadraphonicGroupToSpeakers: centerRing zCoord: 0.f scale: 1.f];

	NSMutableArray* bottomRing = [NSMutableArray arrayWithCapacity: 4];
	[self addQuadraphonicGroupToSpeakers: bottomRing zCoord: -0.5f scale: 0.5f];
	
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setSpeakerLayoutName: @"Sphere12"];
	[layout setSpeakerPositionRings: [NSArray arrayWithObjects: topRing, centerRing, bottomRing, nil]];
	return layout;
}

- (void)testPannerCofficientsInQuadLayout
{
	ZKMNRSpeakerLayout* quadLayout = [self quadraphonicLayout];
	ZKMNRVBAPPanner* panner = [[ZKMNRVBAPPanner alloc] init];
	[panner setSpeakerLayout: quadLayout];
	[quadLayout release];
	STAssertTrue([quadLayout retainCount] == 1, @"The panner should retain the speaker layout (RC: %u)", [quadLayout retainCount]);
	
	ZKMNRPannerSource* source = [[ZKMNRPannerSource alloc] init];
	[panner registerPannerSource: source];
	[source release];
	
	STAssertTrue([source retainCount] == 1, @"The panner should retain the source (RC: %u)", [source retainCount]);
	STAssertTrue([source numberOfMixerCoefficients] == 4, @"A panner position on a quadraphonic layout should have 4 coeffs");
		
	ZKMNRSphericalCoordinate point = { 0.f, 0.f, 1.f };
	[source setCenter: point];
	// straight ahead should have mixer coeffs of [LR LF RF RR] == [0.0, 0.7, 0.7, 0.0]
	float* mixerCoeffs = [source mixerCoefficients];
	STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
	STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.7f, 0.01, @"LF coeff should be 0.7");
	STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.7f, 0.01, @"RF coeff should be 0.7");
	STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
		
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
		
	point.azimuth = -1.f;
	[source setCenter: point];
	// directly behind should have mixer coeffs of [LR LF RF RR] == [0.7, 0.0, 0.0, 0.7]
	mixerCoeffs = [source mixerCoefficients];
	STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.7f, 0.01, @"LR coeff should be 0.7");
	STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
	STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
	STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.7f, 0.01, @"RR coeff should be 0.7");
		
	ZKMNRSphericalCoordinateSpan span = { 2.f, 0.f };
	[source setCenter: point span: span gain: 1.f];
	// all the speakers should be used here
	mixerCoeffs = [source mixerCoefficients];
	STAssertTrue(mixerCoeffs[0] > 0.f, @"LR coeff should be > 0");
	STAssertTrue(mixerCoeffs[1] > 0.f, @"LF coeff should be > 0");
	STAssertTrue(mixerCoeffs[2] > 0.f, @"RF coeff should be > 0");
	STAssertTrue(mixerCoeffs[3] > 0.f, @"RR coeff should be > 0");
	
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
		
		
	point.azimuth = 0.f;
	point.zenith = 0.5f;
	span.azimuthSpan = 2.0f;
	span.zenithSpan = 0.0f;
	[source setCenter: point span: span gain: 1.f];
	// directly above with span 2 should have mixer coeffs where everything is greater than 0
	mixerCoeffs = [source mixerCoefficients];
	STAssertTrue(mixerCoeffs[0] > 0.f, @"LR coeff should be > 0");
	STAssertTrue(mixerCoeffs[1] > 0.f, @"LF coeff should be > 0");
	STAssertTrue(mixerCoeffs[2] > 0.f, @"RF coeff should be > 0");
	STAssertTrue(mixerCoeffs[3] > 0.f, @"RR coeff should be > 0");
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
	
	ZKMNRRectangularCoordinate rectPoint = { 1.f, 0.f, 0.f };
	ZKMNRRectangularCoordinateSpan rectSpan = { 0.f, 0.f };
	[source setCenterRectangular: rectPoint span: rectSpan gain: 1.0];
	// straight ahead should have mixer coeffs of [LR LF RF RR] == [0.0, 0.7, 0.7, 0.0]
	mixerCoeffs = [source mixerCoefficients];
	STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
	STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.7f, 0.01, @"LF coeff should be 0.7");
	STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.7f, 0.01, @"RF coeff should be 0.7");
	STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
		
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
	
	// check proper retain/release behavior
	[quadLayout retain]; [source retain];
	[panner release];
	STAssertTrue([quadLayout retainCount] == 1, @"The panner should release the speaker layout when released (RC: %u)", [quadLayout retainCount]);
	STAssertTrue([source retainCount] == 1, @"The panner should release the source when released (RC: %u)", [source retainCount]);
	[quadLayout release]; [source release];	
}

- (NSUInteger)countNonZeroMixerCoeffs:(ZKMNRPannerSource *)source
{
	float* mixerCoeffs = [source mixerCoefficients];
	NSUInteger nonZeroCoeffCount = 0;
	NSUInteger i, count = [source numberOfMixerCoefficients];
	for (i = 0; i < count; ++i) {
		if (fabsf(mixerCoeffs[i]) > 0.0001f) nonZeroCoeffCount++;
	}
	
	return nonZeroCoeffCount;
}

- (void)testPannerCofficientsInSphereLayout
{
	ZKMNRSpeakerLayout* sphereLayout = [self sphereLayout];
	ZKMNRVBAPPanner* panner = [[ZKMNRVBAPPanner alloc] init];
	[panner setSpeakerLayout: sphereLayout];
	[sphereLayout release];
	
	ZKMNRPannerSource* source = [[ZKMNRPannerSource alloc] init];
	[panner registerPannerSource: source];
	[source release];
	
	STAssertTrue([source numberOfMixerCoefficients] == 12, @"A panner position on a sphere layout should have 12 coeffs");
		
	ZKMNRSphericalCoordinate point = { 0.f, 0.f, 1.f };
	[source setCenter: point];
	// straight ahead should have activate the front two speakers
	NSUInteger nonZeroCoeffCount = [self countNonZeroMixerCoeffs: source];
	STAssertEquals(nonZeroCoeffCount, (NSUInteger) 2, @"There should be exactly 2 non-zero coefficients.");
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
		
	point.azimuth = -1.f;
	[source setCenter: point];
	nonZeroCoeffCount = [self countNonZeroMixerCoeffs: source];
	STAssertEquals(nonZeroCoeffCount, (NSUInteger) 2, @"There should be exactly 2 non-zero coefficients.");
		
	ZKMNRSphericalCoordinateSpan span = { 2.f, 0.f };
	[source setCenter: point span: span gain: 1.f];
	// all the speakers in the center ring should be used here
	nonZeroCoeffCount = [self countNonZeroMixerCoeffs: source];
	STAssertEquals(nonZeroCoeffCount, (NSUInteger) 4, @"There should be exactly 4 non-zero coefficients.");
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
		
		
	point.azimuth = 0.f;
	point.zenith = 0.2f;
	span.azimuthSpan = 2.0f;
	span.zenithSpan = 0.0f;
	[source setCenter: point span: span gain: 1.f];
	// in the top half with azimuth span of 2 should activate all speakers in the top half
	nonZeroCoeffCount = [self countNonZeroMixerCoeffs: source];
	STAssertEquals(nonZeroCoeffCount, (NSUInteger) 7, @"There should be exactly 7 non-zero coefficients.");
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
	
	ZKMNRRectangularCoordinate rectPoint = { 1.f, 0.f, 0.f };
	ZKMNRRectangularCoordinateSpan rectSpan = { 0.f, 0.f };
	[source setCenterRectangular: rectPoint span: rectSpan gain: 1.0];
	// straight ahead should have activate the front two speakers
	nonZeroCoeffCount = [self countNonZeroMixerCoeffs: source];
	STAssertEquals(nonZeroCoeffCount, (NSUInteger) 2, @"There should be exactly 2 non-zero coefficients.");
	STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
	
	[panner release];
}

- (void)testMute
{
	ZKMNRSpeakerLayout* quadLayout = [self quadraphonicLayout];
	ZKMNRVBAPPanner* panner = [[ZKMNRVBAPPanner alloc] init];
	[panner setSpeakerLayout: quadLayout];
	[quadLayout release];
	
	ZKMNRPannerSource* source = [[ZKMNRPannerSource alloc] init];
	[panner registerPannerSource: source];
	[source release];
	
	[source setMute: YES];
		
	{
		// When Muted, everything should be zero
		ZKMNRSphericalCoordinate point = { 0.f, 0.f, 1.f };
		[source setCenter: point];
		float* mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
			
		point.azimuth = -1.f;
		[source setCenter: point];
		mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
			
		ZKMNRSphericalCoordinateSpan span = { 2.f, 0.f };
		[source setCenter: point span: span gain: 1.f];
		mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
			
		point.azimuth = 0.f;
		point.zenith = 0.5f;
		span.azimuthSpan = 2.0f;
		span.zenithSpan = 0.0f;
		[source setCenter: point span: span gain: 1.f];
		mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
		
		ZKMNRRectangularCoordinate rectPoint = { 1.f, 0.f, 0.f };
		ZKMNRRectangularCoordinateSpan rectSpan = { 0.f, 0.f };
		[source setCenterRectangular: rectPoint span: rectSpan gain: 1.0];
		mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
	}
	
	[source setMute: NO];
	
	{
		// When not muted, everything should work correctly
		ZKMNRSphericalCoordinate point = { 0.f, 0.f, 1.f };
		ZKMNRSphericalCoordinateSpan span = { 0.f, 0.f };
		[source setCenter: point span: span gain: 1.f];		
		// straight ahead should have mixer coeffs of [LR LF RF RR] == [0.0, 0.7, 0.7, 0.0]
		float* mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.7f, 0.01, @"LF coeff should be 0.7");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.7f, 0.01, @"RF coeff should be 0.7");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
			
		STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
			
		point.azimuth = -1.f;
		[source setCenter: point];
		// directly behind should have mixer coeffs of [LR LF RF RR] == [0.7, 0.0, 0.0, 0.7]
		mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.7f, 0.01, @"LR coeff should be 0.7");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.f, 0.01, @"LF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.f, 0.01, @"RF coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.7f, 0.01, @"RR coeff should be 0.7");
			
		span.azimuthSpan = 2.f;
		span.zenithSpan = 0.f;
		[source setCenter: point span: span gain: 1.f];
		// all the speakers should be used here
		mixerCoeffs = [source mixerCoefficients];
		STAssertTrue(mixerCoeffs[0] > 0.f, @"LR coeff should be > 0");
		STAssertTrue(mixerCoeffs[1] > 0.f, @"LF coeff should be > 0");
		STAssertTrue(mixerCoeffs[2] > 0.f, @"RF coeff should be > 0");
		STAssertTrue(mixerCoeffs[3] > 0.f, @"RR coeff should be > 0");
		
		STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
			
			
		point.azimuth = 0.f;
		point.zenith = 0.5f;
		span.azimuthSpan = 2.0f;
		span.zenithSpan = 0.0f;
		[source setCenter: point span: span gain: 1.f];
		// directly above with span 2 should have mixer coeffs where everything is greater than 0
		mixerCoeffs = [source mixerCoefficients];
		STAssertTrue(mixerCoeffs[0] > 0.f, @"LR coeff should be > 0");
		STAssertTrue(mixerCoeffs[1] > 0.f, @"LF coeff should be > 0");
		STAssertTrue(mixerCoeffs[2] > 0.f, @"RF coeff should be > 0");
		STAssertTrue(mixerCoeffs[3] > 0.f, @"RR coeff should be > 0");
		STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
		
		ZKMNRRectangularCoordinate rectPoint = { 1.f, 0.f, 0.f };
		ZKMNRRectangularCoordinateSpan rectSpan = { 0.f, 0.f };
		[source setCenterRectangular: rectPoint span: rectSpan gain: 1.0];
		// straight ahead should have mixer coeffs of [LR LF RF RR] == [0.0, 0.7, 0.7, 0.0]
		mixerCoeffs = [source mixerCoefficients];
		STAssertEqualsWithAccuracy(mixerCoeffs[0], 0.f, 0.01, @"LR coeff should be 0.");
		STAssertEqualsWithAccuracy(mixerCoeffs[1], 0.7f, 0.01, @"LF coeff should be 0.7");
		STAssertEqualsWithAccuracy(mixerCoeffs[2], 0.7f, 0.01, @"RF coeff should be 0.7");
		STAssertEqualsWithAccuracy(mixerCoeffs[3], 0.f, 0.01, @"RR coeff should be 0.");
			
		STAssertEqualsWithAccuracy([source pannerGain], 1.f, 0.001, @"Panning should not change the gain");
	}

	[panner release];
}

- (void)testSpeakerFindingInQuadLayout
{
	ZKMNRSpeakerLayout* quadLayout = [self quadraphonicLayout];
	ZKMNRVBAPPanner* panner = [[ZKMNRVBAPPanner alloc] init];
	[panner setSpeakerLayout: quadLayout];
	[quadLayout release];
	
	ZKMNRPannerSource* source = [[ZKMNRPannerSource alloc] init];
	[panner registerPannerSource: source];
	[source release];
		
	ZKMNRSphericalCoordinate point = { 0.25f, 0.f, 1.f };
	ZKMNRSpeakerPosition* closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.25f, 0.f, 1.f } is nil");
	
	ZKMNRSphericalCoordinate speakerPos = [closestSpeaker coordPlatonic];
	STAssertEqualsWithAccuracy(speakerPos.azimuth, 0.25f, 0.01, @"Speaker position should be { 0.25f, 0.f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.zenith, 0.f, 0.01, @"Speaker position should be { 0.25f, 0.f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.radius, 1.f, 0.01, @"Speaker position should be { 0.25f, 0.f, 1.f }");
	
		// { 0.8f, 0.f, 1.f }
	point.azimuth = 0.8f;
	closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.8f, 0.f, 1.f } is nil");
	
	speakerPos = [closestSpeaker coordPlatonic];
	STAssertEqualsWithAccuracy(speakerPos.azimuth, 0.75f, 0.01, @"Speaker position should be { 0.75f, 0.f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.zenith, 0.f, 0.01, @"Speaker position should be { 0.75f, 0.f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.radius, 1.f, 0.01, @"Speaker position should be { 0.75f, 0.f, 1.f }");
	
	[panner release];
}

- (void)testSpeakerFindingInSphereLayout
{
	ZKMNRSpeakerLayout* sphereLayout = [self sphereLayout];
	ZKMNRVBAPPanner* panner = [[ZKMNRVBAPPanner alloc] init];
	[panner setSpeakerLayout: sphereLayout];
	[sphereLayout release];
	
	ZKMNRPannerSource* source = [[ZKMNRPannerSource alloc] init];
	[panner registerPannerSource: source];
	[source release];
		
	ZKMNRSphericalCoordinate point = { 0.25f, 0.f, 1.f };
	ZKMNRSpeakerPosition* closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.25f, 0.f, 1.f } is nil");
	
	ZKMNRSphericalCoordinate speakerPos = [closestSpeaker coordPlatonic];
	STAssertEqualsWithAccuracy(speakerPos.azimuth, 0.25f, 0.01, @"Speaker position should be { 0.25f, 0.f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.zenith, 0.0f, 0.01, @"Speaker position should be { 0.25f, 0.19f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.radius, 1.f, 0.01, @"Speaker position should be { 0.25f, 0.f, 1.f }");
		// { 0.8f, 0.f, 1.f }
	point.azimuth = 0.8f;
	closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.8f, 0.f, 1.f } is nil");
	
	speakerPos = [closestSpeaker coordPlatonic];
	STAssertEqualsWithAccuracy(speakerPos.azimuth, 0.75f, 0.01, @"Speaker position should be { 0.75f, 0.f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.zenith, 0.0f, 0.01, @"Speaker position should be { 0.75f, 0.19f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.radius, 1.f, 0.01, @"Speaker position should be { 0.75f, 0.f, 1.f }");
	
		// { 0.25f, 0.5f, 1.f };
	point.azimuth = 0.25f;
	point.zenith = 0.5f;
	closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.25f, 0.5f, 1.f } is nil");
	
		// { 0.75f, -0.5f, 1.f };
	point.azimuth = 0.75f;
	point.zenith = -0.5f;
	closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.75f, -0.5f, 1.f } is nil");
	
		// { 0.25f, 0.2f, 1.f };
	point.azimuth = 0.25f;
	point.zenith = 0.2f;
	closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.25f, 0.2f, 1.f } is nil");
	
	speakerPos = [closestSpeaker coordPlatonic];
	STAssertEqualsWithAccuracy(speakerPos.azimuth, 0.25f, 0.01, @"Speaker position should be { 0.25f, 0.19f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.zenith, 0.19f, 0.01, @"Speaker position should be { 0.25f, 0.19f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.radius, 1.f, 0.01, @"Speaker position should be { 0.25f, 0.19f, 1.f }");
	
		// { 0.75f, -0.2f, 1.f };
	point.azimuth = 0.75f;
	point.zenith = -0.2f;
	closestSpeaker = [panner speakerClosestToPoint: point];
	STAssertNotNil(closestSpeaker, @"The speaker closest to point { 0.75f, -0.2f, 1.f } is nil");
	
	speakerPos = [closestSpeaker coordPlatonic];
	STAssertEqualsWithAccuracy(speakerPos.azimuth, 0.75f, 0.01, @"Speaker position should be { 0.75f, -0.19f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.zenith, -0.19f, 0.01, @"Speaker position should be { 0.75f, -0.19f, 1.f }");
	STAssertEqualsWithAccuracy(speakerPos.radius, 1.f, 0.01, @"Speaker position should be { 0.75f, -0.19f, 1.f }");		
	
	[panner release];
}

@end
