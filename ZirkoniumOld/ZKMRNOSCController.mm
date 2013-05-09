//
//  ZKMRNOSCController.mm
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 05.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOSCController.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNDeviceManager.h"
#include "OscReceivedElements.h"
#include "OscPacketListener.h"
#include "IpEndpointName.h"
#include <netinet/in.h>

@interface ZKMRNOSCController (ZKMRNOSCControllerPrivate)
- (void)processPacketAddress:(CFDataRef)address data:(CFDataRef)data;
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain target:(const char*)target;
- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain target:(const char*)target;
- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain target:(const char*)target;
- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain target:(const char*)target;
- (void)masterGain:(float)gain;
@end

static void ZKMRNOSCSocketCallback(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
	ZKMRNOSCController* oscController = (ZKMRNOSCController *) info;
	[oscController processPacketAddress: address data: (CFDataRef) data];
}

class ZKMRNOSCListener : public osc::OscPacketListener {
public:
	ZKMRNOSCListener(ZKMRNOSCController* controller) : OscPacketListener(), mController(controller) { }

protected:
//  Internal Functions
    virtual void ProcessMessage( const osc::ReceivedMessage& m, const IpEndpointName& remoteEndpoint )
    {
        try {
            // example of parsing single messages. osc::OsckPacketListener
            // handles the bundle traversal.
			osc::ReceivedMessage::const_iterator arg = m.ArgumentsBegin();
			osc::ReceivedMessage::const_iterator end = m.ArgumentsEnd();
			
			bool panAz = (strcmp(m.AddressPattern(), "/pan/az") == 0);

			if (strcmp(m.AddressPattern(), "/pan/jump") == 0) {
				// ignore the track and then parse
				ReadOSCInt(arg++, end, "Track", 0);
				panAz = true;
			}
			
			if (panAz) PanAz(arg, end);
			// look for an exact match on the command name first
			if (0 == strcmp(m.AddressPattern(), "/pan/speaker/az")) PanSpeakerAz(arg, end);
			if (0 == strcmp(m.AddressPattern(), "/pan/speaker/xy")) PanSpeakerXy(arg, end);
			// continue to support the old version for now
			if (0 == strcmp(m.AddressPattern(), "/pan/speaker")) 
			{
				static int onetime = 0;
				if (onetime < 1)
				{
					ZKMORLog(kZKMORLogLevel_Warning, kZKMORLogSource_Panner, CFSTR("/pan/speaker is deprecated. Use /pan/speaker/az instead."));
					onetime = 1;
				} 
				PanSpeakerAz(arg, end);
			}
			if (0 == strcmp(m.AddressPattern(), "/pan/xy")) PanXY(arg, end);
			if (0 == strcmp(m.AddressPattern(), "/master/gain")) MasterGain(arg, end);
			
        } catch(osc::Exception& e) {
            // any parsing errors such as unexpected argument types, or 
            // missing arguments get thrown as exceptions.
			ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not parse OSC %s:%s"), m.AddressPattern(), e.what());
        }
    }
	
	int ReadOSCInt(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end, const char* name, int defaultValue)
	{
		int value = defaultValue;
		if (end == arg) return value;
		
		if (arg->IsInt32())
			value = arg->AsInt32();
		else if (arg->IsFloat())
			value = (int) arg->AsFloat();
		else {
			ZKMORLogDebug(CFSTR("%s not sent as number -- default to %i"), name, value);
		}
		return value;
	}

	float ReadOSCFloat(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end, const char* name, float defaultValue)
	{
		float value = defaultValue;
		if (end == arg) return value;
		
		if (arg->IsFloat())
			value = arg->AsFloat();
		else if (arg->IsInt32()) {
			value = (float) arg->AsInt32();
		} else {
			ZKMORLogDebug(CFSTR("%s not sent as number -- default to %.2f"), name, value);
		}
		return value;
	}
	
	const char* ReadOSCString(osc::ReceivedMessage::const_iterator arg, osc::ReceivedMessage::const_iterator end, const char* name, const char* defaultValue)
	{
		const char* value = defaultValue;
		if (end == arg) return value;
		
		if (arg->IsString()) {
			value = arg->AsString();
		} else {
			ZKMORLogDebug(CFSTR("%s not sent as string -- default to %s"), name, value);
		}
		return value;
	}
	
    void PanAz(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int channel;
		ZKMNRSphericalCoordinate center;
		ZKMNRSphericalCoordinateSpan span;
		float gain;
		const char* target;
		channel = ReadOSCInt(arg++, end, "Channel", 0);
		center.azimuth = ReadOSCFloat(arg++, end, "Azimuth", 0.f);
		center.zenith = ReadOSCFloat(arg++, end, "Zenith", 0.f);
		center.radius = 1.f;
		span.azimuthSpan = ReadOSCFloat(arg++, end, "Azimuth span", 0.f);
		span.zenithSpan = ReadOSCFloat(arg++, end, "Zenith span", 0.f);
		gain = ReadOSCFloat(arg++, end, "Gain", 0.f);
		target = ReadOSCString(arg, end, "Target", "");
		
		if (span.azimuthSpan < 0.f) span.azimuthSpan = 0.f;
		if (span.azimuthSpan > 2.f) span.azimuthSpan = 2.f;
		if (span.zenithSpan < 0.f) span.zenithSpan = 0.f;
		if (span.zenithSpan > 0.5f) span.zenithSpan = 0.5f;
		
		[mController panChannel: channel az: center span: span gain: gain target: target];
    }
	
    void PanSpeakerAz(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int channel;
		ZKMNRSphericalCoordinate center;
		float gain;
		const char* target;
		channel = ReadOSCInt(arg++, end, "Channel", 0);
		center.azimuth = ReadOSCFloat(arg++, end, "Azimuth", 0.f);
		center.zenith = ReadOSCFloat(arg++, end, "Zenith", 0.f);
		center.radius = 1.f;
		gain = ReadOSCFloat(arg++, end, "Gain", 0.f);
		target = ReadOSCString(arg, end, "Target", "");
		
		[mController panChannel: channel speakerAz: center gain: gain target: target];
    }
	
    void PanSpeakerXy(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int channel;
		ZKMNRRectangularCoordinate center;
		float gain;
		const char* target;
		channel = ReadOSCInt(arg++, end, "Channel", 0);
		center.x = ReadOSCFloat(arg++, end, "X", 0.f);
		center.y = ReadOSCFloat(arg++, end, "Y", 0.f);
		gain = ReadOSCFloat(arg++, end, "Gain", 0.f);
		target = ReadOSCString(arg, end, "Target", "");
		
		[mController panChannel: channel speakerXy: center gain: gain target: target];
    }
	
    void PanXY(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		int channel;
		ZKMNRRectangularCoordinate center;
		ZKMNRRectangularCoordinateSpan span;
		float gain;
		const char* target;
		channel = ReadOSCInt(arg++, end, "Channel", 0);
		center.x = ReadOSCFloat(arg++, end, "X", 0.f);
		center.y = ReadOSCFloat(arg++, end, "Y", 0.f);
		center.z = 0.f;
		span.xSpan = ReadOSCFloat(arg++, end, "X span", 0.f);
		span.ySpan = ReadOSCFloat(arg++, end, "Y span", 0.f);
		span.zSpan = 0.f;
		gain = ReadOSCFloat(arg++, end, "Gain", 0.f);
		target = ReadOSCString(arg, end, "Target", "");
		
		if (span.xSpan < 0.f) span.xSpan = 0.f;
		if (span.xSpan > 2.f) span.xSpan = 2.f;
		if (span.ySpan < 0.f) span.ySpan = 0.f;
		if (span.ySpan > 2.f) span.ySpan = 2.f;
		
		[mController panChannel: channel xy: center span: span gain: gain target: target];
    }
	
    void MasterGain(osc::ReceivedMessage::const_iterator& arg, osc::ReceivedMessage::const_iterator end)
    {
		float gain;
		gain = ReadOSCFloat(arg++, end, "Gain", 0.f);

		[mController masterGain: gain];
    }
	
//  State
	ZKMRNOSCController* mController;
};


@implementation ZKMRNOSCController
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (_socket) CFRelease(_socket);
	if (_runLoopSource) CFRelease(_runLoopSource);
	if (mOSCListener) delete mOSCListener;
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;

	_zirkoniumSystem = [ZKMRNZirkoniumSystem sharedZirkoniumSystem];
	CFSocketContext socketContext;

	socketContext.version = 0;
	socketContext.info = (void *) self;
	socketContext.retain = NULL;
	socketContext.release = NULL;
	socketContext.copyDescription = NULL;

	_socket = CFSocketCreate(NULL, PF_INET, SOCK_DGRAM, IPPROTO_UDP, kCFSocketDataCallBack, ZKMRNOSCSocketCallback, &socketContext);
	if (!_socket) {
		[self autorelease];
		ZKMORThrow(@"SocketErr", @"Could not create OSC listener socket");
	}
	
	_runLoopSource = CFSocketCreateRunLoopSource(NULL, _socket, 0);
	if (!_runLoopSource) {
		[self autorelease];
		ZKMORThrow(@"SocketErr", @"Could not create run loop source for OSC listener socket");
	}
	CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);

	struct sockaddr_in addr;

	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_ANY);	
	addr.sin_port = htons(50808);
	
	CFDataRef addressData = CFDataCreateWithBytesNoCopy(NULL,  (UInt8 *)&addr, sizeof(struct sockaddr_in), kCFAllocatorNull);
	CFSocketError error = CFSocketSetAddress(_socket, addressData);

	if (kCFSocketSuccess != error) {
		if (kCFSocketError == error) {
			NSDictionary* userInfo = 
				[NSDictionary 
					dictionaryWithObjectsAndKeys: 
						@"Can not start OSC listening.", NSLocalizedDescriptionKey, 
						@"Could not set addr for OSC listener socket: kCFSocketError.", NSLocalizedFailureReasonErrorKey, nil];
			NSError* errorObject = [NSError errorWithDomain: NSPOSIXErrorDomain  code: error userInfo: userInfo];
			[[NSApplication sharedApplication] presentError: errorObject];
		} else {
			NSDictionary* userInfo = 
			[NSDictionary 
				dictionaryWithObjectsAndKeys: 
					@"Can not start OSC listening.", NSLocalizedDescriptionKey, 
					@"Could not set addr for OSC listener socket: kCFSocketTimeout.", NSLocalizedFailureReasonErrorKey, nil];
			NSError* errorObject = [NSError errorWithDomain: NSPOSIXErrorDomain  code: error userInfo: userInfo];
			[[NSApplication sharedApplication] presentError: errorObject];
		}
	}
	
	CFRelease(addressData);
	
	mOSCListener = new ZKMRNOSCListener(self);
	
	return self;
}

#pragma mark _____ ZKMRNOSCControllerPrivate
- (void)processPacketAddress:(CFDataRef)address data:(CFDataRef)data
{
	// convert data to a const char* and int size;
	const char* bytes = (const char*) CFDataGetBytePtr(data);
	int bytesSize = CFDataGetLength(data);
	
	// convert the address to a IpEndpointName
	struct sockaddr_in addr;
	CFRange addrRange = { 0, sizeof(addr) };
	CFDataGetBytes(data, addrRange, (UInt8 *) &addr);
	IpEndpointName remoteEndpoint(ntohl(addr.sin_addr.s_addr), ntohs(addr.sin_port));
	try {
		// TODO: Catch osc::MalformedMessageException
		mOSCListener->ProcessPacket(bytes, bytesSize, remoteEndpoint);
	} catch (osc::MalformedMessageException e) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Malformed OSC message ignored : %s"), e.what());
	} catch (osc::MalformedBundleException e) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Malformed OSC bundle ignored : %s"), e.what());
	} catch (osc::WrongArgumentTypeException e) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Malformed OSC message ignored : %s"), e.what());
	} catch (osc::MissingArgumentException e) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Malformed OSC message ignored : %s"), e.what());
	} catch (osc::ExcessArgumentException e) {
		ZKMORLogError(kZKMORLogSource_Panner, CFSTR("Malformed OSC message ignored : %s"), e.what());
	}
}

- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain target:(const char*)target
{
	if (0 == strcmp(target, "__device__"))
		[[[_zirkoniumSystem deviceManager] deviceSetup] panChannel: channel az: center span: span gain: gain];
	else if (0 == strcmp(target, "__playing__")) {
		ZKMRNPieceDocument* playingPiece = [_zirkoniumSystem playingPiece];
		if (playingPiece) [playingPiece panChannel: channel az: center span: span gain: gain];
	} else
		[_zirkoniumSystem panChannel: channel az: center span: span gain: gain];
}

- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain target:(const char*)target
{
	if (0 == strcmp(target, "__device__"))
		[[[_zirkoniumSystem deviceManager] deviceSetup] panChannel: channel speakerAz: center gain: gain];
	else if (0 == strcmp(target, "__playing__")) {
		ZKMRNPieceDocument* playingPiece = [_zirkoniumSystem playingPiece];
		if (playingPiece) [playingPiece panChannel: channel speakerAz: center gain: gain];
	} else
		[_zirkoniumSystem panChannel: channel speakerAz: center gain: gain];
}

- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain target:(const char*)target
{
	if (0 == strcmp(target, "__device__"))
		[[[_zirkoniumSystem deviceManager] deviceSetup] panChannel: channel speakerXy: center gain: gain];
	else if (0 == strcmp(target, "__playing__")) {
		ZKMRNPieceDocument* playingPiece = [_zirkoniumSystem playingPiece];
		if (playingPiece) [playingPiece panChannel: channel speakerXy: center gain: gain];
	} else
		[_zirkoniumSystem panChannel: channel speakerXy: center gain: gain];
}

- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain target:(const char*)target
{
	if (0 == strcmp(target, "__device__"))
		[[[_zirkoniumSystem deviceManager] deviceSetup] panChannel: channel xy: center span: span gain: gain];
	else if (0 == strcmp(target, "__playing__")) {
		ZKMRNPieceDocument* playingPiece = [_zirkoniumSystem playingPiece];
		if (playingPiece) [playingPiece panChannel: channel xy: center span: span gain: gain];
	} else
		[_zirkoniumSystem panChannel: channel xy: center span: span gain: gain];
}

- (void)masterGain:(float)gain
{
	[_zirkoniumSystem setMasterGain: gain];
}


@end
