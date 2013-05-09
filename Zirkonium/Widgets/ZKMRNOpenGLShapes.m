//
//  ZKMRNOpenGLShapes.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOpenGLShapes.h"


@implementation ZKMRNOpenGLCube

- (void)drawCube
{
	glBegin(GL_QUADS);
		// Front Face
		glTexCoord2f(0.0f, 0.0f); glVertex3f(-0.5f, -0.5f,  0.5f);	// Bottom Left Of The Texture and Quad
		glTexCoord2f(1.0f, 0.0f); glVertex3f( 0.5f, -0.5f,  0.5f);	// Bottom Right Of The Texture and Quad
		glTexCoord2f(1.0f, 1.0f); glVertex3f( 0.5f,  0.5f,  0.5f);	// Top Right Of The Texture and Quad
		glTexCoord2f(0.0f, 1.0f); glVertex3f(-0.5f,  0.5f,  0.5f);	// Top Left Of The Texture and Quad
		// Back Face
		glTexCoord2f(1.0f, 0.0f); glVertex3f(-0.5f, -0.5f, -0.5f);	// Bottom Right Of The Texture and Quad
		glTexCoord2f(1.0f, 1.0f); glVertex3f(-0.5f,  0.5f, -0.5f);	// Top Right Of The Texture and Quad
		glTexCoord2f(0.0f, 1.0f); glVertex3f( 0.5f,  0.5f, -0.5f);	// Top Left Of The Texture and Quad
		glTexCoord2f(0.0f, 0.0f); glVertex3f( 0.5f, -0.5f, -0.5f);	// Bottom Left Of The Texture and Quad
		// Top Face
		glTexCoord2f(0.0f, 1.0f); glVertex3f(-0.5f,  0.5f, -0.5f);	// Top Left Of The Texture and Quad
		glTexCoord2f(0.0f, 0.0f); glVertex3f(-0.5f,  0.5f,  0.5f);	// Bottom Left Of The Texture and Quad
		glTexCoord2f(1.0f, 0.0f); glVertex3f( 0.5f,  0.5f,  0.5f);	// Bottom Right Of The Texture and Quad
		glTexCoord2f(1.0f, 1.0f); glVertex3f( 0.5f,  0.5f, -0.5f);	// Top Right Of The Texture and Quad
		// Bottom Face
		glTexCoord2f(1.0f, 1.0f); glVertex3f(-0.5f, -0.5f, -0.5f);	// Top Right Of The Texture and Quad
		glTexCoord2f(0.0f, 1.0f); glVertex3f( 0.5f, -0.5f, -0.5f);	// Top Left Of The Texture and Quad
		glTexCoord2f(0.0f, 0.0f); glVertex3f( 0.5f, -0.5f,  0.5f);	// Bottom Left Of The Texture and Quad
		glTexCoord2f(1.0f, 0.0f); glVertex3f(-0.5f, -0.5f,  0.5f);	// Bottom Right Of The Texture and Quad
		// Right face
		glTexCoord2f(1.0f, 0.0f); glVertex3f( 0.5f, -0.5f, -0.5f);	// Bottom Right Of The Texture and Quad
		glTexCoord2f(1.0f, 1.0f); glVertex3f( 0.5f,  0.5f, -0.5f);	// Top Right Of The Texture and Quad
		glTexCoord2f(0.0f, 1.0f); glVertex3f( 0.5f,  0.5f,  0.5f);	// Top Left Of The Texture and Quad
		glTexCoord2f(0.0f, 0.0f); glVertex3f( 0.5f, -0.5f,  0.5f);	// Bottom Left Of The Texture and Quad
		// Left Face
		glTexCoord2f(0.0f, 0.0f); glVertex3f(-0.5f, -0.5f, -0.5f);	// Bottom Left Of The Texture and Quad
		glTexCoord2f(1.0f, 0.0f); glVertex3f(-0.5f, -0.5f,  0.5f);	// Bottom Right Of The Texture and Quad
		glTexCoord2f(1.0f, 1.0f); glVertex3f(-0.5f,  0.5f,  0.5f);	// Top Right Of The Texture and Quad
		glTexCoord2f(0.0f, 1.0f); glVertex3f(-0.5f,  0.5f, -0.5f);	// Top Left Of The Texture and Quad
	glEnd();
}

- (void)drawSquare
{
	glBegin(GL_TRIANGLE_STRIP);	
		glTexCoord2f(1.f, 1.f);
		glVertex3f(0.5f, 0.5f, 0.f);	// Top right
		glTexCoord2f(0.f, 1.f);
		glVertex3f(-0.5f, 0.5f, 0.f);   // Top left
		glTexCoord2f(1.f, 0.f);
		glVertex3f(0.5f, -0.5f, 0.f);   // Bottom right
		glTexCoord2f(0.f, 0.f);
		glVertex3f(-0.5f, -0.5f, 0.f);	// Bottom left
	glEnd();
	
				// for non-power of two textures
	//			glEnable(GL_TEXTURE_RECTANGLE_EXT);
	//			glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [_speakerTexture textureID]);
	//			NSRect textureFrame = [_speakerTexture frame];
	//			glBegin(GL_TRIANGLE_STRIP);	
	//				glTexCoord2f(textureFrame.size.width, textureFrame.size.height);
	//				glVertex3f(0.5f, 0.5f, 1.f);   // Top right
	//				glTexCoord2f(0.f, textureFrame.size.height);				
	//				glVertex3f(-0.5f, 0.5f, 1.f);   // Top left
	//				glTexCoord2f(textureFrame.size.width, 0.f);
	//				glVertex3f(0.5f, -0.5f, 1.f);   // Bottom right
	//				glTexCoord2f(0.f, 0.f);				
	//				glVertex3f(-0.5f, -0.5f, 1.f);   // Bottom left
	//			glEnd();
}

@end


///////////
// CIRCLE SHAPE as DisplayList
//////////

#pragma mark -- Circle
@interface ZKMRNOpenGLCircle (Private)
- (void)generateDisplayList;
@end

@implementation ZKMRNOpenGLCircle
-(id)init
{
	self = [super init];
	if(self) {
		_segments = 360;
		_radius =   1.0;
		[self generateDisplayList];
		
	}
	
	return self;
}

- (id)initWithSegments:(int)segments andRadius:(float)radius;
{
	self = [super init];
	if(self)
	{
		_segments = segments;
		_radius   = radius; 
		[self generateDisplayList];		
	}
	
	return self;
}

- (void)drawCircle
{
	if(0!=_displayList)
		glCallList(_displayList);
}

@end

#pragma mark --Private Methods
@implementation ZKMRNOpenGLCircle (Private)
-(void)generateDisplayList
{
	if(0!=_displayList)
		glDeleteLists(_displayList, 1);
		
	//create display list
	_displayList = glGenLists(1);
		
	//draw in list
	glNewList(_displayList, GL_COMPILE);
		
	//the circle points ...
	glBegin(GL_LINE_LOOP);
	int i;
	for (i=0; i<_segments; i++)
	{
		float s = (360.0f / _segments) * i; //division save!
		float degInRad = s*DEG2RAD;
		glVertex2f(cos(degInRad)*_radius, sin(degInRad)*_radius);
	}
	glEnd();
	
	glEndList();
}
@end


#pragma mark --OpenGL Stings
@implementation ZKMRNOpenGLString
- (void) renderBitmapString:(NSString*)string x:(float) x y:(float) y 
{  
	char *c;
	glRasterPos2f(x, y);
 
	if(nil!=string)
	{
		char* cString =  (char*)[string UTF8String];
		for (c=cString; *c != '\0'; c++) {
			glutBitmapCharacter(GLUT_BITMAP_HELVETICA_10, *c);
		}
	}
}

- (void) renderBitmapString:(NSString*)string x:(float) x y:(float) y z:(float)z
{  
	char *c;
	glRasterPos3f(x, y, z);
 
	if(nil!=string)
	{
		char* cString =  (char*)[string UTF8String];
		for (c=cString; *c != '\0'; c++) {
			glutBitmapCharacter(GLUT_BITMAP_HELVETICA_10, *c);
		}
	}
}
@end

