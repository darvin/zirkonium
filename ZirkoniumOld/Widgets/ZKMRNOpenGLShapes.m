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
