//
//  ZKMRNDomeView.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 27.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNDomeView.h"
#import "ZKMRNOpenGLShapes.h"
//#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNSpeaker.h"
#include <OpenGL/gl.h>
#include <OpenGL/glext.h>

@implementation ZKMRNDomeView
#pragma mark _____ ZKMRNOpenGLView overrides
- (void)awakeFromNib
{
	_xRot = 0.f, _yRot = 0.f;
	_cube = [[ZKMRNOpenGLCube alloc] init];
	_isRotateZenith = YES;
}

- (void)dealloc
{
	[self setSpeakerLayout: nil];
	if (_cube) [_cube release];
	if (_speakerTexture) [_speakerTexture release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame pixelFormat:(NSOpenGLPixelFormat*)format {
    if (!(self = [super initWithFrame: frame pixelFormat: format])) return nil;

	[[ self openGLContext ] makeCurrentContext];
	_isPositionIdeal = NO;
	_isRotateZenith = YES;
	_delegate = nil;

    return self;
}

- (void)drawRect:(NSRect)rect {
	[self drawDisplay];
	
	(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
	[self resetCamera];
}

- (void)setupOpenGL
{
	NSRect frame = [self frame];
	NSRect bounds = [self bounds];
	
	GLfloat minX, minY, maxX, maxY;
	minX = NSMinX(bounds); minY = NSMinY(bounds);
	maxX = NSMaxX(bounds); maxY = NSMaxY(bounds);
	_camera.bounds.width = frame.size.width;
	_camera.bounds.height = frame.size.height;
	
	[self update];
	
	if (NSIsEmptyRect([self visibleRect]))
		glViewport(0, 0, 1, 1);
	else
		glViewport(0, 0, _camera.bounds.width, _camera.bounds.height);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
		
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}

- (void)setProjectionMatrix
{
	GLdouble ratio;
	ratio = _camera.bounds.width / _camera.bounds.height;
	gluPerspective(_camera.aperture, ratio, 3.5, 6.5);
}

- (void)setModelViewMatrix
{
	gluLookAt(	_camera.position.x, _camera.position.y, _camera.position.z,
				_camera.center.x, _camera.center.y, _camera.center.z,
				_camera.up.x, _camera.up.y, _camera.up.z);
	[self setViewRotation];
}


#pragma mark _____ Accessors
- (ZKMNRSpeakerLayout *)speakerLayout { return _speakerLayout; }
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout
{
	if (_speakerLayout != speakerLayout) {
		[_speakerLayout release];
		_speakerLayout = (speakerLayout) ? [speakerLayout retain] : nil;
	}
	//[self setNeedsDisplay: YES];
}

- (BOOL)isPositionIdeal { return _isPositionIdeal; }
- (void)setPositionIdeal:(BOOL)isPositionIdeal { _isPositionIdeal = isPositionIdeal; }

#pragma mark _____ UI Actions
- (void)resetRotation { _xRot = 0.f, _yRot = 0.f; }
- (void)resetCamera
{
	_camera.aperture = 30.;
	
	_camera.position.x = 0.f;
	_camera.position.y = 0.f;
	_camera.position.z = 5.f;
	_camera.center.x = 0.f; 
	_camera.center.y = 0.f; 
	_camera.center.z = 0.f;

	_camera.up.x = 0.f;			
	_camera.up.y = 1.f;
	_camera.up.z = 0.f;
}
- (void)setXRotation:(float)xRotation { _xRot = xRotation; [self display]; }
- (void)setYRotation:(float)yRotation { _yRot = yRotation; [self display]; }
- (void)drawDisplayAndUpdate { [self drawDisplay]; glFlush(); }

#pragma mark _____ Delegate
- (id)delegate { return _delegate; }
- (void)setDelegate:(id)delegate { _delegate = delegate; }

#pragma mark _____ ZKMRNDomeViewPrivate
- (void)resetDrawingState
{
	[self setupOpenGL];
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClearDepth(1.0);
	glShadeModel(GL_SMOOTH);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

//	glDisable(GL_DEPTH_TEST);
//	glEnable(GL_BLEND);					// Enable blending
//	glBlendFunc(GL_SRC_ALPHA, GL_ONE);	// Type of blending to perform
	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
	glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
	
	glEnable(GL_RESCALE_NORMAL);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	[self setProjectionMatrix];

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	[self setModelViewMatrix];
}

- (void)setViewRotation
{
		// by default, we are looking down from the top on a left-handed
		// coord system. Rotate so that x faces the "front" (top of the screen)
	glRotatef(90.0f, 0.0f, 0.0f, 1.0f);
	glRotatef(_xRot, 1.0f, 0.0f, 0.0f);
	glRotatef(_yRot, 0.0f, 1.0f, 0.0f);
}

- (void)drawDisplay
{
	[self resetDrawingState];
	
	[self drawReferenceObjects];
	[self drawSpeakers];
}

- (void)drawReferenceObjects 
{
	// draw the axes
	glBegin(GL_LINES);
		// x-axis
		glColor3f(1.0f, 0.0f, 0.0f);
		glVertex3f(0.0f, 0.0f, 0.0f);
		glVertex3f(0.5f, 0.0f, 0.0f);

		// y-axis			
		glColor3f(0.0f, 1.0f, 0.0f);			
		glVertex3f(0.0f, 0.0f, 0.0f);
		glVertex3f(0.0f, 0.5f, 0.0f);			

		// z-axis			
		glColor3f(0.0f, 0.0f, 1.0f);			
		glVertex3f(0.0f, 0.0f, 0.0f);
		glVertex3f(0.0f, 0.0f, 0.5f);
	glEnd();
}

- (void)drawSpeakers
{
	if (!_speakerLayout) return;
	
	currentSpeakerPositions = [_speakerLayout speakerPositions];
	currentSpeakersPerRing = [_speakerLayout numberOfSpeakersPerRing];
	currentSpeakerIndex = 0;
	unsigned j, numRings = [_speakerLayout numberOfRings];

	glEnable(GL_TEXTURE_2D);
		for (j = 0; j < numRings; j++) [self drawSpeakersRing: j];
	glDisable(GL_TEXTURE_2D);
}

	// return the new current speaker index
- (void)drawSpeakersRing:(unsigned)ring
{
	ZKMNRRectangularCoordinate speakerPositionRect;
	ZKMNRSphericalCoordinate speakerPositionSph;
	unsigned i, numSpeakersInRing = [[currentSpeakersPerRing objectAtIndex: ring] unsignedIntValue];
	for(i = 0; i < numSpeakersInRing; currentSpeakerIndex++, i++) {
		ZKMNRSpeakerPosition* speakerPosition = [currentSpeakerPositions objectAtIndex: currentSpeakerIndex];
		speakerPositionSph = [speakerPosition coordPhysical];
		speakerPositionRect = 
			(_isPositionIdeal) ?
				ZKMNRSphericalCoordinateToRectangular([speakerPosition coordPlatonic]) : 
				[speakerPosition coordRectangular];
		float x = speakerPositionRect.x, y = speakerPositionRect.y, z = speakerPositionRect.z;
		glPushName(currentSpeakerIndex);
		glPushMatrix();
			glTranslatef(x, y, z);
				// undo the -90 deg rotation of the coordinate space
			glRotatef(90.f, 0.f, 0.f, 1.f);
				// rotate the speaker toward the center - azimuth
			glRotatef(speakerPositionSph.azimuth * 180.f, 0.f, 0.f, 1.f);
				// rotate the speaker toward the center - zenith
			if (_isRotateZenith) glRotatef(speakerPositionSph.zenith * -180.f, 1.f, 0.f, 0.f);
			glScalef(0.2f, 0.2f, 0.3f);
			[self drawSpeaker: currentSpeakerIndex ringPosition: i ringTotal: numSpeakersInRing];
		glPopMatrix();
		glPopName();
	}
}

- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal
{
	glColor3f(0.0f, 0.7f, 0.0f);
	glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
	[_cube drawCube];
}

@end


@implementation ZKMRNSpeakerSetupView
#pragma mark _____ NSResponder overrides
- (void)mouseDown:(NSEvent *)theEvent
{
	[self activateOpenGLContext];
	
	[self beginHitTesting: theEvent];
	[self drawSpeakers];
	ZKMRNHitRecords hitRecords = [self endHitTesting];
	
	// process hit records
	GLuint i, numberOfNames = hitRecords.numberOfNames;
	GLuint* names = hitRecords.names;
	ZKMNRSpeakerPosition* selectedPos = nil;
	for (i = 0; i < numberOfNames; i++) selectedPos = [[_speakerLayout speakerPositions] objectAtIndex: names[i]];
		// nothing selected -- get out of here
	if (!selectedPos) return;
	
	// notify delegate
	if (_delegate && [_delegate respondsToSelector: @selector(view:selectedSpeakerPosition:)]) { 
		[_delegate view: self selectedSpeakerPosition: selectedPos];
	}
	
	if (!_isEditingAllowed) return;

	// consume events until we are done 
	BOOL keepProcessing = YES;
	BOOL didDrag = NO;
	NSPoint mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];
//	ZKMNRSphericalCoordinate center = _isShowingInitial ? [selectedSource initialCenter] : [selectedSource center];
//	ZKMNRRectangularCoordinate dragPosition = ZKMNRSphericalCoordinateToRectangular(center);
	ZKMRNSpeaker* selectedSpeaker = [selectedPos tag];
	ZKMNRRectangularCoordinate newSpeakerPosition, startSpeakerPosition = [selectedPos coordRectangular];
	ZKMNRRectangularCoordinate dragMouseDelta, startMousePosition; 
	[self getOpenGLCoord: &startMousePosition forWindowLocation: mouseLocation];
	
	while (keepProcessing) {
		theEvent = [[self window] nextEventMatchingMask: (NSLeftMouseUpMask | NSLeftMouseDraggedMask)];
		mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
				didDrag = YES;
				[self getOpenGLCoord: &dragMouseDelta forWindowLocation: mouseLocation];
					// convert the drag position to a delta
				dragMouseDelta.x -= startMousePosition.x; dragMouseDelta.y -= startMousePosition.y; dragMouseDelta.z -= startMousePosition.z;
				newSpeakerPosition.x = ZKMORClamp(startSpeakerPosition.x + dragMouseDelta.x, -1.f, 1.f);
				newSpeakerPosition.y = ZKMORClamp(startSpeakerPosition.y + dragMouseDelta.y, -1.f, 1.f);
				newSpeakerPosition.z = ZKMORClamp(startSpeakerPosition.z + dragMouseDelta.z, -1.f, 1.f);								
				[selectedSpeaker setPositionX: [NSNumber numberWithFloat: newSpeakerPosition.x]];
				[selectedSpeaker setPositionY: [NSNumber numberWithFloat: newSpeakerPosition.y ]];
				[selectedSpeaker setPositionZ: [NSNumber numberWithFloat: newSpeakerPosition.z]];
				[self drawDisplay]; glFlush();
				break;
			case NSLeftMouseUp:
				keepProcessing = NO;
				break;
			default:
				// ignore
				break;
		}
	}
	
	[self restoreOpenGLContext];
}


- (void)scrollWheel:(NSEvent *)theEvent
{
	_xRot += [theEvent deltaX];
	_yRot += [theEvent deltaY];
	[self display];
}

#pragma mark _____ ZKMRNDomeView Overrides
- (void)awakeFromNib
{
	[super awakeFromNib];
	_isEditingAllowed = NO;
	_selectedRings = nil;
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
	_speakerTexture = [[ZKMRNSpeakerCubeTexture alloc] init];
}

- (void)drawSpeakersRing:(unsigned)ring
{
	if (_selectedRings && ([_selectedRings count] > 0)) {
		_speakerAlpha = [_selectedRings containsIndex: ring] ? 1.f : 0.5f;
	} else 
		_speakerAlpha = 1.f;
	[super drawSpeakersRing: ring];
}


- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal
{
	float redFactor = (float) ringNum / (float) ringTotal;
	glColor3f(redFactor * _speakerAlpha, 0.3f * _speakerAlpha, (1.0f - redFactor) * _speakerAlpha);
//	glColor3f(redFactor, 0.3f, 1.0f - redFactor);
	glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
	glScalef(0.6f, 0.6f, 0.6f);
	[_cube drawCube];
}

#pragma mark _____ Accessors
- (BOOL)isEditingAllowed { return _isEditingAllowed; }
- (void)setEditingAllowed:(BOOL)isEditingAllowed { _isEditingAllowed = isEditingAllowed; }

- (NSIndexSet *)selectedRings { return _selectedRings; }
- (void)setSelectedRings:(NSIndexSet *)selectedRings 
{
	if (_selectedRings) [_selectedRings release];
	_selectedRings = selectedRings;
	if (_selectedRings) [_selectedRings retain];
	
	//[self setNeedsDisplay: YES];
}

@end


static void InterpolateHighlight (void* info, float const* inData, float *outData)
{
//	static float start[4] = { 1.0f, 1.0f, 1.0f, 1.f };
//	static float end[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
	ZKMRNSpeakerTexture* texture = (ZKMRNSpeakerTexture *)info;
	float* start = texture->startColor;
	float* end = texture->endColor;	
	int i;
	float a = inData[0];
	for(i = 0; i < 4; i++) outData[i] = a*end[i] + (1.0f-a)*start[i];
		
}

@implementation ZKMRNSpeakerTexture

- (void)dealloc
{
	if (_colorSpace) CGColorSpaceRelease(_colorSpace);
	if (_gradientFunction) CGFunctionRelease(_gradientFunction);
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
		
	_colorSpace = CGColorSpaceCreateDeviceRGB();
	CGFunctionCallbacks highlightCallback = { 0, InterpolateHighlight, NULL };
	// void* info, size_t domainDimension, float const* domain, size_t rangeDimension, float const* range
	_gradientFunction = CGFunctionCreate(self, 1, NULL, 4, NULL, &highlightCallback);

	startColor[0] = 1.0f; startColor[1] = 1.0f; startColor[2] = 1.0f; startColor[3] = 1.f;
	endColor[0] = 0.0f; endColor[1] = 0.0f; endColor[2] = 0.0f; endColor[3] = 0.f;

	[self generateTexture];
	return self;
}

@end


@implementation ZKMRNSpeakerCubeTexture

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

@implementation ZKMRNSpeakerRectangleTexture

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

@implementation ZKMRNVirtualSourceTexture

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



