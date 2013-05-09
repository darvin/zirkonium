//
//  ZKMRNTestSource.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNTestSource.h"

@interface ZKMRNTestSource (ZKMRNTestSourcePrivate)
- (void)createNoiseGraph;
- (void)sourceTypeChanged;
@end


@implementation ZKMRNTestSource
#pragma mark _____ Accessors
- (ZKMORConduit *)conduit
{
	[self willAccessValueForKey: @"conduit"];
	ZKMORConduit* conduit = [self primitiveValueForKey: @"conduit"];
	[self didAccessValueForKey: @"conduit"];

	if (conduit == nil) {
		[self createNoiseGraph];
		conduit = _noiseGraph;
		[self setPrimitiveValue: conduit forKey: @"conduit"];
		[_noiseGraph release];
	}
	return conduit;
}

#pragma mark _____ Queries
- (BOOL)isConduitValid { return YES; }

#pragma mark _____ ZKMRNTestSourcePrivate
- (void)createNoiseGraph
{
	AudioStreamBasicDescription streamFormat;
	_noiseGraph = [[ZKMORGraph alloc] init];
	_pinkNoise = [[ZKMORPinkNoise alloc] init];
	_whiteNoise = [[ZKMORWhiteNoise alloc] init];
	_noiseMixer = [[ZKMORMixerMatrix alloc] init];
		// set up the conduits
	[_noiseMixer setNumberOfInputBuses: 2];
	[_noiseMixer setNumberOfOutputBuses: 1];
	[_noiseGraph setPurposeString: @"Graph for test source"];
	[_noiseMixer setPurposeString: @"Mixer for test source"];

	streamFormat = [[_pinkNoise outputBusAtIndex: 0] streamFormat];
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[_pinkNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_whiteNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_noiseMixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[_noiseMixer inputBusAtIndex: 1] setStreamFormat: streamFormat];
		// just send out a mono output, either pink or white noise
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[_noiseMixer outputBusAtIndex: 0] setStreamFormat: streamFormat];

	[_noiseGraph beginPatching];
		[_noiseGraph setHead: _noiseMixer];
		[_noiseGraph patchBus: [_pinkNoise outputBusAtIndex: 0] into: [_noiseMixer inputBusAtIndex: 0]];
		[_noiseGraph patchBus: [_whiteNoise outputBusAtIndex: 0] into: [_noiseMixer inputBusAtIndex: 1]];
		[_noiseGraph initialize];
	[_noiseGraph endPatching];
	[_pinkNoise release]; [_whiteNoise release]; [_noiseMixer release];
	[self sourceTypeChanged];
}

- (void)sourceTypeChanged
{
	unsigned sourceTypeIndex = [[self valueForKey: @"sourceType"] unsignedIntValue];
	[_noiseMixer setInputsAndOutputsOn];
	[_noiseMixer setMasterVolume: 0.25];
	[_noiseMixer setVolume: 1.f forCrosspointInput: sourceTypeIndex output: 0];	
	[_noiseMixer setVolume: 0.f forCrosspointInput: (sourceTypeIndex + 1) % 2 output: 0];
}

@end
