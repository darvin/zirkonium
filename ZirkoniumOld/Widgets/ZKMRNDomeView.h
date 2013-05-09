//
//  ZKMRNDomeView.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 27.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOpenGLView.h"


///
///	 ZKMRNDomeView
///
///  View that displays the dome.
///  This version is really the speaker setup view -- a different view
///  is necessary for the playback.
///
@class ZKMRNSpeakerCubeTexture, ZKMRNOpenGLCube;
@interface ZKMRNDomeView : ZKMRNOpenGLView {
	float	_xRot, _yRot;

	BOOL						_isPositionIdeal;
	BOOL						_isRotateZenith;
	ZKMRNCameraState			_camera;
	ZKMNRSpeakerLayout*			_speakerLayout;
	ZKMRNSpeakerCubeTexture*	_speakerTexture;
	ZKMRNOpenGLCube*			_cube;
	
	// drawing state -- volatile (only valid during a draw)
	NSArray*					currentSpeakerPositions;
	NSArray*					currentSpeakersPerRing;
	unsigned					currentSpeakerIndex;

	id							_delegate;
}

//  Accessors
- (ZKMNRSpeakerLayout *)speakerLayout;
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout;

- (BOOL)isPositionIdeal;
- (void)setPositionIdeal:(BOOL)isPositionIdeal;

//  UI Actions
- (void)resetRotation;
- (void)resetCamera;
- (void)setXRotation:(float)xRotation;
- (void)setYRotation:(float)yRotation;
	/// lighter weight than setNeedsDisplay.
- (void)drawDisplayAndUpdate;

//  Delegate
- (id)delegate;
- (void)setDelegate:(id)delegate;

@end

@interface ZKMRNDomeView (ZKMRNDomeViewPrivate)

- (void)resetDrawingState;
- (void)setViewRotation;
- (void)drawDisplay;
- (void)drawReferenceObjects;
- (void)drawSpeakers;
- (void)drawSpeakersSelect;
- (void)drawSpeakersRing:(unsigned)ring;
- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal;

@end


///
///	 ZKMRNSpeakerSetupView
///
///  View that displays the speaker positions in the dome.
///
@interface ZKMRNSpeakerSetupView : ZKMRNDomeView {
	BOOL			_isEditingAllowed;
	NSIndexSet*		_selectedRings;
	// drawing state
	float			_speakerAlpha;
}

//  Accessors
- (BOOL)isEditingAllowed;
- (void)setEditingAllowed:(BOOL)isEditingAllowed;

/// the selected rings are drawn more prominently than the others
- (NSIndexSet *)selectedRings;
- (void)setSelectedRings:(NSIndexSet *)selectedRings;

@end


///
///	 ZKMRNSpeakerSetupViewDelegate
///
///  The informal protocol the delegate to a ZKMRNSpeakerSetupView should conform to.
///
@interface NSObject (ZKMRNSpeakerSetupViewDelegate)

- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition;

@end



///
///	 ZKMRNSpeakerTexture
///
///  And abstract superclass for the speaker textures.
///
@interface ZKMRNSpeakerTexture : ZKMRNOpenGLTexture {
	CGColorSpaceRef		_colorSpace;	
	CGFunctionRef		_gradientFunction;
@public
	float	startColor[4];
	float	endColor[4];	
}

@end


///
///	 ZKMRNSpeakerCubeTexture
///
///  The texture for the speakers which are drawn as cubes.
///  Another texture is used for speakers when they are simply rectangles.
///
@interface ZKMRNSpeakerCubeTexture : ZKMRNSpeakerTexture {

}

@end


///
///	 ZKMRNSpeakerRectangleTexture
///
///  The texture for the speakers which are drawn as rectangles.
///
@interface ZKMRNSpeakerRectangleTexture : ZKMRNSpeakerTexture {

}

@end


///
///	 ZKMRNVirtualSourceTexture
///
///  The texture for the virtual sources.
///
@interface ZKMRNVirtualSourceTexture : ZKMRNSpeakerTexture {

}

@end