//
//  ZKMRLLightView.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNDomeView.h"


///
///	 ZKMRLLightView
///
///  View that displays the state of the light spatializer.
///
@class ZKMRNVirtualSourceTexture, ZKMRLPannerLight;
@interface ZKMRLLightView : ZKMRNDomeView <ZKMNRPannerSourceExpanding> {
	ZKMRLPannerLight*	_panner;
	NSArray*			_pannerSources;
	BOOL				_isShowingMesh;
	BOOL				_isShowingInitial;
	
	ZKMRNVirtualSourceTexture*	_sourceTexture;
	
	BOOL initialized; 
}

//  Accessors
- (BOOL)isShowingMesh;
- (void)setShowingMesh:(BOOL)isShowingMesh;

- (BOOL)isShowingInitial;
- (void)setShowingInitial:(BOOL)isShowingInitial;

- (NSArray *)pannerSources;

- (ZKMRLPannerLight *)panner;
	/// unlike in Zirkonium, the LightView may be created before the system's panner. Thus, the panner may need to be updated.
- (void)setPanner:(ZKMRLPannerLight *)panner;

@end



///
///	 ZKMRNSpatializerViewDelegate
///
///  The informal protocol the delegate to a ZKMRNSpeakerSetupView should conform to.
///
@interface NSObject (ZKMRNSpatializerViewDelegate)

- (void)view:(ZKMRNDomeView *)domeView selectedPannerSource:(ZKMNRPannerSource *)pannerSource;
- (void)view:(ZKMRNDomeView *)domeView movedPannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point;
- (void)view:(ZKMRNDomeView *)domeView finishedMovePannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point;

@end
