//
//  ZKMORNoise.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORConduit.h"


///
///  ZKMORWhiteNoise
/// 
///  Generate white noise
///
@interface ZKMORWhiteNoise : ZKMORConduit {
	unsigned	_numberOfOutputBuses;
	int			_seed;
}

@end



///
///  ZKMORPinkNoise
/// 
///  Generate pink noise.
///
///  Based on Phil Burk's implementation of the Voss-McCartney algorithm.
///
///		http://www.firstpr.com.au/dsp/pink-noise/phil_burk_19990905_patest_pink.c
///
///
#define PINK_MAX_RANDOM_ROWS   (30)
#define PINK_RANDOM_BITS       (24)
#define PINK_RANDOM_SHIFT      ((sizeof(long)*8)-PINK_RANDOM_BITS)
@interface ZKMORPinkNoise : ZKMORConduit {
	unsigned	_numberOfOutputBuses;
	int			_seed;
	
	long		_rows[PINK_MAX_RANDOM_ROWS];
	long		_runningSum;					// Used to optimize summing of generators.
	int			_index;							// Incremented each sample.
	int			_indexMask;						// Index wrapped by ANDing with this mask.
	float		_scalar;						// Used to scale within range of -1.0 to +1.0 
}

@end
