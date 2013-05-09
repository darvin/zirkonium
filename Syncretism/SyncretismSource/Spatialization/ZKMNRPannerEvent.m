//
//  ZKMNRPannerEvent.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 12.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRPannerEvent.h"
#import "ZKMNRPanner.h"
#import "ZKMORLogger.h"
#import "ZKMORUtilities.h"

@implementation ZKMNRPannerEvent
#pragma mark _____ ZKMNREvent Overrides
- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{
	ZKMNRPannerSource* source = (ZKMNRPannerSource *)_target;
	float percent = ZKMNRPercentDone([self startTime], [self duration], timeRange->end);
	if (percent > 1.)
		switch (_continuationMode) {
			case kZKMNRContinuationMode_Halt: percent = 1.; break;
			case kZKMNRContinuationMode_Continue: break;
			case kZKMNRContinuationMode_Retrograde: percent = ZKMORFold0ToMax(percent, 1.f); break;	
		}
	ZKMNRSphericalCoordinate center = { 0.f, 0.f, 1.f };
	ZKMNRSphericalCoordinateSpan span;
	float gain;
	center.azimuth = ZKMNRInterpolateValue(_iAzimuth, _tAzimuth, percent);
	center.zenith = ZKMNRInterpolateValue(_iZenith, _tZenith, percent);
	span.azimuthSpan = ZKMNRInterpolateValue(_iAspan, _azimuthSpan, percent);
	span.zenithSpan = ZKMNRInterpolateValue(_iZspan, _zenithSpan, percent);
	gain = ZKMNRInterpolateValue(_iGain, _gain, percent);
	[source setCenter: center span: span gain: gain];
		
	if (_debugLevel & kZKMNREventDebugLevel_Task)
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Scheduler, CFSTR("Task %.2f %@ C {%.2f, %.2f} S {%.2f, %.2f} G %.2f"), timeRange->start, self, center.azimuth, center.zenith, span.azimuthSpan, span.zenithSpan, gain);
}

- (void)cleanup:(Float64)now 
{ 
	// move the values to the end value, if in halt mode
	if (kZKMNRContinuationMode_Halt == _continuationMode) {
		ZKMNRPannerSource* source = (ZKMNRPannerSource *)_target;
		ZKMNRSphericalCoordinate center = { 0.f, 0.f, 1.f };
		ZKMNRSphericalCoordinateSpan span;
		center.azimuth = _tAzimuth;	center.zenith = _tZenith;
		span.azimuthSpan = _azimuthSpan; span.zenithSpan = _zenithSpan;
		[source setCenter: center span: span gain: _gain];
		if (_debugLevel & kZKMNREventDebugLevel_Cleanup)
			ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Scheduler, CFSTR("Cleanup %.2f %@ C {%.2f, %.2f} S {%.2f, %.2f} G %.2f"), now, self, center.azimuth, center.zenith, span.azimuthSpan, span.zenithSpan, _gain);
	}
}

#pragma mark _____ Accessors
- (float)deltaAzimuth { return _deltaAzimuth; }
- (void)setDeltaAzimuth:(float)deltaAzimuth { _deltaAzimuth = deltaAzimuth; }

- (float)deltaZenith { return _deltaZenith; }
- (void)setDeltaZenith:(float)deltaZenith { _deltaZenith = deltaZenith; }

- (float)azimuthSpan { return _azimuthSpan; }
- (void)setAzimuthSpan:(float)aspan { _azimuthSpan = aspan; }

- (float)zenithSpan { return _zenithSpan; }
- (void)setZenithSpan:(float)zspan { _zenithSpan = zspan; }

- (float)gain { return _gain; }
- (void)setGain:(float)gain { _gain = gain; }

- (ZKMNRContinuationMode)continuationMode { return _continuationMode; }
- (void)setContinuationMode:(ZKMNRContinuationMode)continuationMode { _continuationMode = continuationMode; }

#pragma mark _____ Actions
- (void)initializeAtTime:(Float64)now
{
	// initialize initial state from source
	ZKMNRPannerSource* source = (ZKMNRPannerSource *)_target;
	_iAzimuth = [source center].azimuth; _tAzimuth = _iAzimuth + _deltaAzimuth;
	_iZenith = [source center].zenith; _tZenith = _iZenith + _deltaZenith;
	_iAspan = [source span].azimuthSpan;
	_iZspan = [source span].zenithSpan;
	_iGain = [source gain];
	
	if (_debugLevel & kZKMNREventDebugLevel_Activate)
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Scheduler, 
			CFSTR("Initialize %.2f %@ A {%.2f -> %.2f} Z {%.2f -> %.2f} As {%.2f -> %.2f} Zs {%.2f -> %.2f} G {%.2f -> %.2f}"), 
				now, self, 
				_iAzimuth, _tAzimuth, _iZenith, _tZenith,
				_iAspan, _azimuthSpan, _iZspan, _zenithSpan,
				_iGain, _gain);
}

@end


@implementation ZKMNRPannerEventXY
#pragma mark _____ ZKMNREvent Overrides
- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{
	ZKMNRPannerSource* source = (ZKMNRPannerSource *)_target;
	float percent = ZKMNRPercentDone([self startTime], [self duration], timeRange->end);
	if (percent > 1.)
		switch (_continuationMode) {
			case kZKMNRContinuationMode_Halt: percent = 1.; break;
			case kZKMNRContinuationMode_Continue: break;
			case kZKMNRContinuationMode_Retrograde: percent = ZKMORFold0ToMax(percent, 1.f); break;	
		}
	ZKMNRRectangularCoordinate center = { 0.f, 0.f, 0.f };
	ZKMNRRectangularCoordinateSpan span;
	float gain;
	center.x = ZKMNRInterpolateValue(_iX, _x, percent);
	center.y = ZKMNRInterpolateValue(_iY, _y, percent);
	span.xSpan = ZKMNRInterpolateValue(_iXspan, _xSpan, percent);
	span.ySpan = ZKMNRInterpolateValue(_iYspan, _ySpan, percent);
	gain = ZKMNRInterpolateValue(_iGain, _gain, percent);
	[source setCenterRectangular: center span: span gain: gain];
	if (_debugLevel & kZKMNREventDebugLevel_Task)
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Scheduler, CFSTR("Task %.2f %@ C {%.2f, %.2f} S {%.2f, %.2f} G %.2f"), timeRange->start, self, center.x, center.y, span.xSpan, span.ySpan, gain);
}

- (void)cleanup:(Float64)now 
{ 
	// move the values to the end value, if in halt mode
	if (kZKMNRContinuationMode_Halt == _continuationMode) {
		ZKMNRPannerSource* source = (ZKMNRPannerSource *)_target;
		ZKMNRRectangularCoordinate center = { 0.f, 0.f, 0.f };
		ZKMNRRectangularCoordinateSpan span;
		center.x = _x;	center.y = _y;
		span.xSpan = _xSpan; span.ySpan = _ySpan;
		[source setCenterRectangular: center span: span gain: _gain];
		if (_debugLevel & kZKMNREventDebugLevel_Cleanup)
			ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Scheduler, CFSTR("Cleanup %.2f %@ C {%.2f, %.2f} S {%.2f, %.2f} G %.2f"), now, self,center.x, center.y, span.xSpan, span.ySpan, _gain);
	}
}

#pragma mark _____ Accessors
- (float)x { return _x; }
- (void)setX:(float)x { _x = x; }

- (float)y { return _y; }
- (void)setY:(float)y { _y = y; }

- (float)xSpan { return _xSpan; }
- (void)setXSpan:(float)xspan { _xSpan = xspan; }

- (float)ySpan { return _ySpan; }
- (void)setYSpan:(float)yspan { _ySpan = yspan; }

- (float)gain { return _gain; }
- (void)setGain:(float)gain { _gain = gain; }

- (ZKMNRContinuationMode)continuationMode { return _continuationMode; }
- (void)setContinuationMode:(ZKMNRContinuationMode)continuationMode { _continuationMode = continuationMode; }

#pragma mark _____ Actions
- (void)initializeAtTime:(Float64)now
{
	// initialize initial state from source
	ZKMNRPannerSource* source = (ZKMNRPannerSource *)_target;
	ZKMNRRectangularCoordinate center = ZKMNRSphericalCoordinateToRectangular([source center]);
	_iX = center.x;
	_iY = center.y;
	_iXspan = [source spanRectangular].xSpan;
	_iYspan = [source spanRectangular].ySpan;
	_iGain = [source gain];
	
	if (_debugLevel & kZKMNREventDebugLevel_Activate)
		ZKMORLog(kZKMORLogLevel_Debug, kZKMORLogSource_Scheduler, 
			CFSTR("Initialize %.2f %@ X {%.2f -> %.2f} Y {%.2f -> %.2f} Xs {%.2f -> %.2f} Ys {%.2f -> %.2f} G {%.2f -> %.2f}"), 
				now, self, 
				_iX, _x, _iY, _y,
				_iXspan, _xSpan, _iYspan, _ySpan,
				_iGain, _gain);
}

@end
