//
//  ZKMRNOpenGLView.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOpenGLView.h"
#import <OpenGL/glu.h>


@implementation ZKMRNOpenGLView

#pragma mark -
#pragma mark Pixel Format
#pragma mark -

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


#pragma mark -
#pragma mark Initialize
#pragma mark -

-(void)initialize
{
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.showCoordinateSystem" options:0 context:nil]; 
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.showSpeakerMesh" options:0 context:nil]; 
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.showIDNumbers" options:0 context:nil]; 
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.showIDVolumes" options:0 context:nil]; 
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.showSpeakersNumbering" options:0 context:nil]; 
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.speakersNumberingMode" options:0 context:nil];
	_isHitTesting = NO;
}

-(void)awakeFromNib
{
	[self initialize];	
}

#pragma mark -
#pragma mark Live Resize (Reshape)
#pragma mark -

- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
}


- (void)reshape 
{ 
	[self setupOpenGL]; 
	[self setNeedsDisplay:YES]; 
} 

- (void)prepareOpenGL
{
	NSOpenGLPixelFormat* pixelFormat = [self pixelFormat];
	GLint isDoubleBuffered;
	[pixelFormat getValues: &isDoubleBuffered forAttribute: NSOpenGLPFADoubleBuffer forVirtualScreen: 0];
	_isDoubleBuffered = isDoubleBuffered;
	
	glEnable(GL_BLEND);	
}


#pragma mark -
#pragma mark Subclasses Override 
#pragma mark -

- (void)setupOpenGL { }
- (void)setProjectionMatrix { }
- (void)setModelViewMatrix { }

#pragma mark -
#pragma mark OpenGL Context
#pragma mark -

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

#pragma mark -
#pragma mark Hit Testing
#pragma mark -

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
	_isHitTesting = YES;
}

- (ZKMRNHitRecords)endHitTesting
{
	_isHitTesting = NO;
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	
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

#pragma mark -
#pragma mark Coordinate Transform 
#pragma mark -

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
	mouseZ = 0.f; 
	gluUnProject((GLdouble) point.x, (GLdouble) point.y, mouseZ, modelview, projection, viewport, &x, &y, &z);
	coord->x = x; coord->y = y; coord->z = z;
}

#pragma mark -
#pragma mark View Preferences Observation
#pragma mark -

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// User Defaults Observation ...
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark OpenGLView Overrides
#pragma mark -

- (BOOL)isOpaque { return YES; }

#pragma mark -
#pragma mark Clean Up
#pragma mark -

-(void)dealloc
{	
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.showCoordinateSystem"]; 
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.showSpeakerMesh"]; 
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.showIDNumbers"]; 
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.showIDVolumes"]; 
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.showSpeakersNumbering"]; 
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:@"values.speakersNumberingMode"]; 

	//[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self]; 
	[super dealloc];
}

@end

