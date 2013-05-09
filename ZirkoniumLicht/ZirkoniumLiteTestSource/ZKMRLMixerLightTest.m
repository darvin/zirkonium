//
//  ZKMRLMixerLightTest.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 16.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLMixerLightTest.h"


@implementation ZKMRLMixerLightTest

- (void)setUp
{
	mixer = [[ZKMRLMixerLight alloc] init];
}

- (void)tearDown
{
	[mixer release];
}

- (void)testMixer
{
	[mixer setNumberOfInputChannels: 2];
	[mixer setNumberOfOutputChannels: 1];
	[mixer setColor: [NSColor redColor] forInput: 0];
	[mixer setColor: [NSColor blueColor] forInput: 1];

	[mixer updateOutputColors];
	NSColor* mixedColor = [mixer colorForOutput: 0];
	float r, g, b, a;
	[mixedColor getRed: &r green: &g blue: &b alpha: &a];
		// everything should be 0 until I open up the crosspoints
	STAssertEqualsWithAccuracy(r, 0.f, 0.001f, @"Red should be 1");
	STAssertEqualsWithAccuracy(g, 0.f, 0.001f, @"Green should be 0");
	STAssertEqualsWithAccuracy(b, 0.f, 0.001f, @"Blue should be 1");
	STAssertEqualsWithAccuracy(a, 1.f, 0.001f, @"Alpha should be 1");

		// open the crosspoints
	[mixer setToDiagonalLevels];
	[mixer updateOutputColors];
	mixedColor = [mixer colorForOutput: 0];
	[mixedColor getRed: &r green: &g blue: &b alpha: &a];
	STAssertEqualsWithAccuracy(r, 1.f, 0.001f, @"Red should be 1");
	STAssertEqualsWithAccuracy(g, 0.f, 0.001f, @"Green should be 0");
	STAssertEqualsWithAccuracy(b, 1.f, 0.001f, @"Blue should be 1");
	STAssertEqualsWithAccuracy(a, 1.f, 0.001f, @"Alpha should be 1");
}

@end
