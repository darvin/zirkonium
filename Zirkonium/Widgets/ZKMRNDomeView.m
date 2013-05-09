//
//  ZKMRNDomeView.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 27.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNDomeView.h"
#include <OpenGL/gl.h>
#include <OpenGL/glext.h>
#import "ZKMRNZirkoniumSystem.h"

@implementation ZKMRNDomeView
@synthesize viewType; 
@synthesize isPositionIdeal; 
@synthesize isRotateZenith; 
@synthesize pieceIsPlaying; 
@synthesize delegate; 

#pragma mark -
#pragma mark Initialize
#pragma mark -

- (void)awakeFromNib
{
	[super awakeFromNib];

	_previewPanner = nil; 
	_cube = [[ZKMRNOpenGLCube alloc] init];
	_glString = [[ZKMRNOpenGLString alloc] init];
	self.isRotateZenith = YES;
	
	_cameraAdjustment = [[ZKMRNDomeViewCameraAdjustment sharedManager] retain]; 
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidUndoChangeNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(undoManagerChangeNotification:) name: NSUndoManagerDidRedoChangeNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewPreferenceChanged:) name:@"ViewPreferenceChanged" object:nil];
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
	[self resetCamera];
}



#pragma mark -
#pragma mark Clean Up
#pragma mark -

- (void)dealloc
{
	if(_previewPanner) { [_previewPanner release]; _previewPanner = nil; }
	[self setSpeakerLayout: nil];
	if (_cube) [_cube release];
	if (_speakerTexture) [_speakerTexture release];
	if (_cameraAdjustment) [_cameraAdjustment release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self]; 
	
	[super dealloc];
}

#pragma mark -
#pragma mark Draw
#pragma mark -

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


- (void)drawRect:(NSRect)rect {
	
	[self drawDisplay];
	
	(_isDoubleBuffered) ? [[self openGLContext] flushBuffer] : glFlush();
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

#pragma mark -
#pragma mark Panner
#pragma mark -

-(ZKMNRVBAPPanner*)previewPanner {
	if(!_previewPanner) {
		_previewPanner = [[ZKMNRVBAPPanner alloc] init];
	}
	return _previewPanner; 
}

#pragma mark -
#pragma mark Speaker Layout 
#pragma mark -

- (ZKMNRSpeakerLayout *)speakerLayout { return _speakerLayout; }
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout
{
	if (_speakerLayout != speakerLayout) {
		[_speakerLayout release];
		_speakerLayout = (speakerLayout) ? [speakerLayout retain] : nil;
		
		[[self previewPanner] setSpeakerLayout:speakerLayout];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];
}


#pragma mark -
#pragma mark Speaker Position
#pragma mark -

-(void)setSelectedSpeakerPositions:(NSArray*)array
{
	if(_selectedSpeakerPositions)
		[_selectedSpeakerPositions release];
	_selectedSpeakerPositions = [array retain];
	
	if([array count]>0) {
		_selectedRing = [[[[array objectAtIndex:0] valueForKey:@"speakerRing"] valueForKey:@"ringNumber"] intValue];
	}
	
	[self setNeedsDisplay:YES]; 
}

- (void)dragSpeaker
{
	ZKMNRRectangularCoordinate dragMouseDelta;
	ZKMNRRectangularCoordinate newSpeakerPosition;
	
	if(_initiatedDragSpeaker) {
		[self getOpenGLCoord: &_startMousePosition forWindowLocation: _mouseLocation];
		_initiatedDragSpeaker = NO; 
	}
	
	[self getOpenGLCoord: &dragMouseDelta forWindowLocation: _mouseLocation];
	
	// convert the drag position to a delta
	dragMouseDelta.x -= _startMousePosition.x; 
	dragMouseDelta.y -= _startMousePosition.y; 
	dragMouseDelta.z -= _startMousePosition.z;
	newSpeakerPosition.x = ZKMORClamp(_startSpeakerPosition.x + dragMouseDelta.x, -1.f, 1.f);
	newSpeakerPosition.y = ZKMORClamp(_startSpeakerPosition.y + dragMouseDelta.y, -1.f, 1.f);
	newSpeakerPosition.z = ZKMORClamp(_startSpeakerPosition.z + dragMouseDelta.z, -1.f, 1.f);								
	
	if(_selectedSpeaker) {
		[_selectedSpeaker setPositionX: [NSNumber numberWithFloat: newSpeakerPosition.x]];
		[_selectedSpeaker setPositionY: [NSNumber numberWithFloat: newSpeakerPosition.y]];
		[_selectedSpeaker setPositionZ: [NSNumber numberWithFloat: newSpeakerPosition.z]];
	}
}

#pragma mark -
#pragma mark Camera
#pragma mark -

- (void)resetRotation { [self setXRotation:0.f]; [self setYRotation:0.f]; }
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
- (float)xRotation { return [_cameraAdjustment xRotation]; }
- (float)yRotation { return [_cameraAdjustment yRotation]; }
- (void)setXRotation:(float)xRotation { [_cameraAdjustment setXRotation:xRotation]; }
- (void)setYRotation:(float)yRotation { [_cameraAdjustment setYRotation:yRotation]; }

- (void)setViewRotation
{
		// by default, we are looking down from the top on a left-handed
		// coord system. Rotate so that x faces the "front" (top of the screen)
	glRotatef(90.0f, 0.0f, 0.0f, 1.0f);
	glRotatef([_cameraAdjustment xRotation], 1.0f, 0.0f, 0.0f);
	glRotatef([_cameraAdjustment yRotation], 0.0f, 1.0f, 0.0f);
}

#pragma mark -
#pragma mark Rendering 
#pragma mark -

- (void)drawDisplay
{
	[self resetDrawingState];
	
	[self drawReferenceObjects];
	
	if(_dragSpeaker)
		[self dragSpeaker]; 
	
	[self drawSpeakerMesh];
	[self drawSpeakers];
}

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

- (void)drawReferenceObjects 
{
	BOOL show = [[[NSUserDefaults standardUserDefaults] valueForKey:@"showCoordinateSystem"] boolValue]; 
	if(show) {
	
		// draw the axes
		glBegin(GL_LINES);
		// x-axis
		glColor3f(1.0f, 0.0f, 0.0f);
		glVertex3f(0.0f, 0.0f, 0.0f);
		glVertex3f(0.25f, 0.0f, 0.0f);
		
		// y-axis			
		glColor3f(0.0f, 1.0f, 0.0f);			
		glVertex3f(0.0f, 0.0f, 0.0f);
		glVertex3f(0.0f, 0.25f, 0.0f);			
		
		// z-axis			
		glColor3f(0.0f, 0.0f, 1.0f);			
		glVertex3f(0.0f, 0.0f, 0.0f);
		glVertex3f(0.0f, 0.0f, 0.25f);
		glEnd();
		
	}
}

- (void)drawSpeakerMesh
{
	/*
	NSArray* speakerMesh;
	if([self viewType] != kDomeView2DMappingType) {
		if (!(speakerMesh = [_panner speakerMesh])) return;
	} else {
		if(!(speakerMesh = [[self previewPanner] speakerMesh])) return; 
	}
	*/
	
	BOOL show = [[[NSUserDefaults standardUserDefaults] valueForKey:@"showSpeakerMesh"] boolValue]; 
	
	if(show) {
		
		//FILLED MESH ...
		
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		glEnable(GL_BLEND);	// Turn Blending On
		glDisable(GL_DEPTH_TEST);	// Turn Depth Testing Off
		
		
		glLineWidth(1.0f);
		glColor4f(0.2f, 0.2f, 0.2f, 0.1f);
		
		ZKMNRSpeakerMeshElement* aMeshElement;
		for(aMeshElement in [[self previewPanner] speakerMesh]) {
			unsigned count = [aMeshElement numberOfSpeakers];
			
			//draw
			glBegin(GL_TRIANGLES);	
			ZKMNRSpeakerPosition* pos;
			for(pos in [aMeshElement speakers]) {
				ZKMNRRectangularCoordinate speakerPositionRect;
				speakerPositionRect = (self.isPositionIdeal) ? ZKMNRSphericalCoordinateToRectangular([pos coordPlatonic]) : [pos coordRectangular];
				float x = speakerPositionRect.x, y = speakerPositionRect.y, z = speakerPositionRect.z;
				glVertex3f(x, y, z);
			}
			if(count<3) {
				glVertex3f(0.f, 0.f, 0.f);
			}
			glEnd();
			
		}
		
		glDisable(GL_BLEND);	// Turn Blending Off
		glEnable(GL_DEPTH_TEST);	// Turn Depth Testing On
	
		// OUTLINES ...
		
		NSArray* speakerMesh = [[self previewPanner] speakerMesh];
		// draw the mesh
		glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
		glEnable(GL_LINE_SMOOTH);
		glLineWidth(0.5f);
		glColor4f(0.3f, 0.3f, 0.3f, 1.f);
		ZKMNRSpeakerMeshElement* meshElement;
		for(meshElement in speakerMesh) {
			unsigned count = [meshElement numberOfSpeakers];
			NSEnumerator* speakers = [[meshElement speakers] objectEnumerator];
			ZKMNRSpeakerPosition* pos;
			glBegin(GL_TRIANGLES);	
			while (pos = [speakers nextObject]) {
				ZKMNRRectangularCoordinate speakerPositionRect;
				speakerPositionRect = (self.isPositionIdeal) ? ZKMNRSphericalCoordinateToRectangular([pos coordPlatonic]) : [pos coordRectangular];
				float x = speakerPositionRect.x, y = speakerPositionRect.y, z = speakerPositionRect.z;
				glVertex3f(x, y, z);		
			}
			if (count < 3) glVertex3f(0.f, 0.f, 0.f);
			glEnd();
		}
		glLineWidth(1.f);
		glDisable(GL_LINE_SMOOTH);
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);	
		
		glEnable(GL_BLEND);					// Enable blending

	}
	

}

- (void)drawSpeakers
{
	if (!_speakerLayout) { return; }
	
	currentSpeakerPositions = [_speakerLayout speakerPositions];
	currentSpeakersPerRing  = [_speakerLayout numberOfSpeakersPerRing];
	currentSpeakerIndex = 0;
	unsigned j, numRings = [_speakerLayout numberOfRings];
	
	glEnable(GL_TEXTURE_2D);
		for (j = 0; j < numRings; j++) [self drawSpeakersRing: j];
	glDisable(GL_TEXTURE_2D);
}

- (void)drawSpeakersRing:(unsigned)ring
{
	ZKMNRRectangularCoordinate speakerPositionRect;
	ZKMNRSphericalCoordinate speakerPositionSph;
	unsigned i, numSpeakersInRing = [[currentSpeakersPerRing objectAtIndex: ring] unsignedIntValue];
		
	_isCurrentSelectedRing = (ring==_selectedRing) ? YES : NO; 
		
	for(i = 0; i < numSpeakersInRing; currentSpeakerIndex++, i++) {	
		ZKMNRSpeakerPosition* speakerPosition = [currentSpeakerPositions objectAtIndex: currentSpeakerIndex];
		speakerPositionSph = [speakerPosition coordPhysical];
		speakerPositionRect = 
			(self.isPositionIdeal) ?
				ZKMNRSphericalCoordinateToRectangular([speakerPosition coordPlatonic]) : 
				[speakerPosition coordRectangular];
		float x = speakerPositionRect.x, y = speakerPositionRect.y, z = speakerPositionRect.z;
		
		id aSpeakerPosition;
		for(aSpeakerPosition in _selectedSpeakerPositions) {
			ZKMNRRectangularCoordinate coord; 
			coord.x	= [[aSpeakerPosition valueForKey:@"positionX"] floatValue];
			coord.y	= [[aSpeakerPosition valueForKey:@"positionY"] floatValue];
			coord.z	= [[aSpeakerPosition valueForKey:@"positionZ"] floatValue];

			if(speakerPositionRect.x == coord.x && speakerPositionRect.y == coord.y && speakerPositionRect.z == coord.z) {
				_isCurrentSelectedSpeaker = YES;
			} else {
				_isCurrentSelectedSpeaker = NO; 
			}	
		}
		
		// Draw Speaker Direction Vector ...
		[self drawSpeakerDirectionOfLength:.2f x:x y:y z:z];			
				
		glPushName(currentSpeakerIndex);
		glPushMatrix();
			glTranslatef(x, y, z);
				// undo the -90 deg rotation of the coordinate space
			glRotatef(90.f, 0.f, 0.f, 1.f);
				// rotate the speaker toward the center - azimuth
			glRotatef(speakerPositionSph.azimuth * 180.f, 0.f, 0.f, 1.f);
				// rotate the speaker toward the center - zenith
			if (self.isRotateZenith) 
				glRotatef(speakerPositionSph.zenith * -180.f, 1.f, 0.f, 0.f);
		
			glScalef(0.2f, 0.2f, 0.3f);
			[self drawSpeaker: currentSpeakerIndex ringPosition: i ringTotal: numSpeakersInRing];
		glPopMatrix();
		
		
		BOOL showSpeakerNumbers = [[[NSUserDefaults standardUserDefaults] valueForKey:@"showSpeakersNumbering"] boolValue]; 
		
		//Draw Speaker Number
		if(showSpeakerNumbers)
		{
			GLint viewport[4];
			GLdouble modelview[16];
			GLdouble projection[16];
			GLdouble win[] = {0, 0, 0};
			//GLdouble pos[] = { x, y, z };
			glGetDoublev(GL_MODELVIEW_MATRIX, modelview);
			glGetDoublev(GL_PROJECTION_MATRIX, projection);
			glGetIntegerv(GL_VIEWPORT, viewport);
			
			gluProject(x, y, z, modelview, projection, viewport, &win[0], &win[1], &win[2]);
		
			if(self.isPositionIdeal)
				[self drawSpeakerNumberAtX:x y:y z:z+0.06];
			else 
				[self drawSpeakerNumberAtX:x y:y z:z+0.1];
		}
						
		glPopName();
		
		
	}
}

- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal
{
	glColor3f(0.0f, 0.7f, 0.0f);
	glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
	[_cube drawCube];
}

- (void)drawSpeakerDirectionOfLength:(float)l x:(float)x y:(float)y z:(float)z
{
	//implemented in SpeakerSetupView ...
}

- (void)drawSpeakerNumberAtX:(float)x y:(float)y z:(float)z
{
	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	NSString* numberString = @"";
	
	if(self.viewType==kDomeViewSpeakerEditorType || self.viewType==kDomeViewSphereMappingType) {
		numberString = [numberString stringByAppendingFormat:@"%d", currentSpeakerIndex+1];
	} else {
		
		int mode = [[[NSUserDefaults standardUserDefaults] valueForKey:@"speakersNumberingMode"] intValue]; 
		
		if(0==mode || 2==mode)
			numberString = [numberString stringByAppendingFormat:@"%d", currentSpeakerIndex+1];
		if(2==mode)
			numberString = [numberString stringByAppendingString:@"/"];
		if(1==mode || 2==mode)
		{
			NSArray* channelMap = [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] deviceOutput] channelMap];
			
			int channelN = 0;
			if(1!=(int)[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] loudspeakerMode])
			{
				NSNumber* channelNumber; 
				for(channelNumber in channelMap) {
					if([channelNumber intValue] == currentSpeakerIndex)
						break; 
					channelN ++; 
				}
			}
			numberString = (channelN==[channelMap count]) ? [numberString stringByAppendingFormat:@"-"] : [numberString stringByAppendingFormat:@"%d", channelN+1];
		}
		
	}
	
	[_glString renderBitmapString:numberString x:x y:y z:z];		
	
}

#pragma mark -
#pragma mark Undo Notification
#pragma mark -

- (void)undoManagerChangeNotification:(NSNotification *)notification
{
	[self setNeedsDisplay: YES];
}

#pragma mark -
#pragma mark Preferences Notfication
#pragma mark -

-(void)viewPreferenceChanged:(NSNotification*)inNotification
{
	[self setNeedsDisplay:YES];
}

@end




