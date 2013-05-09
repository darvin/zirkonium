/*
 *  ZKMRNHALPlugInProtocol.h
 *  Zirkonium
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __ZKMRNHALPlugInProtocol_H__
#define __ZKMRNHALPlugInProtocol_H__

#include <CoreFoundation/CoreFoundation.h>

class ZirkoniumHALPort {
public:
//  CTOR
				ZirkoniumHALPort();
	virtual		~ZirkoniumHALPort();
	
//  Accessors
	CFRunLoopSourceRef	GetRunLoopSource() const { return mRunLoopSource; }
	CFMutableDataRef	GetData() const { return mData; }
	CFStringRef			CopyPortNameForPID(pid_t processID) { return CFStringCreateWithFormat(NULL, NULL, CFSTR("ZirkoniumHALClientPort-%u"), processID); }
	
	typedef enum {
		/// struct checkinmsg { pid_t pid; CFIndex appnamelen; char* appname; }
		kCheckInMessage = 1,
		/// struct heartbeatmsg { pid_t pid; }
		kHeartbeatMessage = 2,
		/// struct setuppathmsg { pid_t pid; UInt32 numberOfInputs; UInt32 numberOfOutputs; }
//		kDeviceSetMixerSizeMessage = 3,
		/// struct setupchmapmsg { pid_t pid; CFIndex length; UInt32[length] channelMap }
		kDeviceSetInputChannelMapMessage = 4,
		/// struct setupchmapmsg { pid_t pid; CFIndex length UInt32[length] channelMap }
		kDeviceSetOutputChannelMapMessage = 5,
		/// struct setupchmapmsg { pid_t pid; CFIndex length; Float32[length / sizeof(Float32)] coeffs }
		kDeviceSetMatrixCoeffsMessage = 6,
		/// struct simmodemsg { pid_t pid; UInt8 numberOfInputs; UInt8 numberOfOutputs; bool ison; CFIndex length; CFData speakerLayout }		
		kDeviceSetSimulationMode = 7,
		/// struct loglevelmsg { pid_t pid; bool debugOn; UInt32 debugLevel}
		kDeviceSetLogLevel = 8,
		/// struct setnumchmsg { pid_t pid; UInt32 numberOfChannels }
		kDeviceSetNumberOfChannels = 9
	} MessageID;
	
protected:
//  Internal Functions
	static CFDataRef	PortManagerCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);
	virtual CFDataRef	ReceivedMessage(SInt32 msgid, CFDataRef data) = 0;
	void				ClearData();
	void				BeginMessage();

	void				ReadAndAdvanceRange(CFDataRef data, CFRange& range, void* memoryLocation);	
	void				AppendLength(CFIndex length);
	CFIndex				ReadLengthAndAdvanceRange(CFDataRef data, CFRange& range);
//	void				AppendFloats(UInt32 count, Float32 *floats);


//  State
	CFMessagePortRef	mMessagePort;
	CFRunLoopSourceRef	mRunLoopSource;
	CFMutableDataRef	mData;
};

class ZirkoniumHALServerPort : public ZirkoniumHALPort {
public:
//  CTOR
	ZirkoniumHALServerPort();
	~ZirkoniumHALServerPort();

//  Protocol	
	//  Heartbeating
	SInt32		SendHeartbeatMessage(CFMessagePortRef port);
	//  Device Setup
	SInt32		SendOutputChannelMap(CFMessagePortRef port, UInt32 mapSize, SInt32* map);
	SInt32		SendSpeakerMode(CFMessagePortRef port, UInt8 numberOfInputs, UInt8 numberOfOutputs, UInt8 speakerMode, UInt8 simulationMode, CFDataRef speakerLayout);	
	SInt32		SendSetNumberOfChannels(CFMessagePortRef port, UInt32 numberOfChannels);
	
	//  Coeffs
		/// length is the length in bytes of the coeffs
	SInt32		SendSetMatrix(CFMessagePortRef port, CFIndex lengthInBytes, Float32* coeffs);
	
	//  Debug
	SInt32		SendLoggingLevel(CFMessagePortRef port, bool debugIsOn, UInt32 debugLevel);
	
//  Delegate
	class ServerPortDelegate {
	public:
		virtual void CheckIn(pid_t processID, CFIndex length, char* appname) = 0;
	};
	
	void SetDelegate(ServerPortDelegate* delegate) { mDelegate = delegate; }
	
protected:
//  Internal Functions
	virtual CFDataRef	ReceivedMessage(SInt32 msgid, CFDataRef data);
	
//  State
	ServerPortDelegate*	mDelegate;
};

class ZirkoniumHALClientPort : public ZirkoniumHALPort {
public:
//  CTOR
	ZirkoniumHALClientPort();
	~ZirkoniumHALClientPort();
	
//  Actions
	void				Connect();
	
//  Queries
	bool				IsConnected() const { return mIsConnected; }
	
//  Delegate
	class ClientPortDelegate {
	public:
		virtual void ReceiveSetMatrix(CFIndex lengthInBytes, Float32* coeffs) = 0;
		virtual void ReceiveOutputChannelMap(UInt32 mapSize, SInt32* map) = 0;
		virtual void ReceiveSpeakerMode(UInt8 numberOfInputs, UInt8 numberOfOutputs, UInt8 speakerMode, UInt8 simulationMode, CFDataRef speakerLayout) = 0;
		virtual void ReceiveNumberOfChannels(UInt32 numberOfChannels) = 0;
		virtual void ReceiveLogLevel(bool debugIsOn, UInt32 debugLevel) = 0;
	};
	
	void SetDelegate(ClientPortDelegate* delegate) { mDelegate = delegate; }
	
protected:
//  Internal Functions
	virtual CFDataRef	ReceivedMessage(SInt32 msgid, CFDataRef data);
	void				SendCheckInMessage();
	
//  State
	CFMessagePortRef	mRemoteMessagePort;	
	bool				mIsConnected;
	bool				mIsLocalPortConnected;
	ClientPortDelegate*	mDelegate;
};

#endif