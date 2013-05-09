//
//  ZKMRNOpenGLShapes.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import <glut/glut.h>

#define DEG2RAD (3.14159/180.0)

///
///  ZKMRNOpenGLCube
///
///  Vertex and Texture definitions for cubes and squares.
///
@interface ZKMRNOpenGLCube : NSObject {

}

- (void)drawCube;
- (void)drawSquare;
@end

@interface ZKMRNOpenGLCircle : NSObject {
	float _radius;
	int   _segments;
	GLuint _displayList;
}
- (id)initWithSegments:(int)segments andRadius:(float)radius;
- (void)drawCircle;
@end

@interface ZKMRNOpenGLString : NSObject {
}
- (void) renderBitmapString:(NSString*)string x:(float) x y:(float) y;
- (void) renderBitmapString:(NSString*)string x:(float) x y:(float) y z:(float)z;

@end

