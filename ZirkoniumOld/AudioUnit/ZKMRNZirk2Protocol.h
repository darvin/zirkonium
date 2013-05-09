/*
 *  ZKMRNZirk2Protocol.h
 *  Zirkonium
 *
 *  Created by Chandrasekhar Ramakrishnan on 09.03.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>

class Zirk2Port {
public:
//  CTOR
				Zirk2Port();
	virtual		~Zirk2Port();
	
//  Accessors
	CFRunLoopSourceRef	GetRunLoopSource() const { return mRunLoopSource; }
	
		// message types
	enum { kZirkPort_Connect = 1, kZirkPort_Disconnect = 2, kZirkPort_Pan = 3 };
	
protected:
//  State
	CFMessagePortRef	mMessagePort;
	CFRunLoopSourceRef	mRunLoopSource;
	
//  Internal Functions
	static CFDataRef	PortManagerCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);
	virtual CFDataRef	ReceivedMessage(SInt32 msgid, CFDataRef data) = 0;
};

class Zirk2PortServer : public Zirk2Port {
public:
//  CTOR
	Zirk2PortServer();
	~Zirk2PortServer() { }
	
	class ServerPortDelegate {
	public:
		virtual void	ReceivedConnect() = 0;
		virtual void	ReceivedPan(UInt32 channel, Float32 azimuth, Float32 zenith, Float32 azimuthSpan, Float32 zenithSpan, Float32 gain) = 0;
		virtual void	ReceivedDisconnect() = 0;
	};
	
	void SetDelegate(ServerPortDelegate* delegate) { mDelegate = delegate; }
	
protected:
//  Internal Functions
	virtual CFDataRef	ReceivedMessage(SInt32 msgid, CFDataRef data);

//  State
	ServerPortDelegate*	mDelegate;
};

class Zirk2PortClient : public Zirk2Port {
public:
//  CTOR
	Zirk2PortClient();
	~Zirk2PortClient();
	
//  Accessors
	CFMessagePortRef	GetRemoteMessagePort() const { return mRemoteMessagePort; }
	CFMutableDataRef	GetData() const { return mData; }
	
//  Actions
	void SendConnect();
	void SendPan(UInt32 channel, Float32 azimuth, Float32 zenith, Float32 azimuthSpan, Float32 zenithSpan, Float32 gain);
	void SendDisconnect();
	
	
protected:
//  State
	CFMessagePortRef	mRemoteMessagePort;	
	CFMutableDataRef	mData;

//  Internal Functions	
	virtual CFDataRef	ReceivedMessage(SInt32 msgid, CFDataRef data);
	void	ClearData();
};
