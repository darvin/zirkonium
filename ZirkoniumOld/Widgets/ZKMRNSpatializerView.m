//
//  ZKMRNSpatializerView.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNSpatializerView.h"
#import "ZKMRNOpenGLShapes.h"
#import "ZKMRNGraphChannel.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNSpeaker.h"
#include <OpenGL/gl.h>
#include <OpenGL/glext.h>

@interface ZKMRNSpatializerView (ZKMRNSpatializerViewPrivate)
- (void)drawSpeakerMesh;
- (void)drawSources;
- (void)undoManagerChangeNotification:(NSNotification *)notification;
@end


@implementation ZKMRNSpatializerView
#pragma mark _____ ZKMRNDomeView Overrides
- (void)awakeFromNib
{
	[super awakeFromNib];
	_panner = [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] panner];
	_pannerSources = nil;
	_isPositionIdeal = YES;
	_isRotateZenith = NO;
	_isShowingMesh = NO;
	_isShowingInitial = NO;
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidUndoChangeNotification object: nil];
	[center addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidRedoChangeNotification object: nil];
	[center addObserver: self selector: @selector(graphChannelInitialChangeNotification:) name: ZKMRNGraphChannelChangedInitalNotification object: nil];
}

- (void)dealloc
{
	if (_pannerSources) [_pannerSources release], _pannerSources = nil;
	if (_sourceTexture) [_sourceTexture release], _sourceTexture = nil;
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frame pixelFormat:(NSOpenGLPixelFormat*)format {
    if (!(self = [super initWithFrame: frame pixelFormat: format])) return nil;

	_isPositionIdeal = YES;
	_isRotateZenith = NO;
	_isShowingMesh = NO;
	_pannerSources = nil;
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidUndoChangeNotification object: nil];
	[center addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidRedoChangeNotification object: nil];

    return self;
}

- (void)setProjectionMatrix
{
	GLdouble ratio;
	ratio = _camera.bounds.width / _camera.bounds.height;
//	gluPerspective(_camera.aperture, ratio, 3.5, 6.5);
	glOrtho(1.2 * ratio, -1.2 * ratio, 1.2, -1.2, 3.5, 6.5);
}

- (void)setViewRotation
{
	glRotatef(-90.0f, 0.0f, 0.0f, 1.0f);
}

- (void)drawDisplay
{
	glEnable(GL_BLEND);					// Enable blending
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);	// Type of blending to perform
	[super drawDisplay];
		// turn off the depth test for the sources -- I always want to see all sources
	glDisable(GL_DEPTH_TEST);
	glBlendFunc(GL_SRC_ALPHA, GL_DST_ALPHA);
	[self drawSources];
	glEnable(GL_DEPTH_TEST);	
	glDisable(GL_BLEND);
}

- (void)drawSpeakers
{
	[super drawSpeakers];
	[self drawSpeakerMesh];
}

- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal
{
	float scale = ZKMORDBToNormalizedDB([[_panner mixer] postAveragePowerForOutput: speakerNum]);
	scale = powf(scale, 4.f);
	glColor3f(2.f * scale, scale + 0.5f, scale * 0.7f);
	scale = MIN(MAX(scale, 0.3f), 1.5);
	glScalef(scale, scale, 1.f);	
	glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
	[_cube drawSquare];
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
	_speakerTexture = [[ZKMRNSpeakerRectangleTexture alloc] init];
	_sourceTexture = [[ZKMRNVirtualSourceTexture alloc] init];
}

#pragma mark _____ NSResponder overrides
- (void)mouseDown:(NSEvent *)theEvent
{
	[self activateOpenGLContext];
	
	[self beginHitTesting: theEvent];
	[self drawSources];
	ZKMRNHitRecords hitRecords = [self endHitTesting];
	
	// process hit records
	GLuint i, numberOfNames = hitRecords.numberOfNames;
	GLuint* names = hitRecords.names;
	ZKMNRPannerSource* selectedSource = nil;
	for (i = 0; i < numberOfNames; i++) selectedSource = [_pannerSources objectAtIndex: names[i]];
		// nothing selected -- get out of here
	if (!selectedSource) return;
	
		// notify delegate
	if (_delegate && [_delegate respondsToSelector: @selector(view:selectedPannerSource:)])
		[_delegate view: self selectedPannerSource: selectedSource];
	
	BOOL delegateGetsMoves = _delegate && [_delegate respondsToSelector: @selector(view:movedPannerSource:toPoint:)];
	// consume events until we are done 
	BOOL keepProcessing = YES;
	BOOL didDrag = NO;
	NSPoint mouseLocation;
	ZKMNRSphericalCoordinate center = _isShowingInitial ? [selectedSource initialCenter] : [selectedSource center];
	ZKMNRRectangularCoordinate dragPosition = ZKMNRSphericalCoordinateToRectangular(center);
	while (keepProcessing) {
		theEvent = [[self window] nextEventMatchingMask: (NSLeftMouseUpMask | NSLeftMouseDraggedMask)];
		mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
				didDrag = YES;
				[self getOpenGLCoord: &dragPosition forWindowLocation: mouseLocation];
				center = ZKMNRPlanarCoordinateLiftedToSphere(dragPosition);
				_isShowingInitial ? [selectedSource setInitialCenter: center] : [selectedSource setCenter: center];
				[self drawDisplay]; glFlush();
				[_panner updatePanningToMixer];
				if (delegateGetsMoves) [_delegate view: self movedPannerSource: selectedSource toPoint: center];
				break;
			case NSLeftMouseUp:
				keepProcessing = NO;
				break;
			default:
				// ignore
				break;
		}
	}
	
	if (didDrag  && _delegate && [_delegate respondsToSelector: @selector(view:movedPannerSource:toPoint:)])
		[_delegate view: self finishedMovePannerSource: selectedSource toPoint: center];

	[self restoreOpenGLContext];
}


#pragma mark _____ Accessors
- (BOOL)isShowingMesh { return _isShowingMesh; }
- (void)setShowingMesh:(BOOL)isShowingMesh
{
	_isShowingMesh = isShowingMesh;
	[self setNeedsDisplay: YES];
}

- (BOOL)isShowingInitial { return _isShowingInitial; }
- (void)setShowingInitial:(BOOL)isShowingInitial
{
	_isShowingInitial = isShowingInitial;
	[self setNeedsDisplay: YES];
}

- (NSArray *)pannerSources { return _pannerSources; }
- (void)setPannerSources:(NSArray *)pannerSources
{
	if (pannerSources) [pannerSources retain];
	[_pannerSources release], _pannerSources = nil;
	_pannerSources = pannerSources;
	[self setNeedsDisplay: YES];
}

#pragma mark _____ ZKMRNSpatializerViewPrivate
- (void)drawSpeakerMesh
{
	if (!_isShowingMesh) return;
	NSArray* speakerMesh;
	if (!(speakerMesh = [_panner speakerMesh])) return;
	
	// draw the mesh
	glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
	glEnable(GL_LINE_SMOOTH);
	glLineWidth(2.f);
	glColor4f(0.4f, 0.1f, 0.1f, 1.0f);
	NSEnumerator* meshElts = [speakerMesh objectEnumerator];
	ZKMNRSpeakerMeshElement* meshElement;
	while (meshElement = [meshElts nextObject]) {
		unsigned count = [meshElement numberOfSpeakers];
		NSEnumerator* speakers = [[meshElement speakers] objectEnumerator];
		ZKMNRSpeakerPosition* pos;
		glBegin(GL_TRIANGLES);	
		while (pos = [speakers nextObject]) {
			ZKMNRRectangularCoordinate speakerPositionRect;
			speakerPositionRect = (_isPositionIdeal) ? ZKMNRSphericalCoordinateToRectangular([pos coordPlatonic]) : [pos coordRectangular];
			float x = speakerPositionRect.x, y = speakerPositionRect.y, z = speakerPositionRect.z;
			glVertex3f(x, y, z);		
		}
		if (count < 3) glVertex3f(0.f, 0.f, 0.f);
		glEnd();
	}
	glLineWidth(1.f);
	glDisable(GL_LINE_SMOOTH);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
}

- (void)drawSources
{
	if (!_pannerSources) return;

	glEnable(GL_TEXTURE_2D);
	NSEnumerator* sources = [_pannerSources objectEnumerator];
	ZKMNRPannerSource* source;
	unsigned i;
	for (i = 0; source = [sources nextObject]; i++) {
			// set up the color and texture
		ZKMRNGraphChannel* tag = [source tag];
		float r = 0.5f, g = 0.5f, b = 0.9f, a = 1.f;
		if (tag) [[tag color] getRed: &r green: &g blue: &b alpha: &a];
		glColor4f(r, g, b, a);
		glBindTexture(GL_TEXTURE_2D, [_sourceTexture textureID]);
			
		glPushName(i);
			// have the source call us back for each of the spatial samples
			[source expandFor: self useInitial: _isShowingInitial];
		glPopName();
	}
	glDisable(GL_TEXTURE_2D);
}

- (void)undoManagerChangeNotification:(NSNotification *)notification
{
	[self setNeedsDisplay: YES];
}

- (void)graphChannelInitialChangeNotification:(NSNotification *)notification
{
	[self setNeedsDisplay: YES];
}

#pragma mark _____ ZKMNRPannerSourceExpanding
- (void)pannerSource:(ZKMNRPannerSource *)source spatialSampleAt:(ZKMNRRectangularCoordinate)center
{
	glPushMatrix();
		glTranslatef(center.x, center.y, center.z);
//  Undo Rotation
//		glRotatef(-_xRot, 1.0f, 0.0f, 0.0f);
//		glRotatef(-_yRot, 0.0f, 1.0f, 0.0f);			
		glScalef(0.2f, 0.2f, 0.3f);
		[_cube drawSquare];
	glPopMatrix();
}

@end

