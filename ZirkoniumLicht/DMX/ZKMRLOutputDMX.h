//
//  ZKMRLOutputDMX.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 16.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LanBox.h"


@class ZKMRLMixerLight;
/// 
///  ZKMRLOutputDMX
///
///  The Output DMX sends the state of a MixerLight via UDP to a LanBox.
///
///  To verify, try
///
///		sudo tcpdump -i en1 -s 128 -x port 4777
///
///
@interface ZKMRLOutputDMX : NSObject {
	ZKMRLMixerLight*	_mixer;
	unsigned			_numberOfLamps;
	unsigned			_numberOfChannels;	
	
	NSString*			_address;
	BOOL				_isBroadcastOn;
	NSArray*			_lampOrder;
	
	int					_fd;
	char				_buf[LCUDP_BUFSZ];
	int					_tcpFd;
	CFSocketRef			_adminSocket;
	CFRunLoopSourceRef	_adminSocketRunLoopSource;
}

//  Accessors
- (NSString *)address;
- (void)setAddress:(NSString *)address;
- (NSString *)defaultLanBoxAddress;

- (ZKMRLMixerLight *)mixer;
- (void)setMixer:(ZKMRLMixerLight *)mixer;

//  Actions
	/// Sends the current state of the mixer to the LanBox
- (void)tick:(id)sender;

@end
