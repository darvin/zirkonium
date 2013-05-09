//
//  ZKMRNOSCController.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 05.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
ZKMDECLCPPT(ZKMRNOSCListener)

@class ZKMRNZirkoniumSystem;
@interface ZKMRNOSCController : NSObject {
	ZKMCPPT(ZKMRNOSCListener)	mOSCListener;

	CFSocketRef					_socket;
	CFRunLoopSourceRef			_runLoopSource;
	ZKMRNZirkoniumSystem*		_zirkoniumSystem;
}

@end
