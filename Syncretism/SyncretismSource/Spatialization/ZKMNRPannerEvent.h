//
//  ZKMNRPannerEvent.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 12.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMNRPannerEvent_h__
#define __ZKMNRPannerEvent_h__

#import <Cocoa/Cocoa.h>
#import "ZKMNREventScheduler.h"


///
///  ZKMNRContinuationMode
///
///  Enums for the volitilie state of the graph.
///
typedef enum
{
	kZKMNRContinuationMode_Halt = 0,
	kZKMNRContinuationMode_Continue = 1,
	kZKMNRContinuationMode_Retrograde = 2
} ZKMNRContinuationMode;



///
///  ZKMNRPannerEvent
///
///  A panner event (spherical coordinates).
///
@class ZKMNRPannerSource;
@interface ZKMNRPannerEvent : ZKMNREvent {
		// event state
	float _deltaAzimuth, _deltaZenith, _azimuthSpan, _zenithSpan, _gain;
		// running state -- computed at initialize time
	float _iAzimuth, _iZenith, _iAspan, _iZspan, _iGain;
	float _tAzimuth, _tZenith;
	ZKMNRContinuationMode _continuationMode;
}

//  Accessors
- (float)deltaAzimuth;
- (void)setDeltaAzimuth:(float)deltaAzimuth;

- (float)deltaZenith;
- (void)setDeltaZenith:(float)deltaZenith;

- (float)azimuthSpan;
- (void)setAzimuthSpan:(float)aspan;

- (float)zenithSpan;
- (void)setZenithSpan:(float)zspan;

- (float)gain;
- (void)setGain:(float)gain;

- (ZKMNRContinuationMode)continuationMode;
- (void)setContinuationMode:(ZKMNRContinuationMode)continuationMode;

//  Actions
- (void)initializeAtTime:(Float64)now;

@end

///
///  ZKMNRPannerEventXY
///
///  A panner event (Cartesian coordinates).
///
@class ZKMNRPannerSource;
@interface ZKMNRPannerEventXY : ZKMNREvent {
		// event state
	float _x, _y, _xSpan, _ySpan, _gain;
		// running state -- computed at initialize time
	float _iX, _iY, _iXspan, _iYspan, _iGain;
	ZKMNRContinuationMode _continuationMode;
}

//  Accessors
- (float)x;
- (void)setX:(float)x;

- (float)y;
- (void)setY:(float)y;

- (float)xSpan;
- (void)setXSpan:(float)xspan;

- (float)ySpan;
- (void)setYSpan:(float)yspan;

- (float)gain;
- (void)setGain:(float)gain;

- (ZKMNRContinuationMode)continuationMode;
- (void)setContinuationMode:(ZKMNRContinuationMode)continuationMode;

//  Actions
- (void)initializeAtTime:(Float64)now;

@end
#endif
