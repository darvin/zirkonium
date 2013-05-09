//
//  ZKMRNAudioUnitController.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 09.03.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

ZKMDECLCPPT(Zirk2PortServer)
ZKMDECLCPPT(Zirk2ServerDelegate)

@class ZKMRNZirkoniumSystem;
@interface ZKMRNAudioUnitController : NSObject {
	ZKMCPPT(Zirk2PortServer)		mServer;
	ZKMCPPT(Zirk2ServerDelegate)	mDelegate;
	
@public
	ZKMRNZirkoniumSystem*			_zirkoniumSystem;
}

@end
