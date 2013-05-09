//
//  ZKMRNDomeViewCameraAdjustment.m
//  Zirkonium
//
//  Created by Jens on 24.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNDomeViewCameraAdjustment.h"

/* 
	Implemented as a Singleton since all DomeView share this ...
*/

@implementation ZKMRNDomeViewCameraAdjustment

static ZKMRNDomeViewCameraAdjustment *sharedDomeViewCameraAdjustmentManager = nil;

+ (ZKMRNDomeViewCameraAdjustment*)sharedManager
{
    @synchronized(self) {
        if (sharedDomeViewCameraAdjustmentManager == nil) {
            [[self alloc] init];
        }
    }
    return sharedDomeViewCameraAdjustmentManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedDomeViewCameraAdjustmentManager == nil) {
            return [super allocWithZone:zone];
        }
    }
    return sharedDomeViewCameraAdjustmentManager;
}

- (id)init
{
    Class myClass = [self class];
    @synchronized(myClass) {
        if (sharedDomeViewCameraAdjustmentManager == nil) {
            if (self = [super init]) {
                sharedDomeViewCameraAdjustmentManager = self;
                // custom initialization here
				_xRotation = 0.f; 
				_yRotation = 0.f; 
            }
        }
    }
    return sharedDomeViewCameraAdjustmentManager;
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (unsigned)retainCount { return UINT_MAX; }

- (void)release {}

- (id)autorelease { return self; }

#pragma mark -

-(float)xRotation { return _xRotation; }
-(float)yRotation { return _yRotation; }
-(void)setXRotation:(float)xRot { _xRotation = MAX(0.0, MIN(360.0, xRot)); [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];}
-(void)setYRotation:(float)yRot { _yRotation = MAX(0.0, MIN(90.0, yRot));  [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewPreferenceChanged" object:nil];}

@end
