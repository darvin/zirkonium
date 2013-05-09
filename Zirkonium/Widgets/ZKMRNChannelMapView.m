//
//  ZKMRNChannelMapView.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNChannelMapView.h"
#import "ZKMRNOpenGLShapes.h"
#include <OpenGL/gl.h>
#include <OpenGL/glext.h>


@interface ZKMRNChannelMapView (ZKMRNChannelMapViewPrivate)

- (void)addMatrixObserver;
- (void)removeMatrixObserver;
- (void)resetCamera;
- (void)resetDrawingState;
- (void)drawReferenceObjects;
- (void)drawMatrix;
- (void)drawMatrixSelect;

@end

static void 	CrosspointForMatrixElement(unsigned* inputBus, unsigned* outputBus, unsigned element)
{
	*outputBus = element & 0x0000FFFF;
	*inputBus = (element >> 16) & 0x0000FFFF;	
}


@implementation ZKMRNChannelMapView

#pragma mark _____ ZKMRNOpenGLView overrides
- (void)awakeFromNib
{
	_cube = [[ZKMRNOpenGLCube alloc] init];
}

- (void)dealloc
{
	[self setChannelMap: nil];
	if (_cube) [_cube release];
//	if (_speakerTexture) [_speakerTexture release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame pixelFormat:(NSOpenGLPixelFormat*)format {
    if (!(self = [super initWithFrame: frame pixelFormat: format])) return nil;

	[[ self openGLContext ] makeCurrentContext];

    return self;
}

- (void)drawRect:(NSRect)rect {
	[self resetDrawingState];
	
	[self drawMatrix];
		// want the reference objects (dividing lines) on top of the matrix
	[self drawReferenceObjects];	
	
	(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
//	_speakerTexture = [[ZKMRNSpeakerCubeTexture alloc] init];
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
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	gluLookAt(	_camera.position.x, _camera.position.y, _camera.position.z,
				_camera.center.x, _camera.center.y, _camera.center.z,
				_camera.up.x, _camera.up.y, _camera.up.z);
}


#pragma mark _____ NSResponder overrides
- (void)mouseDown:(NSEvent *)theEvent
{
	[self beginHitTesting: theEvent];
	[self drawMatrixSelect];
	ZKMRNHitRecords hitRecords = [self endHitTesting];
	
	GLuint i, numberOfNames = hitRecords.numberOfNames;
	GLuint* names = hitRecords.names;
	for (i = 0; i < numberOfNames; i++) {
		unsigned input, output;
		CrosspointForMatrixElement(&input, &output, names[i]);
		float volume = ([_channelMap volumeForCrosspointInput: input output: output] > 0.1f) ? 0.f : 1.f;
			// turn on a crosspoint that was off, and turn off if it was on
		[_channelMap setVolume: volume forCrosspointInput: input output: output];
	}
	[self setNeedsDisplay: YES];
}

#pragma mark _____ Accessors
- (ZKMRNChannelMap *)channelMap { return _channelMap; }
- (void)setChannelMap:(ZKMRNChannelMap *)channelMap
{
	if (_channelMap != channelMap) {
		[self removeMatrixObserver];
		_channelMap = channelMap;
		[self addMatrixObserver];
	}
	[self setNeedsDisplay: YES];
}

#pragma mark _____ ZKMRNDomeViewPrivate
- (void)addMatrixObserver
{
	if (!_channelMap) return;
	[_channelMap addObserver: self forKeyPath: @"matrix" options: NSKeyValueObservingOptionNew context: NULL];
}

- (void)removeMatrixObserver
{
	if (!_channelMap) return;
	[_channelMap removeObserver: self forKeyPath: @"matrix"];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath  ofObject:(id)object change:(NSDictionary *)change 
					context:(void *)context
{
	if ([keyPath isEqualToString: @"matrix"]) {
		[self setNeedsDisplay: YES];
		return;
	}	
}

- (void)resetCamera
{
	_camera.aperture = 25.;
	
	_camera.position.x = 0.f;
	_camera.position.y = 0.f;
	_camera.position.z = -5.f;
	_camera.center.x = 0.f; 
	_camera.center.y = 0.f; 
	_camera.center.z = 0.f;

	_camera.up.x = 0.f;			
	_camera.up.y = 1.f;
	_camera.up.z = 0.f;
}

- (void)resetDrawingState
{
	[self setupOpenGL];
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClearDepth(1.0);
	glShadeModel(GL_SMOOTH);
//	glEnable(GL_DEPTH_TEST);
//	glDepthFunc(GL_LEQUAL);
//	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

	glDisable(GL_DEPTH_TEST);
	glEnable(GL_BLEND);					// Enable blending
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);	// Type of blending to perform
	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
	glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
	
	glEnable(GL_RESCALE_NORMAL);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	[self setProjectionMatrix];
	[self setModelViewMatrix];	
}

- (void)drawReferenceObjects 
{
	unsigned input, output;
	unsigned numInputs = [[_channelMap valueForKey: @"numberOfInputs"] unsignedIntValue];
	unsigned numOutputs = [[_channelMap valueForKey: @"numberOfOutputs"] unsignedIntValue];
	float inputScale = 2.f/numInputs;
	float outputScale = 2.f/numOutputs;	
	
	// draw the grid
	glBegin(GL_LINES);
		glColor3f(1.f, 1.f, 1.f);
//		glColor3f(0.5f, 0.5f, 0.5f);
		glVertex3f( 1.f, -1.f, 0.f);
		glVertex3f(-1.f, -1.f, 0.f);
		glVertex3f( 1.f,  1.f, 0.f);
		glVertex3f(-1.f,  1.f, 0.f);
		
		glVertex3f(-1.f,  1.f, 0.f);
		glVertex3f(-1.f, -1.f, 0.f);
		glVertex3f( 1.f,  1.f, 0.f);
		glVertex3f( 1.f, -1.f, 0.f);

		for (input = 0; input < numInputs; input++) {
			float y = 1.f - ((input + 1) * inputScale);
			glVertex3f( 1.f, y, 0.f);
			glVertex3f(-1.f, y, 0.f);
			
			for (output = 0; output < numOutputs; output++) {
				float x = 1.f - (output + 1) * outputScale;
				glVertex3f(x,  1.f, 0.f);
				glVertex3f(x, -1.f, 0.f);
			}
		}
	glEnd();
}

- (void)drawMatrix
{
	if (!_channelMap) return;
	
	unsigned input, output;
	unsigned numInputs = [[_channelMap valueForKey: @"numberOfInputs"] unsignedIntValue];
	unsigned numOutputs = [[_channelMap valueForKey: @"numberOfOutputs"] unsignedIntValue];
	float inputScale = 2.f/numInputs;
	float outputScale = 2.f/numOutputs;
	float startX = 1.f - (outputScale * 0.5f), startY = 1.f - (inputScale * 0.5f);
//	glEnable(GL_TEXTURE_2D);
	for (input = 0; input < numInputs; input++) {
		float y = startY - input*inputScale;
		float z = 0.f;
		for (output = 0; output < numOutputs; output++) {
			float x = startX - output*outputScale;
			float blueFactor = [_channelMap volumeForCrosspointInput: input output: output];
			glColor3f(0.f, 0.f, blueFactor);
//			glColor3f(((float)numInputs - input)/numInputs, 0.f, ((float)numOutputs - output)/numOutputs);

			glPushMatrix();
				glTranslatef(x, y, z);	
				glScalef(outputScale, inputScale, 1.f);	
//				glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
				[_cube drawSquare];
			glPopMatrix();			
		}
	}
//	glDisable(GL_TEXTURE_2D);
}

- (void)drawMatrixSelect
{
	if (!_channelMap) return;
	
	unsigned input, output;
	unsigned numInputs = [[_channelMap valueForKey: @"numberOfInputs"] unsignedIntValue];
	unsigned numOutputs = [[_channelMap valueForKey: @"numberOfOutputs"] unsignedIntValue];
	float inputScale = 2.f/numInputs;
	float outputScale = 2.f/numOutputs;
	float startX = 1.f - (outputScale * 0.5f), startY = 1.f - (inputScale * 0.5f);
	for (input = 0; input < numInputs; input++) {
		float y = startY - input*inputScale;
		float z = 0.f;
		for (output = 0; output < numOutputs; output++) {
			float x = startX - output*outputScale;
			float blueFactor = [_channelMap volumeForCrosspointInput: input output: output];
			glColor3f(0.f, 0.f, blueFactor);

			glPushName(ElementForMatrixCrosspoint(input, output));
			glPushMatrix();
				glTranslatef(x, y, z);	
				glScalef(outputScale, inputScale, 1.f);	
				[_cube drawSquare];
			glPopMatrix();
			glPopName();
		}
	}
}


@end
