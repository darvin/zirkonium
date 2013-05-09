/*
 *  ZKMRNZirk2Protocol.cpp
 *  Zirkonium
 *
 *  Created by Chandrasekhar Ramakrishnan on 09.03.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "ZKMRNZirk2Protocol.h"

#pragma mark _____ Zirk2Port
CFDataRef Zirk2Port::PortManagerCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
	Zirk2Port* manager = reinterpret_cast<Zirk2Port*>(info);
	return manager->ReceivedMessage(msgid, data);
}

Zirk2Port::Zirk2Port() : mMessagePort(NULL), mRunLoopSource(NULL)
{
	Boolean shouldFreeInfo;
	CFMessagePortContext context;
	context.version = 0;
	context.info = this;
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;
	
	mMessagePort = CFMessagePortCreateLocal(NULL, NULL, PortManagerCallBack, &context, &shouldFreeInfo);
	if (shouldFreeInfo || (!mMessagePort)) {
		CFShow(CFSTR("Could not create message port"));
		mMessagePort = NULL;
		return;
	}
	
	mRunLoopSource = CFMessagePortCreateRunLoopSource(NULL, mMessagePort, 0);
}

Zirk2Port::~Zirk2Port()
{
	CFRelease(mMessagePort);
	CFRelease(mRunLoopSource);
}

#pragma mark _____ Zirk2PortServer
Zirk2PortServer::Zirk2PortServer() : Zirk2Port() 
{ 
	CFMessagePortSetName(mMessagePort, CFSTR("Zirk2PortServer"));
}

CFDataRef Zirk2PortServer::ReceivedMessage(SInt32 msgid, CFDataRef data)
{
	switch (msgid) {
		case kZirkPort_Connect: if (mDelegate) mDelegate->ReceivedConnect(); break;
		case kZirkPort_Disconnect: if (mDelegate) mDelegate->ReceivedDisconnect(); break;
		case kZirkPort_Pan: 
		{
			const UInt8* bytePtr = CFDataGetBytePtr(data);
			UInt32 channel;
			Float32 azimuth, zenith, azimuthSpan, zenithSpan, gain;
			channel = *((UInt32 *)bytePtr); bytePtr += sizeof(UInt32);
			azimuth = *((Float32 *)bytePtr); bytePtr += sizeof(Float32);
			zenith = *((Float32 *)bytePtr); bytePtr += sizeof(Float32);
			azimuthSpan = *((Float32 *)bytePtr); bytePtr += sizeof(Float32);
			zenithSpan = *((Float32 *)bytePtr); bytePtr += sizeof(Float32);
			gain = *((Float32 *)bytePtr);
			if (mDelegate) mDelegate->ReceivedPan(channel, azimuth, zenith, azimuthSpan, zenithSpan, gain);
		} break;
	}
	return NULL;
}

#pragma mark _____ Zirk2PortClient
Zirk2PortClient::Zirk2PortClient() : Zirk2Port(), mRemoteMessagePort(NULL), mData(NULL)
{
	CFMessagePortSetName(mMessagePort, CFSTR("Zirk2PortClient"));
	mRemoteMessagePort = CFMessagePortCreateRemote(NULL, CFSTR("Zirk2PortServer"));
	if (!mRemoteMessagePort) {
		CFShow(CFSTR("Could not create remote message port"));
		mRemoteMessagePort = NULL;
	}
	mData = CFDataCreateMutable(NULL, 0);
}

Zirk2PortClient::~Zirk2PortClient()
{
	if (mRemoteMessagePort) CFRelease(mRemoteMessagePort);
	if (mData) CFRelease(mData);	
}

void Zirk2PortClient::SendConnect()
{
	if (!mRemoteMessagePort) return;
	
	CFDataRef returnData;
	SInt32 ans = CFMessagePortSendRequest(GetRemoteMessagePort(), kZirkPort_Connect, mData, 1., 1., NULL, &returnData);
	if (ans != 0) return;
}

void Zirk2PortClient::SendPan(UInt32 channel, Float32 azimuth, Float32 zenith, Float32 azimuthSpan, Float32 zenithSpan, Float32 gain)
{
	if (!mRemoteMessagePort) return;
	
	ClearData();
	CFDataAppendBytes(mData, (const UInt8*) &channel, sizeof(channel));
	CFDataAppendBytes(mData, (const UInt8*) &azimuth, sizeof(azimuth));
	CFDataAppendBytes(mData, (const UInt8*) &zenith, sizeof(zenith));
	CFDataAppendBytes(mData, (const UInt8*) &azimuthSpan, sizeof(azimuthSpan));
	CFDataAppendBytes(mData, (const UInt8*) &zenithSpan, sizeof(zenithSpan));
	CFDataAppendBytes(mData, (const UInt8*) &gain, sizeof(gain));	
	
	CFDataRef returnData;
	SInt32 ans = CFMessagePortSendRequest(GetRemoteMessagePort(), kZirkPort_Pan, mData, 1., 1., NULL, &returnData);
	if (ans != 0) return;	
}


void Zirk2PortClient::SendDisconnect()
{
	if (!mRemoteMessagePort) return;
	
	CFDataRef returnData;
	SInt32 ans = CFMessagePortSendRequest(GetRemoteMessagePort(), kZirkPort_Disconnect, mData, 1., 1., NULL, &returnData);
	if (ans != 0) return;
}

CFDataRef Zirk2PortClient::ReceivedMessage(SInt32 msgid, CFDataRef data)
{
	CFShow(CFSTR("Sender: Received callback"));
	return NULL;
}

void Zirk2PortClient::ClearData()
{
	CFRange range = CFRangeMake(0, CFDataGetLength(mData));
	CFDataDeleteBytes(mData, range);
}
