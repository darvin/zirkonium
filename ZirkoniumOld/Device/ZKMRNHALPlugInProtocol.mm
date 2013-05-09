/*
 *  ZKMRNHALPlugInProtocol.mm
 *  Zirkonium
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "ZKMRNHALPlugInProtocol.h"
#include <Syncretism/ZKMORLogger.h>
#include <unistd.h>

//  Copied from Apple
static inline void SwapUInt32ArrayBigToHost(UInt32 *array, UInt32  count) 
{
    int i;
 
    for(i = 0; i < count; i++) {
        array[i] = CFSwapInt32BigToHost(array[i]);
    }
}

static inline void SwapUInt32ArrayHostToBig(UInt32 *array, UInt32  count) 
{
    int i;
 
    for(i = 0; i < count; i++) {
        array[i] = CFSwapInt32HostToBig(array[i]);
    }
}

static inline void SwapFloat32ArraySwappedToHost(Float32 *array, UInt32  count) 
{
    int i;
	CFSwappedFloat32 *swapped = (CFSwappedFloat32 *) array;
 
    for(i = 0; i < count; i++) {
        array[i] = CFConvertFloat32SwappedToHost(swapped[i]);
    }
}

static inline void SwapFloat32ArrayHostToSwapped(Float32 *array, UInt32  count) 
{
    int i;
	CFSwappedFloat32 *swapped = (CFSwappedFloat32 *) array;
 
    for(i = 0; i < count; i++) {
        swapped[i] = CFConvertFloat32HostToSwapped(array[i]);
    }
}

#pragma mark _____ ZirkoniumHALPort
CFDataRef ZirkoniumHALPort::PortManagerCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info)
{
	ZirkoniumHALPort* manager = reinterpret_cast<ZirkoniumHALPort*>(info);
	return manager->ReceivedMessage(msgid, data);
}

ZirkoniumHALPort::ZirkoniumHALPort() : mMessagePort(NULL), mRunLoopSource(NULL), mData(NULL)
{	
	Boolean shouldFreeInfo;
	CFMessagePortContext context;
	context.info = this;
	context.version = 0; context.retain = NULL; context.release = NULL; context.copyDescription = NULL;	
	mMessagePort = CFMessagePortCreateLocal(NULL, NULL, PortManagerCallBack, &context, &shouldFreeInfo);
	if (shouldFreeInfo || (!mMessagePort)) {
		CFShow(CFSTR("Could not create message port"));
		mMessagePort = NULL;
		return;
	}
	
	mRunLoopSource = CFMessagePortCreateRunLoopSource(NULL, mMessagePort, 0);
	mData = CFDataCreateMutable(NULL, 0);
}

ZirkoniumHALPort::~ZirkoniumHALPort()
{
	CFRelease(mMessagePort);
	CFRelease(mRunLoopSource);
	CFRelease(mData);
}

void	ZirkoniumHALPort::ClearData()
{
	CFRange range = CFRangeMake(0, CFDataGetLength(mData));
	CFDataDeleteBytes(mData, range);
}

void	ZirkoniumHALPort::BeginMessage()
{
	ClearData();
	
	pid_t processID = getpid();
	processID = CFSwapInt32HostToBig(processID);
	CFDataAppendBytes(mData, (UInt8 *)&processID, sizeof(pid_t));
}

void		ZirkoniumHALPort::ReadAndAdvanceRange(CFDataRef data, CFRange& range, void* memoryLocation)
{
	UInt32 length = CFDataGetLength(data);
	if (length < (range.location + range.length)) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Port attempting to read beyond length: {%u, %u} >= %u"), range.location, range.length, length);
		return;
	}
	CFDataGetBytes(data, range, (UInt8 *) memoryLocation);
 	range.location += range.length;
}

void	ZirkoniumHALPort::AppendLength(CFIndex length)
{
	UInt32 lenthToSend = (UInt32) length;
	lenthToSend = CFSwapInt32HostToBig(lenthToSend);
	CFDataAppendBytes(mData, (UInt8 *) &lenthToSend, sizeof(UInt32));	
}

CFIndex	ZirkoniumHALPort::ReadLengthAndAdvanceRange(CFDataRef data, CFRange& range)
{
	UInt32 lengthInBytes;
	range.length = sizeof(UInt32);	
	ReadAndAdvanceRange(data, range, &lengthInBytes);
	lengthInBytes = CFSwapInt32BigToHost(lengthInBytes);
	return lengthInBytes;
}

#pragma mark _____ ZirkoniumHALServerPort
ZirkoniumHALServerPort::ZirkoniumHALServerPort() : ZirkoniumHALPort(), mDelegate(NULL)
{ 
	CFMessagePortSetName(mMessagePort, CFSTR("ZirkoniumHALServerPort"));
}

ZirkoniumHALServerPort::~ZirkoniumHALServerPort()
{

}

#pragma mark _____ Heartbeating
SInt32		ZirkoniumHALServerPort::SendHeartbeatMessage(CFMessagePortRef port)
{
	BeginMessage();
	
	return CFMessagePortSendRequest(port, kHeartbeatMessage, mData, 1., 1., NULL, NULL);	
}

#pragma mark _____ Device Setup
SInt32		ZirkoniumHALServerPort::SendOutputChannelMap(CFMessagePortRef port, UInt32 mapSize, SInt32* map)
{	
	BeginMessage();
	
	SwapUInt32ArrayHostToBig((UInt32 *) map, mapSize);
	
	AppendLength(mapSize);
	CFDataAppendBytes(mData, (UInt8 *) map, sizeof(SInt32) * mapSize);
	return CFMessagePortSendRequest(port, kDeviceSetOutputChannelMapMessage, mData, 1., 1., NULL, NULL);
}

SInt32		ZirkoniumHALServerPort::SendSpeakerMode(CFMessagePortRef port, UInt8 numberOfInputs, UInt8 numberOfOutputs, UInt8 speakerMode, UInt8 simulationMode, CFDataRef speakerLayout)
{
	BeginMessage();
	
	CFDataAppendBytes(mData, (UInt8 *) &numberOfInputs, sizeof(UInt8));
	CFDataAppendBytes(mData, (UInt8 *) &numberOfOutputs, sizeof(UInt8));
	CFDataAppendBytes(mData, (UInt8 *) &speakerMode, sizeof(UInt8));
	CFDataAppendBytes(mData, (UInt8 *) &simulationMode, sizeof(UInt8));
	CFIndex lengthInBytes = CFDataGetLength(speakerLayout);
	AppendLength(lengthInBytes);
	CFDataAppendBytes(mData, CFDataGetBytePtr(speakerLayout), lengthInBytes);
	return CFMessagePortSendRequest(port, kDeviceSetSimulationMode, mData, 1., 1., NULL, NULL);
}

SInt32		ZirkoniumHALServerPort::SendSetNumberOfChannels(CFMessagePortRef port, UInt32 numberOfChannels)
{
	BeginMessage();
	
	AppendLength(numberOfChannels);
	return CFMessagePortSendRequest(port, kDeviceSetNumberOfChannels, mData, 1., 1., NULL, NULL);
}

#pragma mark _____ Coeffs
SInt32		ZirkoniumHALServerPort::SendSetMatrix(CFMessagePortRef port, CFIndex lengthInBytes, Float32* coeffs)
{
	BeginMessage();
	
	AppendLength(lengthInBytes);
//	SwapFloat32ArrayHostToSwapped(coeffs, lengthInBytes);
	CFDataAppendBytes(mData, (UInt8 *) coeffs, lengthInBytes);
	return CFMessagePortSendRequest(port, kDeviceSetMatrixCoeffsMessage, mData, 1., 1., NULL, NULL);
}

#pragma mark _____ Debug
SInt32		ZirkoniumHALServerPort::SendLoggingLevel(CFMessagePortRef port, bool debugIsOn, UInt32 debugLevel)
{
	BeginMessage();
	
	CFDataAppendBytes(mData, (UInt8 *) &debugIsOn, sizeof(bool));
	CFDataAppendBytes(mData, (UInt8 *) &debugLevel, sizeof(UInt32));
	return CFMessagePortSendRequest(port, kDeviceSetLogLevel, mData, 1., 1., NULL, NULL);
}

#pragma mark _____ Internal Functions
CFDataRef	ZirkoniumHALServerPort::ReceivedMessage(SInt32 msgid, CFDataRef data)
{
	/// all messages begin with the pid
	CFRange range = { 0, sizeof(pid_t) };
	pid_t processID;
	ReadAndAdvanceRange(data, range, &processID);
	processID = CFSwapInt32BigToHost(processID);

	switch(msgid) {
		case kCheckInMessage: 
		{
			// read the message
			CFIndex length = ReadLengthAndAdvanceRange(data, range);
			range.length = length;			
			UInt8 bundleStr[256];
			ReadAndAdvanceRange(data, range, bundleStr);
			bundleStr[length] = '\0';
			if (mDelegate) mDelegate->CheckIn(processID, length, (char *) &bundleStr);
		} break;
		case kHeartbeatMessage:
			break;
		default:
			break;
	}
	return NULL;
}

#pragma mark _____ ZirkoniumHALClientPort
ZirkoniumHALClientPort::ZirkoniumHALClientPort() : ZirkoniumHALPort(), mRemoteMessagePort(NULL), mIsConnected(false), mIsLocalPortConnected(false), mDelegate(NULL)
{

}

ZirkoniumHALClientPort::~ZirkoniumHALClientPort()
{
	if (mRemoteMessagePort) CFRelease(mRemoteMessagePort);
}

#pragma mark _____ Actions
void		ZirkoniumHALClientPort::Connect()
{
	if (mIsConnected) return;
	
	if (!mIsLocalPortConnected) {
		CFStringRef clientPortName = CopyPortNameForPID(getpid());
		CFMessagePortSetName(mMessagePort, clientPortName);
		mIsLocalPortConnected = true;
		CFRelease(clientPortName);
	}
	mRemoteMessagePort = CFMessagePortCreateRemote(NULL, CFSTR("ZirkoniumHALServerPort"));
	if (!mRemoteMessagePort) {
		CFShow(CFSTR("Could not create remote message port"));
		mIsConnected = false;
		return;
	}
	mIsConnected = true;
	
	SendCheckInMessage();
}

#pragma mark _____ Internal Functions
CFDataRef	ZirkoniumHALClientPort::ReceivedMessage(SInt32 msgid, CFDataRef data)
{
	/// all messages begin with the pid
	CFRange range = { 0, sizeof(pid_t) };
	pid_t processID;
	CFDataGetBytes(data, range, (UInt8*) &processID);
	processID = CFSwapInt32BigToHost(processID);
	range.location += sizeof(pid_t);

	switch(msgid) {
		case kCheckInMessage:
			break;
		case kHeartbeatMessage:
			break;
		case kDeviceSetMatrixCoeffsMessage:
		{
			CFIndex lengthInBytes;
			lengthInBytes = ReadLengthAndAdvanceRange(data, range);
			range.length = lengthInBytes;
			const UInt8 *dataPtr = CFDataGetBytePtr(data);
			Float32 coeffs[lengthInBytes];
			memcpy(coeffs, dataPtr + range.location, lengthInBytes);
//			SwapFloat32ArraySwappedToHost(coeffs, lengthInBytes);		
			if (mDelegate) mDelegate->ReceiveSetMatrix(lengthInBytes, coeffs);
		} break;
		case kDeviceSetOutputChannelMapMessage:
		{
			// TODO: Switch to using the convenience functions ReadAndAdvanceRange, ReadLengthAndAdvanceRange	
			UInt32 mapSize; SInt32* map;
			range.length = sizeof(UInt32);
			CFDataGetBytes(data, range, (UInt8 *) &mapSize);
			mapSize = CFSwapInt32BigToHost(mapSize);
			range.location += range.length; range.length = mapSize * sizeof(SInt32);
			const UInt8 *dataPtr = CFDataGetBytePtr(data);
			map = (SInt32 *) (dataPtr + range.location);
			SwapUInt32ArrayBigToHost((UInt32 *) map, mapSize);
			if (mDelegate) mDelegate->ReceiveOutputChannelMap(mapSize, map);
		} break;
		case kDeviceSetSimulationMode:
		{
			UInt8 numberOfInputs;
			range.length = sizeof(UInt8);
			ReadAndAdvanceRange(data, range, &numberOfInputs);
			
			UInt8 numberOfOutputs;
			range.length = sizeof(UInt8);
			ReadAndAdvanceRange(data, range, &numberOfOutputs);
			
			UInt8 speakerMode;
			range.length = sizeof(UInt8);
			ReadAndAdvanceRange(data, range, &speakerMode);

			UInt8 simulationMode;
			range.length = sizeof(UInt8);
			ReadAndAdvanceRange(data, range, &simulationMode);

			UInt32 lengthInBytes;
			lengthInBytes = ReadLengthAndAdvanceRange(data, range);
			
			CFDataRef speakerLayout = 
				CFDataCreateWithBytesNoCopy(	NULL, 
												CFDataGetBytePtr(data) + range.location, 
												lengthInBytes, 
												kCFAllocatorNull);
			if (mDelegate) mDelegate->ReceiveSpeakerMode(numberOfInputs, numberOfOutputs, speakerMode, simulationMode, speakerLayout);
			CFRelease(speakerLayout);
		} break;
		case kDeviceSetNumberOfChannels:
		{
			UInt32 numberOfChannels = ReadLengthAndAdvanceRange(data, range);
			if (mDelegate) mDelegate->ReceiveNumberOfChannels(numberOfChannels);
		} break;
		case kDeviceSetLogLevel:
		{
			bool debugIsOn;
			range.length = sizeof(bool);
			ReadAndAdvanceRange(data, range, &debugIsOn);
			
			UInt32 debugLevel;
			range.length = sizeof(UInt32);
			ReadAndAdvanceRange(data, range, &debugLevel);
			
			if (mDelegate) mDelegate->ReceiveLogLevel(debugIsOn, debugLevel);
		}
		default:
			break;
	}
	return NULL;
}

void		ZirkoniumHALClientPort::SendCheckInMessage()
{
	BeginMessage();

	CFBundleRef mainBundle = CFBundleGetMainBundle();
	CFStringRef bundleID = CFBundleGetIdentifier(mainBundle);
	if (!bundleID) bundleID = CFSTR("Unknown");
	CFIndex length = (CFStringGetLength(bundleID) < 256) ? CFStringGetLength(bundleID) : 256;
	UInt8 bundleStr[256];
	CFStringGetCString(bundleID, (char*) bundleStr, 256, kCFStringEncodingASCII);
	AppendLength(length);
	CFDataAppendBytes(mData, bundleStr, length);
	SInt32 err = CFMessagePortSendRequest(mRemoteMessagePort, kCheckInMessage, mData, 1., 1., NULL, NULL);
	if (err != kCFMessagePortSuccess) printf("Failed to check in %i\n", err);
}

