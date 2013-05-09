//
//  ZKMRNSimpleMap.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNSimpleMap.h"


@implementation ZKMRNSimpleMap

#pragma mark _____ ZKMRNChannelMap Overrides
- (void)setVolume:(float)volume forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	unsigned i, count = _cachedNumberOfOutputs;
		// clear the row
	for (i = 0; i < count; i++) _crosspoints[inputNum * _cachedNumberOfOutputs + i] = 0.f;
		// set the new value
	_crosspoints[inputNum * _cachedNumberOfOutputs + outputNum] = volume;
	[self storeCrosspoints];
}

#pragma mark _____ Accessors
- (int)outputForInput:(unsigned)inputNum
{
	unsigned numInputs = [[self valueForKey: @"numberOfInputs"] unsignedIntValue];
	unsigned i, numOutputs = [[self valueForKey: @"numberOfOutputs"] unsignedIntValue];

	if (inputNum >= numInputs) return -1;
	
	for (i = 0; i < numOutputs; i++)
		if ([self volumeForCrosspointInput: inputNum output: i] > 0.f)
			return i;
	return -1;
}

- (void)setOutput:(unsigned)outputNum forInput:(unsigned)inputNum
{
	[self setVolume: 1.f forCrosspointInput: inputNum output: outputNum];
}

@end
