//
//  ZKMRNSpatializerView.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNDomeView.h"


///
///	 ZKMRNSpatializerView
///
///  View that displays the state of the spatializer.
///
@class ZKMRNVirtualSourceTexture;
@interface ZKMRNSpatializerView : ZKMRNDomeView <ZKMNRPannerSourceExpanding> {
	ZKMNRVBAPPanner*	_panner;
	NSArray*			_pannerSources;
	BOOL				_isShowingMesh;
	BOOL				_isShowingInitial;
	
	ZKMRNVirtualSourceTexture*	_sourceTexture;
}

//  Accessors
- (BOOL)isShowingMesh;
- (void)setShowingMesh:(BOOL)isShowingMesh;

- (BOOL)isShowingInitial;
- (void)setShowingInitial:(BOOL)isShowingInitial;

- (NSArray *)pannerSources;
- (void)setPannerSources:(NSArray *)pannerSources;

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