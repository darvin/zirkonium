//
//  ZKMRNSpatializerViewCameraAdjustment.m
//  Zirkonium
//
//  Created by Jens on 08.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNSpatializerViewCameraAdjustment.h"


@implementation ZKMRNSpatializerViewCameraAdjustment

-(id)init
{
	if(self = [super init]) {
		_xRotation = 0.f; 
		_yRotation = 0.f; 
	}
	return self; 
}

-(float)xRotation { return _xRotation; }
-(float)yRotation { return _yRotation; }
-(void)setXRotation:(float)xRot { _xRotation = MAX(0.0, MIN(360.0, xRot));  [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];}
-(void)setYRotation:(float)yRot { _yRotation = MAX(0.0, MIN(90.0,  yRot));  [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];}

@end
