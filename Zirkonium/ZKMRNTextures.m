//
//  ZKMRNTextures.m
//  Zirkonium
//
//  Created by Jens on 02.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNTextures.h"

static void InterpolateHighlight (void* info, float const* inData, float *outData)
{
	ZKMRNSpeakerTexture* texture = (ZKMRNSpeakerTexture *)info;
	float* start = texture->startColor;
	float* end = texture->endColor;	
	int i;
	float a = inData[0];
	for(i = 0; i < 4; i++) outData[i] = a*end[i] + (1.0f-a)*start[i];
		
}

#pragma mark -

@implementation ZKMRNOpenGLTexture

#pragma mark -

- (id)init
{
	if (!(self = [super init])) return nil;
		
	_textureBitmap = nil;
		// frame size needs to be a power of 2
	_frame = NSMakeRect(0.f, 0.f, 128.f, 128.f);

	return self;
}

#pragma mark -

- (void)bindTexture
{
	glEnable(GL_TEXTURE_2D);					
	glGenTextures(1, &_textureID);
	glBindTexture(GL_TEXTURE_2D, _textureID);
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
	glTexImage2D(	GL_TEXTURE_2D, 0, GL_RGBA,
					_frame.size.width, _frame.size.height,
					0, GL_RGBA, GL_UNSIGNED_BYTE, [_textureBitmap bitmapData]);
	glDisable(GL_TEXTURE_2D);
}

- (GLuint)textureID { return _textureID; }

- (NSRect)frame { return _frame; }

#pragma mark -

- (void)generateTexture
{

}

#pragma mark -

- (void)dealloc
{
	if (_textureBitmap) [_textureBitmap release];
	[super dealloc];
}
@end


#pragma mark -

@implementation ZKMRNSpeakerTexture

#pragma mark -

- (id)init
{
	if (!(self = [super init])) return nil;
		
	_colorSpace = CGColorSpaceCreateDeviceRGB();
	CGFunctionCallbacks highlightCallback = { 0, InterpolateHighlight, NULL };
	_gradientFunction = CGFunctionCreate(self, 1, NULL, 4, NULL, &highlightCallback);

	startColor[0] = 1.0f; startColor[1] = 1.0f; startColor[2] = 1.0f; startColor[3] = 1.f;
	endColor[0] = 0.0f; endColor[1] = 0.0f; endColor[2] = 0.0f; endColor[3] = 0.f;

	[self generateTexture];
	return self;
}

#pragma mark -

- (void)dealloc
{
	if (_colorSpace) CGColorSpaceRelease(_colorSpace);
	if (_gradientFunction) CGFunctionRelease(_gradientFunction);
	[super dealloc];
}


@end

#pragma mark -

@implementation ZKMRNSpeakerCubeTexture

#pragma mark -

- (void)generateTexture
{
	// paint the texture into an image
	NSImage* image = [[NSImage alloc] initWithSize: _frame.size];
	[image lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill(_frame);
	
	CGContextRef ctx = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
		// create a small circle
	CGContextSetRGBFillColor(ctx, 1.f, 1.f, 1.f, 0.8f);

	// make it big so the sides of the cube are closed.
	CGContextAddRect(ctx, CGRectMake(NSMidX(_frame) - 64.f, NSMidY(_frame) - 64.f, 128.f, 128.f));
	CGContextFillPath(ctx);
	
		// make the gradient
	CGPoint mid = CGPointMake(NSMidX(_frame), NSMidY(_frame));
	float startRadius = 0.f;
	float endRadius = .5f * _frame.size.width;
	CGShadingRef shading = 
		CGShadingCreateRadial(	_colorSpace,
								mid,			// start center
								startRadius,	
								mid,			// end center
								endRadius, 
								_gradientFunction, NO, NO);
	
	CGContextDrawShading(ctx, shading);
	if (_textureBitmap) [_textureBitmap release];
		// save the image in a bitmap
	_textureBitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect: _frame];
	[image unlockFocus];
	
	[self bindTexture];
	
	[image release];
	CGShadingRelease(shading);
}

@end

#pragma mark -

@implementation ZKMRNSpeakerRectangleTexture

#pragma mark -

- (void)generateTextureBumpy
{
	// paint the texture into an image
	NSImage* image = [[NSImage alloc] initWithSize: _frame.size];
	[image lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill(_frame);
	
	float srcX = NSMinX(_frame), srcY = NSMinY(_frame);
	float dstY = NSMaxY(_frame);
	CGContextRef ctx = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(ctx);

	// create a rectangle
	CGShadingRef shading = CGShadingCreateAxial(
		_colorSpace,				// CGColorSpaceRef colorspace,
		CGPointMake(srcX, srcY),	// CGPoint start,
		CGPointMake(srcX, dstY),	// CGPoint end,
		_gradientFunction,			// CGFunctionRef function,
		NO,							// bool extendStart,
		NO							// bool extendEnd
	);
	
	CGRect clipRect = CGRectMake(_frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height);
	CGContextClipToRect(ctx, clipRect);

	startColor[0] = 1.0f; startColor[1] = 1.0f; startColor[2] = 1.0f; startColor[3] = 0.8f;
	endColor[0] = 0.7f; endColor[1] = 0.7f; endColor[2] = 0.7f; endColor[3] = 0.8f;
	
	CGContextDrawShading(ctx, shading);
	CGShadingRelease(shading);

	int insetX = 6;
	int insetY = 17;
	CGRect insetRect = CGRectMake(_frame.origin.x + insetX, _frame.origin.y + insetY, _frame.size.width - insetX * 2.f, _frame.size.height - insetY * 2.f);
	srcX = CGRectGetMinX(insetRect); srcY = CGRectGetMinY(insetRect);
	dstY = CGRectGetMaxY(insetRect);
	shading = CGShadingCreateAxial(
		_colorSpace,				// CGColorSpaceRef colorspace,
		CGPointMake(srcX, srcY),	// CGPoint start,
		CGPointMake(srcX, dstY),	// CGPoint end,
		_gradientFunction,			// CGFunctionRef function,
		NO,							// bool extendStart,
		NO							// bool extendEnd
	);
	
	CGContextClipToRect(ctx, insetRect);
	startColor[0] = 1.0f; startColor[1] = 1.0f; startColor[2] = 1.0f; startColor[3] = 1.f;
	endColor[0] = 0.2f; endColor[1] = 0.2f; endColor[2] = 0.2f; endColor[3] = 0.0f;	
	
	CGContextDrawShading(ctx, shading);
	CGShadingRelease(shading);
	CGContextRestoreGState(ctx);
	
	if (_textureBitmap) [_textureBitmap release];
		// save the image in a bitmap
	_textureBitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect: _frame];
	[image unlockFocus];
	
	[self bindTexture];
	
	[image release];
}

- (void)generateTextureAura
{
	// paint the texture into an image
	NSImage* image = [[NSImage alloc] initWithSize: _frame.size];
	[image lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill(_frame);
	
	CGContextRef ctx = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];

	// create a square
	CGContextSetRGBFillColor(ctx, 1.f, 1.f, 1.f, 0.7f);
	float rectSize = _frame.size.width * 0.5;
	CGContextAddRect(ctx, CGRectMake(NSMidX(_frame) - rectSize * 0.5, NSMidY(_frame) - rectSize * 0.5, rectSize, rectSize));
	CGContextFillPath(ctx);
	
	// make the gradient
	CGPoint mid = CGPointMake(NSMidX(_frame), NSMidY(_frame));
	float startRadius = 0.f;
	float endRadius = .5f * _frame.size.width;
	CGShadingRef shading = 
		CGShadingCreateRadial(	_colorSpace,
								mid,			// start center
								startRadius,	
								mid,			// end center
								endRadius, 
								_gradientFunction, NO, NO);
	
	CGContextDrawShading(ctx, shading);
	if (_textureBitmap) [_textureBitmap release];
		// save the image in a bitmap
	_textureBitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect: _frame];
	[image unlockFocus];
	
	[self bindTexture];
	
	[image release];
	CGShadingRelease(shading);
}

- (void)generateTexture { [self generateTextureBumpy]; }

@end

#pragma mark -

@implementation ZKMRNVirtualSourceTexture

#pragma mark -

- (void)generateTexture
{
	// paint the texture into an image
	NSImage* image = [[NSImage alloc] initWithSize: _frame.size];
	[image lockFocus];
	
	[[NSColor clearColor] set];
	NSRectFill(_frame);
	
	CGContextRef ctx = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
		// create a small circle
	CGContextSetRGBFillColor(ctx, 1.f, 1.f, 1.f, 0.3f);
	CGContextAddEllipseInRect(ctx, CGRectMake(NSMidX(_frame) - 16.f, NSMidY(_frame) - 16.f, 32.f, 32.f));
	CGContextFillPath(ctx);
	
		// make the gradient
	CGPoint mid = CGPointMake(NSMidX(_frame), NSMidY(_frame));
	float startRadius = 0.f;
	float endRadius = .5f * _frame.size.width;
	CGShadingRef shading = 
		CGShadingCreateRadial(	_colorSpace,
								mid,			// start center
								startRadius,	
								mid,			// end center
								endRadius, 
								_gradientFunction, NO, NO);
	
	CGContextDrawShading(ctx, shading);
	if (_textureBitmap) [_textureBitmap release];
		// save the image in a bitmap
	_textureBitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect: _frame];
	[image unlockFocus];
	
	[self bindTexture];
	
	[image release];
	CGShadingRelease(shading);
}

@end




