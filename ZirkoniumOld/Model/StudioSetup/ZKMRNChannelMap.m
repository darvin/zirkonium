//
//  ZKMRNChannelMap.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNChannelMap.h"

@interface ZKMRNChannelMap (ZKMRNChannelMapPrivate)

- (void)addMatrixObserver;
- (void)removeMatrixObserver;
- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change 
					context:(void *)context;

@end

@implementation ZKMRNChannelMap
#pragma mark _____ NSManagedObject Overrides
- (void)dealloc
{
	[self removeMatrixObserver];
	if (_crosspoints) free(_crosspoints);
	[super dealloc];
}

- (id)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context
{
	if (!(self = [super initWithEntity: entity insertIntoManagedObjectContext: context])) return nil;
	
	_crosspoints = NULL;
	_isChangingMatrix = NO;
	_cachedNumberOfInputs = 0;
	_cachedNumberOfOutputs = 0;
	
	[self addMatrixObserver];

	return self;
}

- (void)awakeFromInsert
{
	// default a matrix
	if (!_crosspoints) [self allocCrosspoints];
	
	unsigned input, inputCount = _cachedNumberOfInputs;
	for (input = 0; input < inputCount; input++)
		_crosspoints[input * _cachedNumberOfOutputs + (input % _cachedNumberOfOutputs)] = 1.f;
			
		// store the new data
	[self storeCrosspoints];
	
	[super awakeFromInsert];
}

#pragma mark _____ Accessors
- (float)volumeForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{ 
	if (!_crosspoints) [self faultCrosspoints];
	return _crosspoints[inputNum * _cachedNumberOfOutputs + outputNum];
}

- (void)setVolume:(float)volume forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum
{
	_crosspoints[inputNum * _cachedNumberOfOutputs + outputNum] = volume;
	[self storeCrosspoints];
}

- (void)setNumberOfInputs:(NSNumber *)numberOfInputs
{
	if (!_crosspoints) [self faultCrosspoints];
	
	[self willChangeValueForKey: @"numberOfInputs"];
	[self setPrimitiveValue: numberOfInputs forKey: @"numberOfInputs"];
	[self didChangeValueForKey: @"numberOfInputs"];	
	[self matrixSizeChanged];
}

- (void)setNumberOfOutputs:(NSNumber *)numberOfOutputs
{
	if (!_crosspoints) [self faultCrosspoints];

	[self willChangeValueForKey: @"numberOfOutputs"];
	[self setPrimitiveValue: numberOfOutputs forKey: @"numberOfOutputs"];
	[self didChangeValueForKey: @"numberOfOutputs"];	
	[self matrixSizeChanged];
}

#pragma mark _____ ZKMRNChannelMapInternal
- (void)matrixSizeChanged
{
		// crosspoints cannot be NULL - changing the matrix size forces a fault of the crosspoints
	float* oldCrosspoints = _crosspoints;		
	unsigned oldNumberOfInputs = _cachedNumberOfInputs;
	unsigned oldNumberOfOutputs = _cachedNumberOfOutputs;
		// alloc a new crosspoints array
	[self allocCrosspoints];

		// copy over the old data
	unsigned input, inputCount = MIN(_cachedNumberOfInputs, oldNumberOfInputs);
	unsigned output, outputCount = MIN(_cachedNumberOfOutputs, oldNumberOfOutputs);
	for (input = 0; input < inputCount; ++input)
		for (output = 0; output < outputCount; ++output) {
			unsigned idx = input * _cachedNumberOfOutputs + output;
			unsigned oldidx = input * oldNumberOfOutputs + output;
			_crosspoints[idx] = oldCrosspoints[oldidx];
		}
			
		// default any elements beyond the existing ones
	for (input = inputCount; input < _cachedNumberOfInputs; ++input) {
		output = input % _cachedNumberOfOutputs;
		unsigned idx = input * _cachedNumberOfOutputs + output;
		_crosspoints[idx] = 1.f;
	}
		// store the new data
	[self storeCrosspoints];
		
	free(oldCrosspoints);
}

- (void)faultCrosspoints
{
	[self allocCrosspoints];
	[self synchronizeCrosspoints];
}

- (void)synchronizeCrosspoints
{
	if (!_crosspoints) return;

	NSData* crosspointsData;
		// this means I've been deleted
	if (!(crosspointsData = [self valueForKey: @"matrix"])) return;
	
	// read in the data from the NSData
	unsigned input, inputCount = _cachedNumberOfInputs;
	unsigned output, outputCount = _cachedNumberOfOutputs;
	const float* bytes = (const float*) [crosspointsData bytes];
	for (input = 0; input < inputCount; input++)
		for (output = 0; output < outputCount; output++) 
			_crosspoints[input * _cachedNumberOfOutputs + output] = bytes[input * _cachedNumberOfOutputs + output];
}

- (void)allocCrosspoints
{
	// users need to deal with the old memory of crosspoints themselves
	_cachedNumberOfInputs = [[self valueForKey: @"numberOfInputs"] unsignedIntValue];
	_cachedNumberOfOutputs = [[self valueForKey: @"numberOfOutputs"] unsignedIntValue];
	_crosspoints = (float *) calloc(_cachedNumberOfInputs * _cachedNumberOfOutputs, sizeof(float));
}

- (void)storeCrosspoints
{
		// store the data as an NSData
	NSData* crosspointsData = [NSData dataWithBytes: _crosspoints length: _cachedNumberOfInputs * _cachedNumberOfOutputs * sizeof(float)];
	_isChangingMatrix = YES;
	[self setValue: crosspointsData forKey: @"matrix"];
	_isChangingMatrix = NO;
}

#pragma mark _____ ZKMRNChannelMapPrivate
- (void)addMatrixObserver
{
	[self addObserver: self forKeyPath: @"matrix" options: NSKeyValueObservingOptionNew context: NULL];
}

- (void)removeMatrixObserver
{
	[self removeObserver: self forKeyPath: @"matrix"];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString: @"matrix"]) {
			// I made the change myself -- I'll deal with the consequences
		if (_isChangingMatrix) return;
			
			// someone else is changing the channel map -- react!
		[self synchronizeCrosspoints];
		return;
	}	
}

@end
