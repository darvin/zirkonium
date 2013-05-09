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
#include <GLUT/glut.h>

@interface ZKMRNSpatializerView (ZKMRNSpatializerViewPrivate)
- (void)drawSpeakerMesh;
- (void)drawSources;
- (void)undoManagerChangeNotification:(NSNotification *)notification;
@end


@implementation ZKMRNSpatializerView
@synthesize useCamera; 
@synthesize isShowingInitial; 

#pragma mark -
#pragma mark Initialize
#pragma mark -

- (void)awakeFromNib
{
	[super awakeFromNib];
	_panner = [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] panner];
	_pannerSources = nil;

	self.isPositionIdeal = YES;
	self.isRotateZenith = NO;
	self.isShowingInitial = NO;
	self.useCamera = NO; 
	
	_camAdjust = [[ZKMRNSpatializerViewCameraAdjustment alloc] init];
	
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidUndoChangeNotification object: nil];
	[center addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidRedoChangeNotification object: nil];
	[center addObserver: self selector: @selector(graphChannelInitialChangeNotification:) name: ZKMRNGraphChannelChangedInitalNotification object: nil];
	[center addObserver: self selector: @selector(viewUpdate:) name:@"ZKMRNSpatializerViewShouldUpdate" object:nil];
	
	_lock = [[NSRecursiveLock alloc] init];

}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
	_speakerTexture = [[ZKMRNSpeakerRectangleTexture alloc] init];
	_sourceTexture = [[ZKMRNVirtualSourceTexture alloc] init];
	_circle = [[ZKMRNOpenGLCircle alloc] initWithSegments:5 andRadius:1.0];
}

#pragma mark -
#pragma mark Draw
#pragma mark -

- (void)setProjectionMatrix
{
	GLdouble ratio;
	ratio = _camera.bounds.width / _camera.bounds.height;
	if(self.useCamera) {
		gluPerspective(_camera.aperture, ratio, 3.5, 6.5);
	} else {
		glOrtho(1.2 * ratio, -1.2 * ratio, 1.2, -1.2, 3.5, 6.5);
	}
}

- (void)drawDisplay
{
	glEnable(GL_BLEND);					// Enable blending
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);	// Type of blending to perform
	[super drawDisplay];
	// turn off the depth test for the sources -- I always want to see all sources
	glDisable(GL_DEPTH_TEST);
	glBlendFunc(GL_SRC_ALPHA, GL_DST_ALPHA);
	if([self viewType] != kDomeView2DMappingType) [self drawSources];
	glEnable(GL_DEPTH_TEST);	
	glDisable(GL_BLEND);
}

#pragma mark -
#pragma mark Camera
#pragma mark -

- (void)setViewRotation
{
	if(self.useCamera) {
		glRotatef(90.0f, 0.0f, 0.0f, 1.0f);
		glRotatef([_camAdjust xRotation], 1.0f, 0.0f, 0.0f);
		glRotatef([_camAdjust yRotation], 0.0f, 1.0f, 0.0f);
	}
	else {
		glRotatef(-90.0f, 0.0f, 0.0f, 1.0f);
	}
}

- (float)xRotation { return [_camAdjust xRotation]; }
- (float)yRotation { return [_camAdjust yRotation]; }
- (void)setXRotation:(float)xRotation { [_camAdjust setXRotation:xRotation]; }
- (void)setYRotation:(float)yRotation { [_camAdjust setYRotation:yRotation]; }

//-(void)setUseCamera:(BOOL)useCamera { _useCamera = useCamera; }
//-(BOOL)useCamera { return _useCamera; }

#pragma mark -
#pragma mark Sources
#pragma mark -

- (NSArray *)pannerSources { return _pannerSources; }
- (void)setPannerSources:(NSArray *)pannerSources
{
	if (pannerSources) [pannerSources retain];
	[_pannerSources release], _pannerSources = nil;
	_pannerSources = pannerSources;
	[self setNeedsDisplay: YES];
}

#pragma mark -
#pragma mark Rendering
#pragma mark -

- (void)drawSpeakers
{
	[super drawSpeakers];
	[self drawSpeakerMesh];
}

- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal
{
	float scale = ZKMORDBToNormalizedDB([[_panner mixer] postAveragePowerForOutput: speakerNum]);
	scale = ([self viewType]==kDomeView2DMappingType) ? 0.3f : powf(scale, 4.f);
	glColor3f(2.f * scale, scale + 0.5f, scale * 0.7f);
	scale = MIN(MAX(scale, 0.3f), 1.5);
	glScalef(scale, scale, scale); 	
	glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
	[_cube drawCube];
}

- (void)drawSources
{
	if (!_pannerSources) return;

	NSEnumerator* sources = [_pannerSources objectEnumerator];
	ZKMNRPannerSource* source;
	unsigned i;
	for (i = 0; source = [sources nextObject]; i++) {
		
		glPushName(i);
			_processedSourceIndex = i;
			// have the source call us back for each of the spatial samples
			[source expandFor: self useInitial: self.isShowingInitial];
		glPopName();
	}
}


#pragma mark -
#pragma mark Panner Source
#pragma mark -

-(void)billboardBegin {
	
	float modelview[16];
	int i,j;

	// save the current modelview matrix
	glPushMatrix();

	// get the current modelview matrix
	glGetFloatv(GL_MODELVIEW_MATRIX , modelview);

	// undo all rotations
	// beware all scaling is lost as well 
	for( i=0; i<3; i++ ) 
	    for( j=0; j<3; j++ ) {
		if ( i==j )
		    modelview[i*4+j] = 1.0;
		else
		    modelview[i*4+j] = 0.0;
	    }

	// set the modelview with no rotations
	glLoadMatrixf(modelview);
}



-(void)billboardEnd {

	// restore the previously 
	// stored modelview matrix
	glPopMatrix();
}

- (void)pannerSource:(ZKMNRPannerSource *)source spatialSampleAt:(ZKMNRRectangularCoordinate)center
{
	if(!source) { return; }
	
	ZKMRNGraphChannel* tag = [source tag];
	float r = 0.5f, g = 0.5f, b = 0.9f, a = 1.f;
	//crash on 10.6 (JB)
	if (tag) { [[tag color] getRed: &r green: &g blue: &b alpha: &a]; }
	glColor4f(r, g, b, 1.0);
	
	//Draw ID Name String
	
	BOOL showIDNumbers = [[[NSUserDefaults standardUserDefaults] valueForKey:@"showIDNumbers"] boolValue]; 
	
	if(showIDNumbers) {
		glPushMatrix();
			[_glString renderBitmapString:[[source tag] displayString] x:center.x+0.05 y:center.y-0.05 z:center.z];
		glPopMatrix();
	}
	
	BOOL showIDVolumes = [[[NSUserDefaults standardUserDefaults] valueForKey:@"showIDVolumes"] boolValue]; 
	
	float v = 1.0; 
	
	if(showIDVolumes) {
		float scale = ZKMORDBToNormalizedDB([[_panner mixer] postAveragePowerForInput: _processedSourceIndex]);
		scale = (scale > 0.0) ? powf(scale, 4.f) : 0.0;
		scale = MAX(MIN(2.0, scale), 0.0);
		v = 0.05 + (0.15*scale);
	}
	
	//Draw fix source circle
	glPushMatrix();
		glTranslatef(center.x, center.y, center.z);
		
		if(self.useCamera) {
		
			[self billboardBegin];
			
				glPushMatrix();
				glScalef(0.05f, 0.05f, 0.05f);
				[_circle drawCircle];
				glPopMatrix();
				
				if(/*!self.isShowingInitial && */showIDVolumes && [self pieceIsPlaying]) {
					//Draw source volume level by a scaled circle
					glPushMatrix();
					glScalef(v, v, v);
					[_circle drawCircle];				
					glPopMatrix();
				}
			[self billboardEnd];
		}
		else { 
			glPushMatrix();	
			glScalef(0.05f, 0.05f, 0.05f);
			[_circle drawCircle];
			glPopMatrix();			
			
			if(/*!self.isShowingInitial && */showIDVolumes && [self pieceIsPlaying]) {
					//Draw source volume level by a scaled circle
					glPushMatrix();
					glScalef(v, v, v);
					[_circle drawCircle];				
					glPopMatrix();
				}
			
			//Draw Invisible Speaker for Hit Testing ...
			glColor4f(0.0, 0.0, 0.0, 0.0);
			glPushMatrix();	
			glScalef(0.2f, 0.2f, 0.3f);
			[_cube drawSquare];
			glPopMatrix();

			
		}
	glPopMatrix();
}

#pragma mark -
#pragma mark Mouse
#pragma mark -

- (void)mouseUp:(NSEvent *)theEvent
{
	[self activateOpenGLContext];

	NSPoint mouseLocation;
	ZKMNRSphericalCoordinate center;
	ZKMNRRectangularCoordinate dragPosition;

	center = self.isShowingInitial ? [_selectedSource initialCenter] : [_selectedSource center];
	dragPosition = ZKMNRSphericalCoordinateToRectangular(center);
	mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	[self getOpenGLCoord: &dragPosition forWindowLocation: mouseLocation];
	center = ZKMNRPlanarCoordinateLiftedToSphere(dragPosition);
	self.isShowingInitial ? [_selectedSource setInitialCenter: center] : [_selectedSource setCenter: center];


	if(_didDrag && _delegateGetsMoves)
		[self.delegate view: self finishedMovePannerSource: _selectedSource toPoint: center];
		
	_selectedSource = nil; 
	_didDrag = NO;

	[self drawDisplay]; 
	(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
	
	[self restoreOpenGLContext];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	[self activateOpenGLContext];

	NSPoint mouseLocation;
	mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];


	if(self.useCamera) {
	
		[self setXRotation:([_camAdjust xRotation] + [theEvent deltaX])];
		[self setYRotation:([_camAdjust yRotation] - [theEvent deltaY])];
	
	} else {

		ZKMNRSphericalCoordinate center;
		ZKMNRRectangularCoordinate dragPosition;
		
		if(_selectedSource)
		{
			center = self.isShowingInitial ? [_selectedSource initialCenter] : [_selectedSource center];
			dragPosition = ZKMNRSphericalCoordinateToRectangular(center);
			[self getOpenGLCoord: &dragPosition forWindowLocation: mouseLocation];
			center = ZKMNRPlanarCoordinateLiftedToSphere(dragPosition);
			self.isShowingInitial ? [_selectedSource setInitialCenter: center] : [_selectedSource setCenter: center];
			
			[self drawDisplay]; 
			(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
			
			[_panner updatePanningToMixer];
			if (_delegateGetsMoves) [self.delegate view: self movedPannerSource: _selectedSource toPoint: center];
			_didDrag = YES;
		}
	}
		
	[self restoreOpenGLContext];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self activateOpenGLContext];
	
	[self beginHitTesting: theEvent];
	[self drawSources];
	ZKMRNHitRecords hitRecords = [self endHitTesting];
	
	// process hit records
	GLuint i, numberOfNames = hitRecords.numberOfNames;
	GLuint* names = hitRecords.names;
	
	_selectedSource = nil;
	
	for (i = 0; i < numberOfNames; i++) _selectedSource = [_pannerSources objectAtIndex: names[i]];
		// nothing selected -- get out of here
	if (!_selectedSource) { 
		[self restoreOpenGLContext]; 
		return; 
	}
	
		// notify delegate
	if (self.delegate && [(NSObject*)self.delegate respondsToSelector: @selector(view:selectedPannerSource:)])
		[self.delegate view: self selectedPannerSource: _selectedSource];
	
	_delegateGetsMoves = self.delegate && [(NSObject*)self.delegate respondsToSelector: @selector(view:movedPannerSource:toPoint:)];
	
	[self restoreOpenGLContext];
}

#pragma mark -
#pragma mark Update Notification
#pragma mark -

-(void)viewUpdate:(NSNotification*)inNotification
{
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Undo Notification
#pragma mark -

- (void)undoManagerChangeNotification:(NSNotification *)notification
{
	[self setNeedsDisplay: YES];
}

#pragma mark -
#pragma mark Graph Notification
#pragma mark -

- (void)graphChannelInitialChangeNotification:(NSNotification *)notification
{
	[self setNeedsDisplay: YES];
}


#pragma mark -
#pragma mark Clean Up
#pragma mark -

- (void)dealloc
{
	if (_camAdjust) [_camAdjust release], _camAdjust = nil; 
	if (_pannerSources) [_pannerSources release], _pannerSources = nil;
	if (_sourceTexture) [_sourceTexture release], _sourceTexture = nil;
	if (_circle) [_circle release], _circle = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}


@end

