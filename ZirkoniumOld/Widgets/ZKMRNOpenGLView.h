//
//  ZKMRNOpenGLView.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

///
///  ZKMRNCameraState
/// 
typedef struct {
	ZKMNRRectangularCoordinate	position, center, up;
	double						aperture;
	NSSize						bounds;
} ZKMRNCameraState;

///
///  ZKMRNHitRecords
///
///  Struct to store info about hit records in the OpenGL select buffer. 
///  See ZKMRNOpenGLView>>getHitRecords:fromHits:count: .
/// 
typedef struct {
	GLuint		numberOfNames;
	GLuint*		names;
} ZKMRNHitRecords;


///
///  ZKMRNOpenGLView
/// 
///  Contains functions common to Zirkonium OpenGL views
/// 
@interface ZKMRNOpenGLView : NSOpenGLView {
	BOOL	_isDoubleBuffered;
	GLuint	_selectBuffer[64];
	NSOpenGLContext*	_savedOpenGLContext;
}

//  Internal Functions
- (void)setupOpenGL;
- (void)setProjectionMatrix;
- (void)setModelViewMatrix;

	/// activates my OGL context, remembering the active context
- (void)activateOpenGLContext;
	/// restores the previously active context
- (void)restoreOpenGLContext;

//  Hit Records
///  Call this to set up the OpenGL select buffer to process mouse hits the the point defined by theEvent.
- (void)beginHitTesting:(NSEvent *)theEvent;
///  Checks this select buffer for any hits and returns them in the form of a ZKMRNHitRecords struct.
- (ZKMRNHitRecords)endHitTesting;


///  Returns the hit records in the select buffer. Returns the number of names found and fills out the
///  hitRecords struct which has a pointer to the names themselves. Don't need to call this yourself, 
///  use the above beginProcessingHints / endProcessingHits.
- (GLuint)getHitRecords:(ZKMRNHitRecords *)hitRecords fromHits:(GLuint *)hitPtr count:(GLint)hitCount;

//  Coordinate Transforms
///  Converts window coordinates to OpenGL coordinates -- the modelview and projection matrices are used
///  and must therefore be correctly set before invoking this function.
- (void)getOpenGLCoord:(ZKMNRRectangularCoordinate *)coord forWindowLocation:(NSPoint)point;

@end


///
///	 ZKMRNOpenGLTexture
///
///  An object that can be used for texturing.
///
@interface ZKMRNOpenGLTexture : NSObject {
	NSBitmapImageRep*	_textureBitmap;
	GLuint				_textureID;
	NSRect				_frame;
}

- (GLuint)textureID;
- (NSRect)frame;

@end

@interface ZKMRNOpenGLTexture (ZKMRNOpenGLTextureInternal)
/// Create a texture bitmap and paint into it. Subclass responsibility.
- (void)generateTexture;
/// Binds the textureBitmap to an OpenGL texture
- (void)bindTexture;

@end
