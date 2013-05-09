//
//  ZKMRNChannelMap.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

///
///  ZKMRNChannelMap
///
///  A matrix for arbitrarily mapping a number of inputs to an arbitrary number of outputs
/// 
@interface ZKMRNChannelMap : NSManagedObject {
	float*		_crosspoints;
	unsigned	_cachedNumberOfInputs;
	unsigned	_cachedNumberOfOutputs;
	BOOL		_isChangingMatrix;
}

//  Accessors
- (float)volumeForCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;
- (void)setVolume:(float)volume forCrosspointInput:(unsigned)inputNum output:(unsigned)outputNum;

- (void)setNumberOfInputs:(NSNumber *)numberOfInputs;
- (void)setNumberOfOutputs:(NSNumber *)numberOfOutputs;

@end


@interface ZKMRNChannelMap (ZKMRNChannelMapInternal)

- (void)matrixSizeChanged;
- (void)faultCrosspoints;
- (void)synchronizeCrosspoints;
- (void)allocCrosspoints;
- (void)storeCrosspoints;

@end