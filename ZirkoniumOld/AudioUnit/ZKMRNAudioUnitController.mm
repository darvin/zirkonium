//
//  ZKMRNAudioUnitController.mm
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 09.03.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNAudioUnitController.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNZirk2Protocol.h"

struct Zirk2ServerDelegate : public Zirk2PortServer::ServerPortDelegate
{
	Zirk2ServerDelegate(ZKMRNAudioUnitController* controller) : Zirk2PortServer::ServerPortDelegate(), mController(controller) { }
	
	virtual void	ReceivedConnect() { }
	virtual void	ReceivedPan(UInt32 channel, Float32 azimuth, Float32 zenith, Float32 azimuthSpan, Float32 zenithSpan, Float32 gain)
	{
		ZKMNRSphericalCoordinate center;
		ZKMNRSphericalCoordinateSpan span;
		center.radius = 1.f; center.azimuth = azimuth; center.zenith = zenith;
		span.azimuthSpan = azimuthSpan; span.zenithSpan = zenithSpan;
		[mController->_zirkoniumSystem panChannel: channel az: center span: span gain: gain];
	}
	
	virtual void	ReceivedDisconnect() { };
	

	ZKMRNAudioUnitController *	mController;	
};


@implementation ZKMRNAudioUnitController
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (mServer) delete mServer, mServer = NULL;
	if (mDelegate) delete mDelegate, mDelegate = NULL;
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_zirkoniumSystem = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];

	mServer = new Zirk2PortServer;
	mDelegate = new Zirk2ServerDelegate(self);
	mServer->SetDelegate(mDelegate);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), mServer->GetRunLoopSource(), kCFRunLoopCommonModes);
	
	return self;
}


@end
