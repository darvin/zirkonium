//
//  ZKMORNoise.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORNoise.h"

typedef struct { @defs(ZKMORWhiteNoise) } ZKMORWhiteNoiseStruct;
typedef struct { @defs(ZKMORPinkNoise) } ZKMORPinkNoiseStruct;

static OSStatus WhiteNoiseRenderFunction(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;
	
	ZKMORWhiteNoiseStruct* theNoise = (ZKMORWhiteNoiseStruct*) SELF;
	int seed = theNoise->_seed;
	unsigned i, countBuffers = ioData->mNumberBuffers;
	float maxIntRecip = 1.f / (float) (0x7FFFFFFF);
	for (i = 0; i < countBuffers; i++) {
		unsigned j;
			// the conduit only uses de-interleaved float PCM buffers
		float* buffer = (float*) ioData->mBuffers[i].mData;
		for (j = 0; j < inNumberFrames; j++) {
			// generate a new pseudo-random 32-bit number using
			// the linear congruential method
			seed = (seed * 196314165) + 907633515;
			*buffer++ = seed * maxIntRecip;
		}
	}
	
	theNoise->_seed = seed;
	return noErr;
}

@implementation ZKMORWhiteNoise

- (id)init {
	if (self = [super init]) {
		_conduitType = kZKMORConduitType_Source;
		_numberOfOutputBuses = 1;
		_seed = time(NULL);
	}
	return self;
}

- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return _numberOfOutputBuses; }

- (void)setNumberOfBuses:(unsigned)numBuses scope:(AudioUnitScope)scope 
{ 
	if (kAudioUnitScope_Output == scope) {
		_numberOfOutputBuses = numBuses;	
		_areBusesInitialized = NO;
	}
}

- (BOOL)isNumberOfOutputBusesSettable { return YES; }
- (ZKMORRenderFunction)renderFunction { return WhiteNoiseRenderFunction; }

@end

// Calculate pseudo-random 32 bit number based on linear congruential method. 
static unsigned long GenerateRandomNumber(ZKMORPinkNoiseStruct* pink)
{
	pink->_seed = (pink->_seed * 196314165) + 907633515;
	return pink->_seed;
}

static float GeneratePinkSample(ZKMORPinkNoiseStruct* pink)
{
	long newRandom;
	long sum;
	float output;

		// Increment and mask index
	pink->_index = (pink->_index + 1) & pink->_indexMask;

		// If index is zero, don't update any random values.
	if(pink->_index != 0)
	{
			// Determine how many trailing zeros in PinkIndex.
			// This algorithm will hang if n==0 so test first.
		int numZeros = 0;
		int n = pink->_index;
		while((n & 1) == 0)
		{
			n = n >> 1;
			numZeros++;
		}

			// Replace the indexed ROWS random value.
			// Subtract and add back to RunningSum instead of adding all the random
			// values together. Only one changes each time.
		pink->_runningSum -= pink->_rows[numZeros];
		newRandom = ((long)GenerateRandomNumber(pink)) >> PINK_RANDOM_SHIFT;
		pink->_runningSum += newRandom;
		pink->_rows[numZeros] = newRandom;
	}
	
		// Add extra white noise value.
	newRandom = ((long)GenerateRandomNumber(pink)) >> PINK_RANDOM_SHIFT;
	sum = pink->_runningSum + newRandom;

		// Scale to range of -1.0 to 0.9999.
	output = pink->_scalar * sum;
	return output;
}

static OSStatus PinkNoiseRenderFunction(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) return noErr;
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) return noErr;
	
	ZKMORPinkNoiseStruct* pink = (ZKMORPinkNoiseStruct*) SELF;
	
	unsigned j;
		// the conduit only uses de-interleaved float PCM buffers
	float* buffer = (float*) ioData->mBuffers[0].mData;
	for (j = 0; j < inNumberFrames; j++) {
		*buffer++ = GeneratePinkSample(pink);
	}
	
	unsigned i, countBuffers = ioData->mNumberBuffers;
	for (i = 1; i < countBuffers; i++) {
		memcpy(ioData->mBuffers[i].mData, ioData->mBuffers[0].mData, ioData->mBuffers[i].mDataByteSize);
	}
	
	return noErr;
}

@implementation ZKMORPinkNoise

- (id)init {
	if (!(self = [super init])) return nil;
	
	_conduitType = kZKMORConduitType_Source;
	_numberOfOutputBuses = 1;
//	_seed = time(NULL);
	_seed = 22222;

	int numRows = 16;
	int i;
	long pmax;
	_index = 0;
	_indexMask = (1<<numRows) - 1;
	
		// Calculate maximum possible signed random value. Extra 1 for white noise always added.
	pmax = (numRows + 1) * (1<<(PINK_RANDOM_BITS-1));
	_scalar = 1.0f / pmax;
		// Initialize rows.
	for(i = 0; i < numRows; ++i)
		_rows[i] = 0;
	_runningSum = 0;		

	return self;
}

- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return _numberOfOutputBuses; }

- (void)setNumberOfBuses:(unsigned)numBuses scope:(AudioUnitScope)scope 
{ 
	if (kAudioUnitScope_Output == scope) {
		_numberOfOutputBuses = numBuses;	
		_areBusesInitialized = NO;
	}
}

- (BOOL)isNumberOfOutputBusesSettable { return YES; }
- (ZKMORRenderFunction)renderFunction { return PinkNoiseRenderFunction; }

@end



