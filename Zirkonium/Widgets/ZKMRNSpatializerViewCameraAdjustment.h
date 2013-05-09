//
//  ZKMRNSpatializerViewCameraAdjustment.h
//  Zirkonium
//
//  Created by Jens on 08.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRNSpatializerViewCameraAdjustment : NSObject {
	float _xRotation;
	float _yRotation;
}
-(float)xRotation;
-(float)yRotation;
-(void)setXRotation:(float)xRot;
-(void)setYRotation:(float)yRot; 

@end
