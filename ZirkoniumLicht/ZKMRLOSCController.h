//
//  ZKMRLOSCController.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 23.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import <VVOSC/VVOSC.h>

//ZKMDECLCPPT(ZKMRLOSCListener)


@class ZKMRLZirkoniumLightSystem;
@interface ZKMRLOSCController : NSObject {
	
	OSCManager*		_oscManager; 
	OSCInPort*		_inPort; 

	
	/*
	ZKMCPPT(ZKMRLOSCListener)	mOSCListener;

	CFSocketRef					_socket;
	CFRunLoopSourceRef			_runLoopSource;
	*/
@public
	ZKMRLZirkoniumLightSystem*	_system;
}

-(void)destroyOSC;
-(void)createOSC; 

@end
