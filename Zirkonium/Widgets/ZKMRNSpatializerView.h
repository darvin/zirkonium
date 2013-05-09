//
//  ZKMRNSpatializerView.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNDomeView.h"
#import "ZKMRNOpenGLShapes.h"
#import "ZKMRNSpatializerViewCameraAdjustment.h"
///
///	 ZKMRNSpatializerView
///
///  View that displays the state of the spatializer.
///
@class ZKMRNVirtualSourceTexture;

@interface ZKMRNSpatializerView : ZKMRNDomeView <ZKMNRPannerSourceExpanding> {
	ZKMNRVBAPPanner*	_panner;

	NSArray*			_pannerSources;
	BOOL				isShowingInitial;
	
	ZKMRNVirtualSourceTexture*	_sourceTexture;
	ZKMRNOpenGLCircle* _circle;
	
	unsigned _processedSourceIndex; //helper
	BOOL				_didDrag; 
	BOOL				_delegateGetsMoves; 
	ZKMNRPannerSource*	_selectedSource; 
	NSRecursiveLock* _lock;
	
	BOOL useCamera;
	ZKMRNSpatializerViewCameraAdjustment* _camAdjust;  
}
@property BOOL useCamera; 
@property BOOL isShowingInitial;

- (NSArray *)pannerSources;
- (void)setPannerSources:(NSArray *)pannerSources;

@end



///
///	 ZKMRNSpatializerViewDelegate
///
///  The informal protocol the delegate to a ZKMRNSpeakerSetupView should conform to.
///
/*
@interface NSObject (ZKMRNSpatializerViewDelegate)

- (void)view:(ZKMRNDomeView *)domeView selectedPannerSource:(ZKMNRPannerSource *)pannerSource;
- (void)view:(ZKMRNDomeView *)domeView movedPannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point;
- (void)view:(ZKMRNDomeView *)domeView finishedMovePannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point;

@end
*/