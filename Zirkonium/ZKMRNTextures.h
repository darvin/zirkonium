//
//  ZKMRNTextures.h
//  Zirkonium
//
//  Created by Jens on 02.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

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