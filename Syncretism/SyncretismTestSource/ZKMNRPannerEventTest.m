//
//  ZKMNRPannerEventTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 17.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRPannerEventTest.h"


@implementation ZKMNRPannerEventTest
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


- (void)setUp
{
	[super setUp];
	ZKMNRSpeakerLayout* quadLayout = [self quadraphonicLayout];
	panner = [[ZKMNRVBAPPanner alloc] init];
	[panner setSpeakerLayout: quadLayout];
	[quadLayout release];
	
	source = [[ZKMNRPannerSource alloc] init];
	[panner registerPannerSource: source];
	[source release];
	[panner setActiveSources: [NSArray arrayWithObject: source]];
	
	scheduler = [[ZKMNREventScheduler alloc] init];
	[scheduler setClock: [simulator clock]];
	[scheduler addTimeDependent: panner];
}

- (void)tearDown
{
	[scheduler release];
	[panner release];
	[super tearDown];
}


- (void)testPannerPosition
{
	ZKMNRSphericalCoordinate point = { 0.f, 0.f, 1.f };
	[source setCenter: point];
	
	ZKMNRPannerEvent* event1 = [[ZKMNRPannerEvent alloc] init];
	[event1 setDeltaAzimuth: 0.1];
	[event1 setStartTime: 0.25];
	[event1 setDuration: 0.25];
	[event1 setTarget: source];
	[scheduler scheduleEvent: event1];
	
	ZKMNRPannerEvent* event2 = [[ZKMNRPannerEvent alloc] init];
	[event2 setDeltaAzimuth: 0.2];
	[event2 setStartTime: 0.75];
	[event2 setDuration: 0.25];
	[event2 setTarget: source];
	[event2 setContinuationMode: kZKMNRContinuationMode_Continue];
	[scheduler scheduleEvent: event2];
	
	ZKMNRPannerEvent* event3 = [[ZKMNRPannerEvent alloc] init];
	[event3 setDeltaAzimuth: 0.1];
	[event3 setStartTime: 1.25];
	[event3 setDuration: 0.25];
	[event3 setTarget: source];
	[event3 setContinuationMode: kZKMNRContinuationMode_Retrograde];
	[scheduler scheduleEvent: event3];
	
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setGraph: graph];
	[simulator start];
		// 0.00 -> 0.23
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.f, 0.0001f, @"Center should not have moved");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.23 -> 0.46
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.09f, 0.02f, @"Center should be almost 0.1f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.46 -> 0.69
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.1f, 0.0001f, @"Center should be 0.1f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.69 -> 0.92
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.25f, 0.1f, @"Center should be almost 0.3f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.92 -> 1.15
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.4f, 0.1f, @"Center should be almost 0.4f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 1.15 -> 1.38
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.5f, 0.1f, @"Center should be 0.5f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 1.38 -> 1.61
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.5f, 0.1f, @"Center should be 0.5f");
	[simulator simulateNumCalls: 20 numFrames: 512];
	
	[event1 release], [event2 release], [event3 release];
}

- (void)testPannerPositionXY
{
	ZKMNRSphericalCoordinate point = { 0.f, 0.f, 1.f };
	[source setCenter: point];
	
	ZKMNRPannerEventXY* event1 = [[ZKMNRPannerEventXY alloc] init];
	[event1 setX: 1.0];
	[event1 setY: 1.0];
	[event1 setStartTime: 0.25];
	[event1 setDuration: 0.25];
	[event1 setTarget: source];
	[scheduler scheduleEvent: event1];
	
	ZKMNRPannerEventXY* event2 = [[ZKMNRPannerEventXY alloc] init];
	[event2 setX: -0.5];
	[event2 setY: -0.5];
	[event2 setStartTime: 0.75];
	[event2 setDuration: 0.25];
	[event2 setTarget: source];
//	[event2 setContinuationMode: kZKMNRContinuationMode_Continue];
	[scheduler scheduleEvent: event2];
	
	ZKMNRPannerEventXY* event3 = [[ZKMNRPannerEventXY alloc] init];
	[event3 setX: 0.0];
	[event3 setY: 1.0];	
	[event3 setStartTime: 1.25];
	[event3 setDuration: 0.25];
	[event3 setTarget: source];
//	[event3 setContinuationMode: kZKMNRContinuationMode_Retrograde];
	[scheduler scheduleEvent: event3];
	
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setGraph: graph];
	[simulator start];
		// 0.00 -> 0.23
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.f, 0.0001f, @"Center should not have moved");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.23 -> 0.46
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.25f, 0.05f, @"Center should be almost 0.25f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.46 -> 0.69
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.25f, 0.0001f, @"Center should be 0.25f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.69 -> 0.92
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, -0.75f, 0.1f, @"Center should be almost -0.75f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 0.92 -> 1.15
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, -0.75f, 0.0001f, @"Center should be -0.75f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 1.15 -> 1.38
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.67f, 0.1f, @"Center should be around 0.67f");
	[simulator simulateNumCalls: 20 numFrames: 512];
		// 1.38 -> 1.61
	[scheduler task: 0.23];
	STAssertEqualsWithAccuracy([source center].azimuth, 0.5f, 0.1f, @"Center should be 0.5f");
	[simulator simulateNumCalls: 20 numFrames: 512];
	
	[event1 release], [event2 release], [event3 release];
}


@end
