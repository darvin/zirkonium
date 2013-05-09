//
//  ZKMRLOutputDMX.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 16.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLOutputDMX.h"
#import "ZKMRLMixerLight.h"

inline float ZKMRLWarpColorValue(float colorValue) { return powf(colorValue, 4); }
//inline float ZKMRLWarpColorValue(float colorValue) { return sqrtf(colorValue); }
//inline float ZKMRLWarpColorValue(float colorValue) { return colorValue; }

static void ZKMRLAdminSocketCallback(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
	// TODO -- Verify that the response is ">" and not "?"
		// convert data to a const char* and int size;
//	const char* bytes = (const char*) CFDataGetBytePtr((CFDataRef) data);
//	int bytesSize = CFDataGetLength(data);
//	NSLog(@"LanBox sez: %s", bytes);
}

@interface ZKMRLOutputDMX (ZKMRLOutputDMXPrivate)
- (void)createAdminSocket;
- (void)sendPassword;
@end


@implementation ZKMRLOutputDMX

- (void)dealloc
{
	if (_fd >= 0) close(_fd);
	if (_adminSocket) CFRelease(_adminSocket);
	if (_adminSocketRunLoopSource) CFRelease(_adminSocketRunLoopSource);
	if (_lampOrder) [_lampOrder release];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

- (void)initializeLampOrder
{
	NSMutableArray* lampOrder = [[NSMutableArray alloc] init];
	// 0 doesn't have a light -- this is communicated by a negative number
	[lampOrder addObject: [NSNumber numberWithInt: -1]];	
	// 2 - 14
	[lampOrder addObject: [NSNumber numberWithInt: 0]];
	[lampOrder addObject: [NSNumber numberWithInt: 1]];
	[lampOrder addObject: [NSNumber numberWithInt: 2]];
	[lampOrder addObject: [NSNumber numberWithInt: 12]];
	[lampOrder addObject: [NSNumber numberWithInt: 17]];
	[lampOrder addObject: [NSNumber numberWithInt: 14]];
	[lampOrder addObject: [NSNumber numberWithInt: 23]];
	[lampOrder addObject: [NSNumber numberWithInt: 15]];
	[lampOrder addObject: [NSNumber numberWithInt: 16]];
	[lampOrder addObject: [NSNumber numberWithInt: 30]];
	[lampOrder addObject: [NSNumber numberWithInt: 31]];
	[lampOrder addObject: [NSNumber numberWithInt: 36]];
	[lampOrder addObject: [NSNumber numberWithInt: 33]];

	// 15 - 28
	[lampOrder addObject: [NSNumber numberWithInt: 3]];
	[lampOrder addObject: [NSNumber numberWithInt: 4]];
	[lampOrder addObject: [NSNumber numberWithInt: 5]];
	[lampOrder addObject: [NSNumber numberWithInt: 6]];
	[lampOrder addObject: [NSNumber numberWithInt: 13]];
	[lampOrder addObject: [NSNumber numberWithInt: 18]];
	[lampOrder addObject: [NSNumber numberWithInt: 19]];
	[lampOrder addObject: [NSNumber numberWithInt: 20]];
	[lampOrder addObject: [NSNumber numberWithInt: 21]];
	[lampOrder addObject: [NSNumber numberWithInt: 24]];
	[lampOrder addObject: [NSNumber numberWithInt: 34]];
	[lampOrder addObject: [NSNumber numberWithInt: 35]];
	[lampOrder addObject: [NSNumber numberWithInt: 32]];
	[lampOrder addObject: [NSNumber numberWithInt: 37]];
	
	// 29 - 36
	[lampOrder addObject: [NSNumber numberWithInt: 38]];
	[lampOrder addObject: [NSNumber numberWithInt: 25]];
	[lampOrder addObject: [NSNumber numberWithInt: 26]];
	[lampOrder addObject: [NSNumber numberWithInt: 8]];
	[lampOrder addObject: [NSNumber numberWithInt: 39]];
	[lampOrder addObject: [NSNumber numberWithInt: 27]];
	[lampOrder addObject: [NSNumber numberWithInt: 28]];
	[lampOrder addObject: [NSNumber numberWithInt: 7]];
	
	// 37 - 42
	[lampOrder addObject: [NSNumber numberWithInt: 9]];
	[lampOrder addObject: [NSNumber numberWithInt: 10]];
	[lampOrder addObject: [NSNumber numberWithInt: 22]];
	[lampOrder addObject: [NSNumber numberWithInt: 29]];
	[lampOrder addObject: [NSNumber numberWithInt: 40]];
	[lampOrder addObject: [NSNumber numberWithInt: 41]];
	
	// 43
	[lampOrder addObject: [NSNumber numberWithInt: 11]];
	
	_lampOrder = lampOrder;
	_numberOfChannels = 42 * 3;
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (_fd < 0) { [self release]; return nil; }
	[self createAdminSocket];
	_isBroadcastOn = NO;

	[self initializeLampOrder];
		// setAddress is called by the system -- no need to call it myself
//	[self setAddress: @"192.168.1.77"];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(mixerSizeChanged:) name: ZKMRLMixerLightChangedSizeNotification object: nil];

	return self;
}

- (NSString *)address { return _address; }
- (void)setAddress:(NSString *)address
{
	if (_address) {
		[_address release];
		if (_fd >= 0) close(_fd), _fd = 0;
		if (_adminSocket) CFRelease(_adminSocket);
	}
	_address = address;
	if (_address) {
		[_address retain];
	} else {
		// set to default
		_address = @"192.168.1.77";	
	}

	const char* addrCString = [_address UTF8String];
	struct sockaddr_in addr;
	inet_aton(addrCString, &addr.sin_addr);
	
	// the lanbox runs on port 4777
	addr.sin_family = AF_INET;
	addr.sin_port = htons(4777);

	// TODO: switch to sendto -- then no need to use connect
	if (connect(_fd, (struct sockaddr *) &addr, sizeof addr) == -1) {
		NSLog(@"connect() UDP failed");
	}
	
	// the lanbox tcp runs on port 777
	addr.sin_port = htons(777);
	CFDataRef addressData = CFDataCreateWithBytesNoCopy(NULL,  (UInt8 *)&addr, sizeof(struct sockaddr_in), kCFAllocatorNull);
		// connect with a timeout of 1 second
	CFSocketError error = CFSocketConnectToAddress(_adminSocket, addressData, 1.0);
	if (kCFSocketSuccess != error) {
		if (kCFSocketError == error) {
			NSDictionary* userInfo = 
				[NSDictionary 
					dictionaryWithObjectsAndKeys: 
						@"Could not create admin connection to LanBox. You need to use LCEdit to send the password.", NSLocalizedDescriptionKey, 
						@"Could not create admin connection to LanBox. kCFSocketError.", NSLocalizedFailureReasonErrorKey, nil];
			NSError* errorObject = [NSError errorWithDomain: NSPOSIXErrorDomain  code: error userInfo: userInfo];
			[[NSApplication sharedApplication] presentError: errorObject];
		} else {
			NSDictionary* userInfo = 
			[NSDictionary 
				dictionaryWithObjectsAndKeys: 
					@"Could not find LanBox. Check network settings", NSLocalizedDescriptionKey, 
					@"Could not create admin connection to LanBox. kCFSocketTimeout.", NSLocalizedFailureReasonErrorKey, nil];
			NSError* errorObject = [NSError errorWithDomain: NSPOSIXErrorDomain  code: error userInfo: userInfo];
			[[NSApplication sharedApplication] presentError: errorObject];
		}
	}
	CFRelease(addressData);

	[self sendPassword];
}

- (NSString *)defaultLanBoxAddress { return @"192.168.1.77"; }

- (ZKMRLMixerLight *)mixer { return _mixer; }

- (void)setMixer:(ZKMRLMixerLight *)mixer
{
	if (_mixer) [_mixer release], _mixer = nil;
	_mixer = mixer;
	if (!mixer) return;
	[_mixer retain];
	_numberOfLamps = [_mixer numberOfOutputChannels];
		// number of channels is pre-computed	
		// * 3 for rgb
//	_numberOfChannels = _numberOfLamps * 3;
}

- (BOOL)isBroadcastOn { return _isBroadcastOn; }
- (void)setBroadcastOn:(BOOL)isBroadcastOn
{
	_isBroadcastOn = isBroadcastOn;
	setsockopt(_fd, SOL_SOCKET, SO_BROADCAST, &isBroadcastOn, sizeof(BOOL));
}

- (void)tick:(id)sender
{
		// nothing to do
	if ([_mixer isSynchedWithOutput]) return;
	
		// update the mixer
	[_mixer updateOutputColors];
	[_mixer setSynchedWithOutput: YES];
	
	// send the DMX
	struct iovec iov;
	uint8_t *dmx;

	// initialize new packet
	iov.iov_base = _buf;
	lcu_init(&iov);
		
	// add a "write channels 1-number of channels into layer A" message
	dmx = lcu_add_write(&iov, 1, _numberOfChannels, ID_LAYER_A);
	if (!dmx) {
		NSLog(@"lcu_add_write() failed");
		return;
	}

	// set all channels to value 0
	memset(dmx, 0, _numberOfChannels);

	// put the rgb values in the appropriate place (determined by the lamp order)
	unsigned i, count = _numberOfLamps;
	for (i = 0; i < count; ++i) 
	{
		unsigned lampIndex = [[_lampOrder objectAtIndex: i] intValue];
		if (lampIndex < 0 || lampIndex > _numberOfChannels) continue;
		
		NSColor* color = [_mixer colorForOutput: i];
		uint8_t *rPtr, *gPtr, *bPtr;
		rPtr = dmx + (lampIndex * 3); gPtr = rPtr + 1; bPtr = gPtr + 1;
		*rPtr = (uint8_t) (ZKMRLWarpColorValue([color redComponent]) * 255);
		*gPtr = (uint8_t) (ZKMRLWarpColorValue([color greenComponent]) * 255);
		*bPtr = (uint8_t) (ZKMRLWarpColorValue([color blueComponent]) * 255);
//		if ((*rPtr > 0) || (*gPtr > 0) || (*bPtr > 0)) NSLog(@"%u : %hhu %hhu %hhu", i, *rPtr, *gPtr, *bPtr);
	}
	
	// TODO: switch to sendto
	// transmit packet
	if (writev(_fd, &iov, 1) == -1) {
		NSLog(@"write() failed %u", errno);
		return;
	}
}

#pragma mark _____ Private
- (void)mixerSizeChanged:(NSNotification *)notification
{
	if ([notification object] != _mixer) return;

	_numberOfLamps = [_mixer numberOfOutputChannels];
		// number of channels is pre-computed
		// * 3 for rgb
//	_numberOfChannels = _numberOfLamps * 3;
}

#pragma mark _____ ZKMRLOutputDMXPrivate
- (void)createAdminSocket
{
	CFSocketContext socketContext;

	socketContext.version = 0;
	socketContext.info = (void *) self;
	socketContext.retain = NULL;
	socketContext.release = NULL;
	socketContext.copyDescription = NULL;

	_adminSocket = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketDataCallBack, ZKMRLAdminSocketCallback, &socketContext);
	if (!_adminSocket) {
		NSLog(@"Could not create admin socket");
		return;
	}
	
	_adminSocketRunLoopSource = CFSocketCreateRunLoopSource(NULL, _adminSocket, 0);
	if (!_adminSocketRunLoopSource) {
		NSLog(@"Could not create admin socket run loop source");
	}
	CFRunLoopAddSource(CFRunLoopGetCurrent(), _adminSocketRunLoopSource, kCFRunLoopCommonModes);
}

- (void)sendPassword
{
	// Lanbox connect: * 0xAF pass_high pass_low #
//	char passwdStr[255];
//	short passwd = htons((short) 777);
//	snprintf(passwdStr, sizeof(passwdStr), "*AF%hu", passwd);
	char* passwdString = "*AF0309#";
	int passwdLen = strlen(passwdString);
	CFDataRef passwdData = CFDataCreateWithBytesNoCopy(NULL,  (UInt8 *)&passwdString, passwdLen, kCFAllocatorNull);
		// send the passwd with a with a 1.0 sec timeout
	CFSocketError error = CFSocketSendData(_adminSocket, NULL, passwdData, 1.0);
	if (kCFSocketSuccess != error) {
		if (kCFSocketError == error) {
			NSDictionary* userInfo = 
				[NSDictionary 
					dictionaryWithObjectsAndKeys: 
						@"Could not send password to LanBox. You need to use LCEdit to send the password.", NSLocalizedDescriptionKey, 
						@"Could not send password to LanBox. kCFSocketError.", NSLocalizedFailureReasonErrorKey, nil];
			NSError* errorObject = [NSError errorWithDomain: NSPOSIXErrorDomain  code: error userInfo: userInfo];
			[[NSApplication sharedApplication] presentError: errorObject];
		} else {
			NSDictionary* userInfo = 
			[NSDictionary 
				dictionaryWithObjectsAndKeys: 
					@"Could not find LanBox. Check network settings", NSLocalizedDescriptionKey, 
					@"Could not send password to LanBox. kCFSocketTimeout.", NSLocalizedFailureReasonErrorKey, nil];
			NSError* errorObject = [NSError errorWithDomain: NSPOSIXErrorDomain  code: error userInfo: userInfo];
			[[NSApplication sharedApplication] presentError: errorObject];
		}
	}
	CFRelease(passwdData);
}

@end
