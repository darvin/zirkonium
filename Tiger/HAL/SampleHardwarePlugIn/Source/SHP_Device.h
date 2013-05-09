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
#if !defined(__SHP_Device_h__)
#define __SHP_Device_h__

//=============================================================================
//	Includes
//=============================================================================

//	Super Class Includes
#include "HP_Device.h"

//  System Includes
#include <IOKit/IOKitLib.h>

//=============================================================================
//	Types
//=============================================================================

class	HP_DeviceControlProperty;
class	HP_HogMode;
class	HP_IOProc;
class   HP_IOThread;
class	SHP_PlugIn;
class   SHP_Stream;

//=============================================================================
//	SHP_Device
//=============================================================================

class SHP_Device
:
	public HP_Device
{

//	Construction/Destruction
public:
								SHP_Device(AudioDeviceID inAudioDeviceID, SHP_PlugIn* inPlugIn);
	virtual						~SHP_Device();

	virtual void				Initialize();
	virtual void				Teardown();
	virtual void				Finalize();

protected:
	SHP_PlugIn*					mSHPPlugIn;
	
//	Attributes
public:
	SHP_PlugIn*					GetSHPPlugIn() const { return mSHPPlugIn; }
	virtual CFStringRef			CopyDeviceName() const;
	virtual CFStringRef			CopyDeviceManufacturerName() const;
	virtual CFStringRef			CopyDeviceUID() const;
	virtual bool				HogModeIsOwnedBySelf() const;
	virtual bool				HogModeIsOwnedBySelfOrIsFree() const;
	virtual void				HogModeStateChanged();

private:
	HP_HogMode*					mHogMode;

//	Property Access
public:
	virtual bool				HasProperty(const AudioObjectPropertyAddress& inAddress) const;
	virtual bool				IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const;
	virtual UInt32				GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const;
	virtual void				GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const;
	virtual void				SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen);

protected:
	virtual void				PropertyListenerAdded(const AudioObjectPropertyAddress& inAddress);

//	Command Management
protected:
	virtual bool				IsSafeToExecuteCommand();
	virtual bool				StartCommandExecution(void** outSavedCommandState);
	virtual void				FinishCommandExecution(void* inSavedCommandState);

//	IOProc Management
public:
	virtual void				Do_StartIOProc(AudioDeviceIOProc inProc);
	virtual void				Do_StartIOProcAtTime(AudioDeviceIOProc inProc, AudioTimeStamp& ioStartTime, UInt32 inStartTimeFlags);

//  IO Management
public:
	virtual CAGuard*			GetIOGuard();
	virtual bool				CallIOProcs(const AudioTimeStamp& inCurrentTime, const AudioTimeStamp& inInputTime, const AudioTimeStamp& inOutputTime);
	
protected:
	virtual void				StartIOEngine();
	virtual void				StartIOEngineAtTime(const AudioTimeStamp& inStartTime, UInt32 inStartTimeFlags);
	virtual void				StopIOEngine();
	
	virtual void				StartHardware();
	virtual void				StopHardware();

	void						StartIOCycle();
	void						PreProcessInputData(const AudioTimeStamp& inInputTime);
	bool						ReadInputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID);
	void						PostProcessInputData(const AudioTimeStamp& inInputTime);
	void						PreProcessOutputData(const AudioTimeStamp& inOuputTime, HP_IOProc& inIOProc);
	bool						WriteOutputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID);
	void						FinishIOCycle();
	
	HP_IOThread*				mIOThread;

//	IO Cycle Telemetry Support
public:
	virtual UInt32				GetIOCycleNumber() const;

//	Time Management
public:
	virtual void				GetCurrentTime(AudioTimeStamp& outTime);
	virtual void				SafeGetCurrentTime(AudioTimeStamp& outTime);
	virtual void				TranslateTime(const AudioTimeStamp& inTime, AudioTimeStamp& outTime);
	virtual void				GetNearestStartTime(AudioTimeStamp& ioRequestedStartTime, UInt32 inFlags);
	
	virtual void				StartIOCycleTimingServices();
	virtual bool				UpdateIOCycleTimingServices();
	virtual void				StopIOCycleTimingServices();

private:
	UInt64						mAnchorHostTime;
	
//  Stream Management
private:
	void						CreateStreams();
	void						ReleaseStreams();
	void						RefreshAvailableStreamFormats();

//  Controls
protected:
	void						CreateControls();
	void						ReleaseControls();
	
	static bool					IsControlRelatedProperty(AudioObjectPropertySelector inSelector);

private:
	bool						mControlsInitialized;
	HP_DeviceControlProperty*	mControlProperty;

};

#endif
