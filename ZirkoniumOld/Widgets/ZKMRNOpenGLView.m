//
//  ZKMRNOpenGLView.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOpenGLView.h"


@implementation ZKMRNOpenGLView
#pragma mark _____ NSOpenGLView overrides
- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
}

- (BOOL)isOpaque { return YES; }
- (void)reshape { [self setupOpenGL]; /*[self display];*/ }

- (void)prepareOpenGL
{
	NSOpenGLPixelFormat* pixelFormat = [self pixelFormat];
	long isDoubleBuffered;
	[pixelFormat getValues: &isDoubleBuffered forAttribute: NSOpenGLPFADoubleBuffer forVirtualScreen: 0];
	_isDoubleBuffered = isDoubleBuffered;
}

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
	GLuint attribs[] = 
	{
		NSOpenGLPFANoRecovery,			// don't fail over to the software renderer
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
#if GL_ANTI_ALIASED		
		NSOpenGLPFASampleBuffers, 1,	// turn on full scene anti-aliasing
		NSOpenGLPFASamples, 2,			// sample at 2x for the full scene anti-aliasing
#endif
		NSOpenGLPFAColorSize, 24, 
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 16,
		NSOpenGLPFAStencilSize, 0,
		NSOpenGLPFAAccumSize, 0,		
		0
	};

	NSOpenGLPixelFormat* fmt = 
		[[NSOpenGLPixelFormat alloc] 
			initWithAttributes: (NSOpenGLPixelFormatAttribute*) attribs];
			
	return fmt;
}

#pragma mark _____ Internal Functions
- (void)setupOpenGL { }
- (void)setProjectionMatrix { }
- (void)setModelViewMatrix { }

- (void)activateOpenGLContext
{
	if ([NSOpenGLContext currentContext] != [self openGLContext]) {
		_savedOpenGLContext = [NSOpenGLContext currentContext];
		[[self openGLContext] makeCurrentContext];
	} else {
		_savedOpenGLContext = nil;
	}
}

- (void)restoreOpenGLContext
{
	// restore the OGL Context if necessary
	if (_savedOpenGLContext) [_savedOpenGLContext makeCurrentContext];
	_savedOpenGLContext = nil;
}

#pragma mark _____ Hit Records
- (void)beginHitTesting:(NSEvent *)theEvent
{
	glSelectBuffer(64, _selectBuffer);
	glRenderMode(GL_SELECT);
	
	NSPoint localPoint = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	GLint viewport[4]; glGetIntegerv(GL_VIEWPORT, viewport);
	gluPickMatrix(localPoint.x, localPoint.y, 0.1, 0.1, viewport);
	[self setProjectionMatrix];	

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	[self setModelViewMatrix];
	glInitNames();
}

- (ZKMRNHitRecords)endHitTesting
{
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
//	glFlush(); 
	
	ZKMRNHitRecords hitRecords = { 0, NULL };
	GLint hits = glRenderMode(GL_RENDER);
	
	if (0 == hits) return hitRecords;
	if (hits < 1)
		// overflow of the select buffer -- just pick the first one
		hits = 1;

	// process hit records
	[self getHitRecords: &hitRecords fromHits: _selectBuffer count: hits];
	return hitRecords;
}

- (GLuint)getHitRecords:(ZKMRNHitRecords *)hitRecords fromHits:(GLuint *)hitPtr count:(GLint)hitCount
{
/*
	hitRecords->numberOfNames = 0;
	hitRecords->names = NULL;
	GLuint numberOfNames, minZ = 0xFFFFFFFF;
	GLint i;	
	for (i = 0; i < hitCount; i++) {
		// hit record layout -- { UInt32 numberOfNames, UInt32 minZ, UInt32 maxZ, UInt32[numberOfNames] nameStack }
		numberOfNames = *hitPtr++;
		if (*hitPtr < minZ && (numberOfNames < INT_MAX)) {
			hitRecords->numberOfNames = numberOfNames;
			minZ = *hitPtr;
			hitRecords->names = hitPtr + 2;
		}
	}
	return hitRecords->numberOfNames;
*/
	hitRecords->numberOfNames = 0;
	hitRecords->names = NULL;
	GLuint overallMinZ = 0xFFFFFFFF;
	GLuint overallMaxZ = 0;
	GLint i;	
	for (i = 0; i < hitCount; i++) {
		// hit record layout -- { UInt32 numberOfNames, UInt32 minZ, UInt32 maxZ, UInt32[numberOfNames] nameStack }
		UInt32 numberOfNames, minZ, maxZ;
		numberOfNames = *hitPtr++; minZ = *hitPtr++; maxZ = *hitPtr++;
		if (minZ < overallMinZ) {
			overallMinZ = minZ;
			hitRecords->numberOfNames = numberOfNames;
			hitRecords->names = hitPtr;
		}
		if (maxZ > overallMaxZ) {
			overallMaxZ = maxZ;
		}
		unsigned j;
		for (j = 0; j < numberOfNames; j++, hitPtr++);
	}
	return hitRecords->numberOfNames;
}

#pragma mark _____ Coordinate Transforms
- (void)getOpenGLCoord:(ZKMNRRectangularCoordinate *)coord forWindowLocation:(NSPoint)point
{
	GLint viewport[4];
	GLdouble modelview[16];
	GLdouble projection[16];
	GLdouble x, y, z, mouseZ;
		
	glGetDoublev(GL_PROJECTION_MATRIX, projection);
	glGetDoublev(GL_MODELVIEW_MATRIX, modelview);
	glGetIntegerv(GL_VIEWPORT, viewport);
	glReadPixels((int) point.x, (int) point.y, 1, 1, GL_DEPTH_COMPONENT, GL_DOUBLE, &mouseZ);
	if (isnan(mouseZ)) mouseZ = 0.f;
	gluUnProject((GLdouble) point.x, (GLdouble) point.y, mouseZ, modelview, projection, viewport, &x, &y, &z);
	coord->x = x; coord->y = y; coord->z = z;
}

@end

@implementation ZKMRNOpenGLTexture

- (void)dealloc
{
	if (_textureBitmap) [_textureBitmap release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
		
	_textureBitmap = nil;
		// frame size needs to be a power of 2
	_frame = NSMakeRect(0.f, 0.f, 128.f, 128.f);

	return self;
}

- (GLuint)textureID { return _textureID; }
- (NSRect)frame { return _frame; }

- (void)generateTexture
{

}

- (void)bindTexture
{
	glEnable(GL_TEXTURE_2D);
	// create an OpenGL texture
		// this is for non-power of two textures
//	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, 1);
//	glPixelStorei(GL_UNPACK_ROW_LENGTH, _frame.size.width);
//	glGenTextures(1, &_textureID);
//	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _textureID);
//	glTexImage2D(	GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, 
//					_frame.size.width, _frame.size.height,
//					0, GL_RGBA, GL_UNSIGNED_BYTE, [_textureBitmap bitmapData]);
					
	glGenTextures(1, &_textureID);
	glBindTexture(GL_TEXTURE_2D, _textureID);
//	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
//	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);		
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
	glTexImage2D(	GL_TEXTURE_2D, 0, GL_RGBA,
					_frame.size.width, _frame.size.height,
					0, GL_RGBA, GL_UNSIGNED_BYTE, [_textureBitmap bitmapData]);
	glDisable(GL_TEXTURE_2D);
}

@end