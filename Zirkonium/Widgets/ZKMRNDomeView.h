//
//  ZKMRNDomeView.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 27.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOpenGLView.h"
#import "ZKMRNDomeViewCameraAdjustment.h"
#import "ZKMRNSpeaker.h"
#import "ZKMRNTextures.h"
#import "ZKMRNOpenGLShapes.h"

///
///	 ZKMRNDomeView
///
///  View that displays the dome.
///  This version is really the speaker setup view -- a different view
///  is necessary for the playback.
///

@class ZKMRNSpeakerCubeTexture, ZKMRNOpenGLCube, ZKMRNOpenGLString;
@class ZKMRNZirkoniumSystem; 


typedef enum 
{
	kDomeViewDefaultType,
    kDomeViewSpeakerEditorType,                       
    kDomeViewSphereMappingType,
	kDomeView3DPreviewType,
	kDomeView2DPreviewType,
	kDomeViewFullscreenType,
	kDomeView2DMappingType
} ViewType;

@protocol ZKMRNDomeViewDelegate;

@interface ZKMRNDomeView : ZKMRNOpenGLView {

	id<ZKMRNDomeViewDelegate> delegate; 

	ViewType					viewType; 
	BOOL						isPositionIdeal; 	
	BOOL						isRotateZenith;

	BOOL						_useTrackball;
	BOOL						_initiatedDragSpeaker; 	
	BOOL						_dragSpeaker;
	BOOL						_isCurrentSelectedSpeaker; 
	BOOL						_isCurrentSelectedRing; 
	
	ZKMRNCameraState				_camera;
	ZKMRNDomeViewCameraAdjustment*	_cameraAdjustment; 
	
	ZKMNRSpeakerLayout*			_speakerLayout;
	ZKMRNSpeakerCubeTexture*	_speakerTexture;
	ZKMRNOpenGLCube*			_cube;
	ZKMRNOpenGLString*			_glString;
	
	ZKMRNSpeaker*				_selectedSpeaker;
	int							_selectedRing; 
	ZKMNRRectangularCoordinate	_startSpeakerPosition;
	ZKMNRRectangularCoordinate  _startMousePosition; 
	NSPoint						_mouseLocation;
	NSArray*					_selectedSpeakerPositions; 
	
	ZKMNRVBAPPanner*			_previewPanner;
	
	
	// drawing state -- volatile (only valid during a draw)
	NSArray*					currentSpeakerPositions;
	NSArray*					currentSpeakersPerRing;
	unsigned					currentSpeakerIndex;

	//id							_delegate;
	
	BOOL						pieceIsPlaying; 
}

@property (nonatomic, assign) id<ZKMRNDomeViewDelegate> delegate; 

@property ViewType viewType; 
@property BOOL isPositionIdeal; 
@property BOOL isRotateZenith; 
@property BOOL pieceIsPlaying; 

- (ZKMNRSpeakerLayout *)speakerLayout;
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout;
- (void)setSelectedSpeakerPositions:(NSArray*)array;

- (void)dragSpeaker;

- (void)drawSpeakerMesh;

- (void)resetRotation;
- (void)resetCamera;
- (void)setXRotation:(float)xRotation;
- (void)setYRotation:(float)yRotation;

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
- (void)drawSpeakerDirectionOfLength:(float)l x:(float)x y:(float)y z:(float)z;
- (void)drawSpeakerNumberAtX:(float)x y:(float)y z:(float)z;
- (void)updateDisplay:(NSNotification*)inNotification; 
@end

@protocol ZKMRNDomeViewDelegate

@optional

// Preference Controller and Studio Setup Document ...
- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition;

// Piece Document ...
- (void)view:(ZKMRNDomeView *)domeView selectedPannerSource:(ZKMNRPannerSource *)pannerSource;
- (void)view:(ZKMRNDomeView *)domeView movedPannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point;
- (void)view:(ZKMRNDomeView *)domeView finishedMovePannerSource:(ZKMNRPannerSource *)pannerSource toPoint:(ZKMNRSphericalCoordinate)point;

@end





///
///	 ZKMRNSpeakerSetupViewDelegate
///
///  The informal protocol the delegate to a ZKMRNSpeakerSetupView should conform to.
///
/*
@interface NSObject (ZKMRNSpeakerSetupViewDelegate)

- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition;

@end
*/


