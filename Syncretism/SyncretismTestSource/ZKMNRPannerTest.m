//
//  ZKMNRPannerTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 09.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRPannerTest.h"


@implementation ZKMNRPannerTest

- (ZKMNRSpeakerLayout *)quadraphonicLayout
{
	NSMutableArray* speakers = [NSMutableArray arrayWithCapacity: 4];

	// set speaker positions
	ZKMNRRectangularCoordinate	physicalRect;
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
	return layout;
}

- (void)testPannerCofficients
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

- (void)testSpeakerFinding
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

@end
