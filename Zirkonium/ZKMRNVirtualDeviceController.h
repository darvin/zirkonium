//
//  ZKMRNVirtualDeviceController.h
//  Zirkonium
//
//  Created by Jens on 22.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

@interface ZKMRNVirtualDeviceController : NSObject {
	
	ZKMORDeviceOutput*		_virtualDeviceOutput;
	ZKMORGraph*				_virtualGraph;
	ZKMORMixerMatrix*		_virtualMixer;

	BOOL _isInitialized; 
	BOOL _isRunning; 
}

-(ZKMORGraph*)graph; 
-(ZKMORDeviceInput*)deviceInput; 

-(void)initialize; 
-(void)startDevice;
-(void)stopDevice;



@end
