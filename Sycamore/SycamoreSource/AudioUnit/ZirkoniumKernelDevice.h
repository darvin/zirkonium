//
//  ZirkoniumKernelEngine.h
//  SimpleDeviceTest
//
//  Created by Jens on 27.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import "AudioRingBuffer.h"
#import "ZKMORDeviceOutput.h"
#import "ZirkoniumKernelDeviceInput.h"
#import "ZKMORConduit.h"

#ifndef __ZIRKONIUM_KERNEL_DEVICE_H__
#define __ZIRKONIUM_KERNEL_DEVICE_H__

@interface ZirkoniumKernelDevice : ZKMORDeviceOutput {
	ZirkoniumKernelDeviceInput* _kernelInput; 
}
-(void)stopDeviceRunning;
-(void)startDeviceRunning;

@end

typedef struct { @defs(ZirkoniumKernelDevice) } ZirkoniumDeviceStruct;

#endif