//
//  ZKMRNDomeViewCameraAdjustment.h
//  Zirkonium
//
//  Created by Jens on 24.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRNDomeViewCameraAdjustment : NSObject {
	float _xRotation;
	float _yRotation; 
}
+ (ZKMRNDomeViewCameraAdjustment*)sharedManager;

-(float)xRotation;
-(float)yRotation;
-(void)setXRotation:(float)xRot;
-(void)setYRotation:(float)yRot; 

@end
