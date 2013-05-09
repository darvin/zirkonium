//
//  ZKMRNSpeakerSetupView.m
//  Zirkonium
//
//  Created by Jens on 02.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNSpeakerSetupView.h"

@implementation ZKMRNSpeakerSetupView

#pragma mark -

@synthesize editingAllowed;
@synthesize editMode; 
 
#pragma mark -
#pragma mark Initialize 
#pragma mark -

-(void)awakeFromNib
{
	[super awakeFromNib];
	self.editingAllowed = NO;
	self.editMode = NO; 
	_selectedRings = nil;
}

- (void)prepareOpenGL
{
	[super prepareOpenGL];
	_speakerTexture = [[ZKMRNSpeakerCubeTexture alloc] init];
}

#pragma mark -
#pragma mark Rendering 
#pragma mark -

- (void)drawSpeakersRing:(unsigned)ring
{
	if (_selectedRings && ([_selectedRings count] > 0)) {
		_speakerAlpha = [_selectedRings containsIndex: ring] ? 1.f : 0.9f;
	} else 
		_speakerAlpha = 0.9f;
	[super drawSpeakersRing: ring];
}


- (void)drawSpeaker:(unsigned)speakerNum ringPosition:(unsigned)ringNum ringTotal:(unsigned)ringTotal
{
	// where Speakers drawing takes place ...
	float redFactor = (float) ringNum / (float) ringTotal;
	glColor3f(redFactor * _speakerAlpha, 0.3f * _speakerAlpha, (1.0f - redFactor) * _speakerAlpha);
	glBindTexture(GL_TEXTURE_2D, [_speakerTexture textureID]);
	
	if(!self.isPositionIdeal) {
		glScalef(0.4f, 0.4f, 0.4f);
	} else {
		glScalef(0.2f, 0.2f, 0.2f);
	}
	
	[_cube drawCube];
	
	// Highlighting ...

	if(_isCurrentSelectedSpeaker) {
		glColor3f(0.0f, 1.0f, 0.0f);
		
		glScalef(1.1f, 1.1f, 1.1f);	
		glutWireCube(1.0); 
	}	
	
	else if(_isCurrentSelectedRing && !self.isPositionIdeal) {
		// selectedSpeakerRing ...	
		glColor3f(1.f, 1.f, 1.f);
		
		glScalef(1.1f, 1.1f, 1.1f);	
		glutWireCube(1.0); 
	}
}

- (void)drawSpeakerDirectionOfLength:(float)l x:(float)x y:(float)y z:(float)z
{
	float length = 1.0 - l; //TODO:
 	glColor3f(1.0f, 1.0f, 1.0f);
	glPushMatrix();
	glBegin(GL_LINES);
	glVertex3f(x*length, y*length, z*length);
	glVertex3f(x, y, z);
	glEnd();
	glPopMatrix();
}

#pragma mark -
#pragma mark Selected Rings
#pragma mark -

- (NSIndexSet *)selectedRings { return _selectedRings; }
- (void)setSelectedRings:(NSIndexSet *)selectedRings 
{
	if (_selectedRings) [_selectedRings release];
	_selectedRings = selectedRings;
	if (_selectedRings) [_selectedRings retain];
	[self setNeedsDisplay: YES];
}

#pragma mark -
#pragma mark Mouse
#pragma mark -

- (void)mouseDragged:(NSEvent *)theEvent
{
	_mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];

	if (_useTrackball) {
		[self setXRotation:([_cameraAdjustment xRotation] + [theEvent deltaX])];
		[self setYRotation:([_cameraAdjustment yRotation] - [theEvent deltaY])];
		return;
	}
	
	if(_dragSpeaker)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	_useTrackball = NO;
	_dragSpeaker = NO;
	_initiatedDragSpeaker = NO; 
	
	if(self.editMode) {
		if(self.editingAllowed && _selectedSpeaker) 
			[_selectedSpeaker stopManipulating]; //for undo ...
	} 
}


- (void)mouseDown:(NSEvent *)theEvent
{	
	ZKMNRSpeakerPosition* selectedPos = nil;
	[self activateOpenGLContext];
	
	if(self.editingAllowed) {
		[self beginHitTesting: theEvent];
		[self drawSpeakers];
		ZKMRNHitRecords hitRecords = [self endHitTesting];
	
		// process hit records
		GLuint i, numberOfNames = hitRecords.numberOfNames;
		GLuint* names = hitRecords.names;
	
		for (i = 0; i < numberOfNames; i++) 
			selectedPos = [[_speakerLayout speakerPositions] objectAtIndex: names[i]];
	}	
		
	if (!selectedPos) {
		_useTrackball = YES;
		[self restoreOpenGLContext];
		return;
	} 
	
	// notify delegate
	if (self.delegate && [(NSObject*)self.delegate respondsToSelector:@selector(view:selectedSpeakerPosition:)]) { 
		[self.delegate view: self selectedSpeakerPosition: selectedPos];
	}
	
	
	_mouseLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	
	_selectedSpeaker = [selectedPos tag];
	
	if(_selectedSpeaker) { 
		
		// bug fix: tableView updates before controller in run loop ...
		[self setSelectedSpeakerPositions:[NSArray arrayWithObject:_selectedSpeaker]];
		
		if(self.editMode) {
			_startSpeakerPosition = [selectedPos coordRectangular];
			_initiatedDragSpeaker = YES; 
			_dragSpeaker = YES;
			[_selectedSpeaker startManipulating]; //for undo ...
		}
	}
			
	[self restoreOpenGLContext];
	[self drawDisplay]; 
}


- (void)scrollWheel:(NSEvent *)theEvent
{
	[self setXRotation:([_cameraAdjustment xRotation] + [theEvent deltaX])];
	[self setYRotation:([_cameraAdjustment yRotation] + [theEvent deltaY])];	
	[self drawDisplay];
}

@end

