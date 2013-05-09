/*	Copyright © 2007 Apple Inc. All Rights Reserved.
	
	Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
			Apple Inc. ("Apple") in consideration of your agreement to the
			following terms, and your use, installation, modification or
			redistribution of this Apple software constitutes acceptance of these
			terms.  If you do not agree with these terms, please do not use,
			install, modify or redistribute this Apple software.
			
			In consideration of your agreement to abide by the following terms, and
			subject to these terms, Apple grants you a personal, non-exclusive
			license, under Apple's copyrights in this original Apple software (the
			"Apple Software"), to use, reproduce, modify and redistribute the Apple
			Software, with or without modifications, in source and/or binary forms;
			provided that if you redistribute the Apple Software in its entirety and
			without modifications, you must retain this notice and the following
			text and disclaimers in all such redistributions of the Apple Software. 
			Neither the name, trademarks, service marks or logos of Apple Inc. 
			may be used to endorse or promote products derived from the Apple
			Software without specific prior written permission from Apple.  Except
			as expressly stated in this notice, no other rights or licenses, express
			or implied, are granted by Apple herein, including but not limited to
			any patent rights that may be infringed by your derivative works or by
			other works in which the Apple Software may be incorporated.
			
			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
			MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
			THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
			FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
			OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
			
			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
			OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
			SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
			INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
			MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
			AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
			STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
			POSSIBILITY OF SUCH DAMAGE.
*/
//==================================================================================================
//	Includes
//==================================================================================================

//	Self Include
#include "SDP_PlugIn.h"

//	PublicUtility Includes
#include "CADebugMacros.h"
#include "CAException.h"
#include "CACFMachPort.h"

//==================================================================================================
//	SDP_PlugIn
//==================================================================================================

SDP_PlugIn::SDP_PlugIn(const AudioDriverPlugInHostInfo& inHostInfo)
:
	HP_DriverPlugIn(inHostInfo),
	mEngineConnection(IO_OBJECT_NULL),
	mConnectionNotificationPort(NULL)
{
	//	create the Mach port for connection notifications
	mConnectionNotificationPort = new CACFMachPort((CFMachPortCallBack)MachPortCallBack, this);

	//  add the run loop source for the connection notifications
	AudioHardwareAddRunLoopSource(mConnectionNotificationPort->GetRunLoopSource());
	
	//	open a connection to the engine
	kern_return_t theKernelError = IOServiceOpen(mHostInfo.mIOAudioEngine, mach_task_self(), 0, &mEngineConnection);
	ThrowIfKernelError(theKernelError, CAException(theKernelError), "SDP_PlugIn::SDP_PlugIn: Cannot connect to the IOAudioEngine.");
	
	//	tell the connection about our notification mach_port_t
	theKernelError = IOConnectSetNotificationPort(mEngineConnection, 0, mConnectionNotificationPort->GetMachPort(), 0);
	ThrowIfKernelError(theKernelError, CAException(theKernelError), "SDP_PlugIn::SDP_PlugIn: Cannot set the device's notification port.");
}

SDP_PlugIn::~SDP_PlugIn()
{
	//	close the connection to the engine
	if(mEngineConnection != IO_OBJECT_NULL)
	{
		IOServiceClose(mEngineConnection);
	}
	
	//  get rid of the run loop source for connection notifications
	AudioHardwareRemoveRunLoopSource(mConnectionNotificationPort->GetRunLoopSource());
	
	//  get rid of the port
	delete mConnectionNotificationPort;
}

HP_DriverPlugIn*	HP_DriverPlugIn::CreatePlugIn(const AudioDriverPlugInHostInfo& inHostInfo)
{
	//	Note that this really is a static method of the base class, HP_DriverPlugIn. It is not
	//	defined by the base class so that sub-classes can, in effect, "override" the method in the
	//	base class. It is a quick and dirty way to fake a virtual static method that is applicable
	//	only in situations where you know ahead of time that there will be one and only one
	//	sub-class.
	return new SDP_PlugIn(inHostInfo);
}

void	HP_DriverPlugIn::DestroyPlugIn(HP_DriverPlugIn* inPlugIn)
{
	//	Note that this really is a static method of the base class, HP_DriverPlugIn. It is not
	//	defined by the base class so that sub-classes can, in effect, "override" the method in the
	//	base class. It is a quick and dirty way to fake a virtual static method that is applicable
	//	only in situations where you know ahead of time that there will be one and only one
	//	sub-class.
	delete inPlugIn;
}

bool	SDP_PlugIn::DeviceHasProperty(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID) const
{
	bool theAnswer = true;
	
	switch(inPropertyID)
	{
		case kSampleDriverPlugInDevicePropertyFoo:
			theAnswer = true;
			break;
			
		default:
			theAnswer = HP_DriverPlugIn::DeviceHasProperty(inChannel, isInput, inPropertyID);
			break;
	};
	
	return theAnswer;
}

UInt32	SDP_PlugIn::DeviceGetPropertyDataSize(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID) const
{
	UInt32 theAnswer = 0;
	
	switch(inPropertyID)
	{
		case kSampleDriverPlugInDevicePropertyFoo:
			theAnswer = sizeof(UInt32);
			break;
			
		default:
			theAnswer = HP_DriverPlugIn::DeviceGetPropertyDataSize(inChannel, isInput, inPropertyID);
			break;
	};
	
	return theAnswer;
}

bool	SDP_PlugIn::DeviceIsPropertyWritable(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID) const
{
	bool theAnswer = false;
	
	switch(inPropertyID)
	{
		case kSampleDriverPlugInDevicePropertyFoo:
			theAnswer = true;
			break;
			
		default:
			theAnswer = HP_DriverPlugIn::DeviceIsPropertyWritable(inChannel, isInput, inPropertyID);
			break;
	};
	
	return theAnswer;
}

void	SDP_PlugIn::DeviceGetPropertyData(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32& ioPropertyDataSize, void* outPropertyData) const
{
	switch(inPropertyID)
	{
		case kSampleDriverPlugInDevicePropertyFoo:
			{
				//	make sure the size is right
				ThrowIf(ioPropertyDataSize != DeviceGetPropertyDataSize(inChannel, isInput, inPropertyID), CAException(kAudioHardwareBadPropertySizeError), "SDP_PlugIn::DeviceGetPropertyData: wrong data size for kSampleDriverPlugInDevicePropertyFoo");
				
				//	set the return value
				*((UInt32*)outPropertyData) = GetFoo(mHostInfo.mIOAudioEngine);
			}
			break;
		
		default:
			HP_DriverPlugIn::DeviceGetPropertyData(inChannel, isInput, inPropertyID, ioPropertyDataSize, outPropertyData);
			break;
	};
}

void	SDP_PlugIn::DeviceSetPropertyData(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData)
{
	switch(inPropertyID)
	{
		case kSampleDriverPlugInDevicePropertyFoo:
			{
				//	make sure the size is right
				ThrowIf(inPropertyDataSize != DeviceGetPropertyDataSize(inChannel, isInput, inPropertyID), CAException(kAudioHardwareBadPropertySizeError), "SDP_PlugIn::DeviceSetPropertyData: wrong data size for kSampleDriverPlugInDevicePropertyFoo");
				
				//	get the new value
				UInt32 theValue = *static_cast<const UInt32*>(inPropertyData);
				
				//	tell the driver about it
				SetFoo(mHostInfo.mIOAudioEngine, theValue);
			}
			break;
		
		default:
			HP_DriverPlugIn::DeviceSetPropertyData(inChannel, isInput, inPropertyID, inPropertyDataSize, inPropertyData);
			break;
	};
}

bool	SDP_PlugIn::StreamHasProperty(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID) const
{
	return HP_DriverPlugIn::StreamHasProperty(inIOAudioStream, inChannel, inPropertyID);
}

UInt32	SDP_PlugIn::StreamGetPropertyDataSize(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID) const
{
	return HP_DriverPlugIn::StreamGetPropertyDataSize(inIOAudioStream, inChannel, inPropertyID);
}

bool	SDP_PlugIn::StreamIsPropertyWritable(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID) const
{
	return HP_DriverPlugIn::StreamIsPropertyWritable(inIOAudioStream, inChannel, inPropertyID);
}

void	SDP_PlugIn::StreamGetPropertyData(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32& ioPropertyDataSize, void* outPropertyData) const
{
	HP_DriverPlugIn::StreamGetPropertyData(inIOAudioStream, inChannel, inPropertyID, ioPropertyDataSize, outPropertyData);
}

void	SDP_PlugIn::StreamSetPropertyData(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData)
{
	HP_DriverPlugIn::StreamSetPropertyData(inIOAudioStream, inChannel, inPropertyID, inPropertyDataSize, inPropertyData);
}

UInt32	SDP_PlugIn::GetFoo(io_object_t /*inIOAudioEngine*/)
{
	//	look up the foo property in the registry
	return 0;
}

void	SDP_PlugIn::SetFoo(io_object_t /*inIOAudioEngine*/, UInt32 /*inFoo*/)
{
	//	set the value of the foo property in the registry
}

void	SDP_PlugIn::MachPortCallBack(CFMachPortRef /*inCFMachPort*/, void* /*inMessage*/, CFIndex /*inSize*/, SDP_PlugIn* inPlugIn)
{
	try
	{
		//	presumably foo changed, so let the HAL call the listeners
		inPlugIn->mHostInfo.mDevicePropertyChangedProc(inPlugIn->mHostInfo.mDeviceID, 0, false, kSampleDriverPlugInDevicePropertyFoo);
	}
	catch(const CAException& inException)
	{
	}
	catch(...)
	{
	}
}
