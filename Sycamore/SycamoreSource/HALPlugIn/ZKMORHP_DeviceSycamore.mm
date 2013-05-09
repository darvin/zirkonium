//
//  ZKMORHP_DeviceSycamore.mm
//  Cushion
//
//  Created by C. Ramakrishnan on 29.02.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "ZKMORHP_DeviceSycamore.h"
//	Internal Includes
#include "ZKMORHP_Control.h"
#include "ZKMORHP_PlugIn.h"
#include "ZKMORHP_Stream.h"
#include "ZKMORHP_IOThreadSlave.h"

//	HPBase Includes
#include "HP_DeviceSettings.h"
#include "HP_HogMode.h"
#include "HP_IOCycleTelemetry.h"
#include "HP_IOProcList.h"
#include "HP_IOThread.h"

//	PublicUtility Includes
#include "CAAudioBufferList.h"
#include "CAAudioTimeStamp.h"
#include "CAAutoDisposer.h"
#include "CACFString.h"
#include "CADebugMacros.h"
#include "CAException.h"
#include "CAHostTimeBase.h"
#include "CALogMacros.h"
#include "CAMutex.h"

#define ZKMCNDebugPrintf printf
//#define ZKMCNDebugPrintf 


ZKMORHP_DeviceSycamore::ZKMORHP_DeviceSycamore(AudioDeviceID inAudioDeviceID, ZKMORHP_PlugIn* inPlugIn,  UInt32 numInputChannels, UInt32 numOutputChannels, CFStringRef deviceName, CFStringRef manuName, CFStringRef deviceUID, CFStringRef modelUID, CFStringRef defaultsDomain) 
	: ZKMORHP_Device(inAudioDeviceID, inPlugIn, numInputChannels, numOutputChannels, deviceName, manuName, deviceUID, modelUID),
	mWrappedDevice(0), mWrappedDeviceUID(NULL), mWrappedDeviceInputSafteyOffset(0), mWrappedDeviceOutputSafteyOffset(0), mWrappedDeviceBufferFrameSize(0),  mDefaultsDomain(defaultsDomain),
	mDeviceOutput(nil), mGraph(nil), mMixerMatrix(nil), mConduitShim(nil),
	mDeviceInput(nil), mInputRenderFunction(NULL)
{

}

ZKMORHP_DeviceSycamore::~ZKMORHP_DeviceSycamore() 
{ 
	if (mWrappedDeviceUID) CFRelease(mWrappedDeviceUID);
	if (mDeviceOutput) [mDeviceOutput release];	
}

void	ZKMORHP_DeviceSycamore::GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const
{
	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(const_cast<ZKMORHP_DeviceSycamore*>(this)->GetStateMutex());
			
	switch(inAddress.mSelector)
	{
		case kAudioDevicePropertyLatency:
		case kAudioDevicePropertyBufferFrameSize:
		case kAudioDevicePropertyBufferFrameSizeRange:
		case kAudioDevicePropertyUsesVariableBufferFrameSizes:
		case kAudioDevicePropertySafetyOffset:
		case kAudioDevicePropertyNominalSampleRate:
		case kAudioDevicePropertyAvailableNominalSampleRates:
		case kAudioDevicePropertyActualSampleRate:
		case kAudioDevicePropertyIOCycleUsage:
		{
			bool isInput = inAddress.mScope == kAudioDevicePropertyScopeInput;
				// initialize the wrapped device, if necessary
			if (!IsWrappedDeviceInitialized()) const_cast<ZKMORHP_DeviceSycamore*>(this)->InitializeWrappedDevice();
			if (!mWrappedDevice) kAudioHardwareNotRunningError;
			OSStatus err;
			err = AudioDeviceGetProperty(mWrappedDevice, inAddress.mElement, isInput, inAddress.mSelector, &ioDataSize, outData);
		} break;

#pragma mark _____ Deprecated Properties
		case kAudioDevicePropertyBufferSize:
		{
				// initialize the wrapped device, if necessary
			if (!IsWrappedDeviceInitialized()) const_cast<ZKMORHP_DeviceSycamore*>(this)->InitializeWrappedDevice();
			// TODO: How do I return an error?
			if (!mWrappedDevice) kAudioHardwareNotRunningError;
			
			UInt32 bufferSizeInFrames = BufferSizeInFrames();
			CAStreamBasicDescription streamFormat;
			bool isInput = inAddress.mScope == kAudioDevicePropertyScopeInput;
			UInt32 numChannels = (isInput) ? mNumberOfInputChannels : mNumberOfOutputChannels;
			streamFormat.SetCanonical(numChannels, false); 
			*(UInt32*) outData = bufferSizeInFrames * streamFormat.mBytesPerFrame;
			ioDataSize = sizeof(UInt32);
		} break;
		case kAudioDevicePropertyBufferSizeRange:
		{
				// initialize the wrapped device, if necessary
			if (!IsWrappedDeviceInitialized()) const_cast<ZKMORHP_DeviceSycamore*>(this)->InitializeWrappedDevice();
			if (!mWrappedDevice) kAudioHardwareNotRunningError;
			
			AudioValueRange bufferSizeRangeInFrames = BufferSizeRangeInFrames();
			CAStreamBasicDescription streamFormat;
			bool isInput = inAddress.mScope == kAudioDevicePropertyScopeInput;
			UInt32 numChannels = (isInput) ? mNumberOfInputChannels : mNumberOfOutputChannels;
			streamFormat.SetCanonical(numChannels, false); 
			((AudioValueRange*) outData)->mMinimum = bufferSizeRangeInFrames.mMinimum * streamFormat.mBytesPerFrame;
			((AudioValueRange*) outData)->mMaximum = bufferSizeRangeInFrames.mMaximum * streamFormat.mBytesPerFrame;
			ioDataSize = sizeof(AudioValueRange);
		} break;
	
		default:
			ZKMORHP_Device::GetPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
			break;
	};
}

void	ZKMORHP_DeviceSycamore::SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen)
{
	switch(inAddress.mSelector)
	{
		case kAudioDevicePropertyIOCycleUsage:
        case kAudioDevicePropertyAvailableNominalSampleRates:
		case kAudioDevicePropertyNominalSampleRate:
		case kAudioDevicePropertyActualSampleRate:
		{
			bool isInput = inAddress.mScope == kAudioDevicePropertyScopeInput;
			
					// initialize the wrapped device, if necessary
			if (!IsWrappedDeviceInitialized()) const_cast<ZKMORHP_DeviceSycamore*>(this)->InitializeWrappedDevice();
			// TODO: How do I return an error?
			if (!mWrappedDevice) kAudioHardwareNotRunningError;

				OSStatus err;
				err = AudioDeviceSetProperty(mWrappedDevice, inWhen, inAddress.mElement, isInput, inAddress.mSelector, inDataSize, inData);
				
				CAPropertyAddress theAddress(kAudioDevicePropertyIOCycleUsage, kAudioObjectPropertyScopeGlobal, 0);
				PropertiesChanged(1, &theAddress);
		} break;
			
		default:
			ZKMORHP_Device::SetPropertyData(inAddress, inQualifierDataSize, inQualifierData, inDataSize, inData, inWhen);
			break;
	};
}

UInt32	ZKMORHP_DeviceSycamore::GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const
{
    UInt32 theAnswer = 0;
    
    switch (inAddress.mSelector)
    {
        case kAudioDevicePropertyAvailableNominalSampleRates:
            AudioObjectGetPropertyDataSize(mWrappedDevice, &inAddress, inQualifierDataSize, inQualifierData, &theAnswer);
            break;
        default:
            theAnswer = ZKMORHP_Device::GetPropertyDataSize(inAddress, inQualifierDataSize, inQualifierData);
            break;
    }
    
    return theAnswer;
}

bool	ZKMORHP_DeviceSycamore::CanBeDefaultDevice(bool inIsInput, bool inIsSystem) const
{
	// I can be a default device, but not a system device
	return !inIsSystem;
}

void	ZKMORHP_DeviceSycamore::Do_StartIOProc(AudioDeviceIOProc inProc)
{
	//	start
	ZKMORHP_Device::Do_StartIOProc(inProc);
}

void	ZKMORHP_DeviceSycamore::Do_StartIOProcAtTime(AudioDeviceIOProc inProc, AudioTimeStamp& ioStartTime, UInt32 inStartTimeFlags)
{
	//	start
	ZKMORHP_Device::Do_StartIOProcAtTime(inProc, ioStartTime, inStartTimeFlags);
}

void	ZKMORHP_DeviceSycamore::StartHardware()
{
	InitializeDeviceOutput();
	StartWrappedDevice();
}

void	ZKMORHP_DeviceSycamore::StopHardware()
{
	StopWrappedDevice();
	GetIOThread()->GetForeignThread().ExternalStop();
}

void	ZKMORHP_DeviceSycamore::CopyOutputData(AudioBufferList *ioData)
{
	// iterate over the IOProcs and sum into the output buffer list
	UInt32 i, count = mIOProcList->GetNumberIOProcs();
	for(i = 0; i < count; ++i) {
		HP_IOProc* proc = mIOProcList->GetIOProcByIndex(i);
		if (!proc || !(proc->IsEnabled())) continue;
		// sum into the buffer list
		AudioBufferList* abl = proc->GetAudioBufferList(false);
        
        if (abl != NULL)
            CAAudioBufferList::Sum(*abl, *ioData);
        else
            NSLog(@"NULL AudioBufferList encountered -- is this a bug?");
	}
}

bool	ZKMORHP_DeviceSycamore::ReadInputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID)
{
	ReadInputFromWrappedDevice(&inStartTime, GetIOBufferFrameSize());
	return true;
}

bool	ZKMORHP_DeviceSycamore::WriteOutputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID)
{
	GetIOCycleTelemetry().IOCycleOutputWriteBegin(GetIOCycleNumber(), inStartTime);
	
	GetIOCycleTelemetry().IOCycleOutputWriteEnd(GetIOCycleNumber(), 0);
	return true;
}

void		ZKMORHP_DeviceSycamore::ReadWrappedDeviceUID()
{
	if (NULL == mWrappedDeviceUID)  {
		mWrappedDeviceUID = (CFStringRef) CFPreferencesCopyAppValue(CFSTR("Device"), mDefaultsDomain);
	}
}

bool		ZKMORHP_DeviceSycamore::IsWrappedDeviceInitialized() const { return mWrappedDevice != 0; }

void		ZKMORHP_DeviceSycamore::InitializeWrappedDevice()
{
	ReadWrappedDeviceUID();
	if (!mWrappedDeviceUID) return;
	
	CFStringRef uid = mWrappedDeviceUID;
	
	AudioDeviceID wrappedID;
	AudioValueTranslation value = { &uid, sizeof(CFStringRef), &wrappedID, sizeof(AudioDeviceID) };
	UInt32 valueSize = sizeof(AudioValueTranslation);
	OSStatus reterr = AudioHardwareGetProperty(kAudioHardwarePropertyDeviceForUID, &valueSize, &value);
	if (noErr != reterr) return;

	mWrappedDevice = wrappedID;
	
	valueSize = sizeof(UInt32);
		// initialize the safety offsets
	AudioDeviceGetProperty(mWrappedDevice, 0, true, kAudioDevicePropertySafetyOffset, &valueSize, &mWrappedDeviceInputSafteyOffset);
	valueSize = sizeof(UInt32);
	AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertySafetyOffset, &valueSize, &mWrappedDeviceOutputSafteyOffset);
	
	valueSize = sizeof(UInt32);
	AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyBufferFrameSize, &valueSize, &mWrappedDeviceBufferFrameSize);
	
	RefreshAvailableStreamFormats();
}

void		ZKMORHP_DeviceSycamore::InitializeDeviceOutput() 
{
	if (!mWrappedDeviceUID) return;
	if (!mWrappedDevice) return;
	if (!IsAlive()) return;
	
	ZKMORAudioHardwareSystem* ahs = [ZKMORAudioHardwareSystem sharedAudioHardwareSystem];
	mDeviceOutput = [[ZKMORDeviceOutput alloc] init];
	UInt32 startTimestampsAtZero = 0;
	UInt32 dataSize = sizeof(UInt32);
	AudioUnitSetProperty([[mDeviceOutput outputUnit] audioUnit], kAudioOutputUnitProperty_StartTimestampsAtZero, kAudioUnitScope_Global, 0, &startTimestampsAtZero, dataSize);
	ZKMORAudioDevice* device = [ahs audioDeviceForDeviceID: mWrappedDevice];
	NSError* error = nil;
	mGraph = [[ZKMORGraph alloc] init];
	mMixerMatrix = [[ZKMORMixerMatrix alloc] init];
	mConduitShim = [[ZKMORDeviceShim alloc] initWithImpl: this];
	
	PatchOutputGraph();
	
	[mDeviceOutput setGraph: mGraph];
	[mMixerMatrix setToCanonicalLevels];

		// pass ownership of everything to the device output
	[mGraph release];
	[mMixerMatrix release];
	[mConduitShim release];

	[mDeviceOutput setOutputDevice: device error: &error];
	if (error) { 
		ZKMCNDebugPrintf("setOutputDevice failed\n"); 
	}
	
	mSampleRate = [mGraph graphSampleRate];
	if ([mDeviceOutput isInputEnabled]) {
		mDeviceInput = [mDeviceOutput deviceInput];
		CAStreamBasicDescription streamFormat([[mDeviceInput outputBusAtIndex: 0] streamFormat]);
		streamFormat.ChangeNumberChannels(mNumberOfInputChannels, false);
		[mDeviceInput uninitialize];
		[[mDeviceInput outputBusAtIndex: 0] setStreamFormat: streamFormat];
		[mDeviceInput initialize];
		
		mInputRenderFunction = [mDeviceInput renderFunction];
	} else {
		CAStreamBasicDescription streamFormat([[[mDeviceOutput outputUnit] inputBusAtIndex: 0] streamFormat]);
		streamFormat.ChangeNumberChannels(mNumberOfInputChannels, false);
	}

//	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, false, kAudioDevicePropertyDeviceHasChanged);
}

void		ZKMORHP_DeviceSycamore::StartWrappedDevice()
{
	// the running state changed, take action
	[mDeviceOutput start];
}

void		ZKMORHP_DeviceSycamore::StopWrappedDevice()
{
	// the running state changed, take action
	[mDeviceOutput stop];
}

void	ZKMORHP_DeviceSycamore::ReadInputFromWrappedDevice(const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames)
{
	GetIOCycleTelemetry().IOCycleInputReadBegin(GetIOCycleNumber(), *inTimeStamp);
	AudioUnitRenderActionFlags inputRenderFlags = 0;
	AudioBufferList* abl = mIOProcList->GetSharedAudioBufferList(true);

	OSErr err = noErr;
		// grab input from the device
	if (mDeviceInput) {
		// if mDeviceInput is defined, so is mInputRenderFunction
		err = mInputRenderFunction(mDeviceInput, &inputRenderFlags, inTimeStamp, 0, inNumberFrames, abl);
	} else {
		ZKMORMakeBufferListSilent(abl, &inputRenderFlags);
	}
	GetIOCycleTelemetry().IOCycleInputReadEnd(GetIOCycleNumber(), err);
}

void		ZKMORHP_DeviceSycamore::SetNumberOfChannels(unsigned numberOfInputs, unsigned numberOfOutputs)
{
	bool haveGraph = mGraph != NULL;
	if (haveGraph) [mGraph beginPatching];
//	ZKMORHP_Device::SetNumberOfChannels(numberOfInputs, numberOfOutputs);
	if (haveGraph) {
		[mMixerMatrix uninitialize];
		[mConduitShim uninitialize];
		[mDeviceInput uninitialize];
		PatchOutputGraph();
		[mGraph endPatching];
		[mMixerMatrix setToCanonicalLevels];
	}
}


void		ZKMORHP_DeviceSycamore::PatchOutputGraph()
{	
	[mGraph beginPatching];
		[mGraph setHead: mMixerMatrix];
		[[mConduitShim outputBusAtIndex: 0] setNumberOfChannels: mNumberOfOutputChannels];
		[[mMixerMatrix inputBusAtIndex: 0] setNumberOfChannels: mNumberOfOutputChannels];
		[mGraph patchBus: [mConduitShim outputBusAtIndex: 0] into: [mMixerMatrix inputBusAtIndex: 0]];
		[mGraph initialize];
	[mGraph endPatching];
}

UInt32				ZKMORHP_DeviceSycamore::BufferSizeInFrames() const
{	
	UInt32 bufferSize;
	UInt32 dataSize = sizeof(UInt32);
	if (mWrappedDevice)
		AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyBufferFrameSize, &dataSize, &bufferSize);
	else
		bufferSize = 512;
	return bufferSize;
}

AudioValueRange		ZKMORHP_DeviceSycamore::BufferSizeRangeInFrames() const
{
	AudioValueRange bufferSizeRange;
	UInt32 dataSize = sizeof(AudioValueRange);
	if (mWrappedDevice)
		AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyBufferFrameSizeRange, &dataSize, &bufferSizeRange);
	else
		bufferSizeRange.mMinimum = 512.0;
		bufferSizeRange.mMaximum = 512.0;
	return bufferSizeRange;
}

Float64				ZKMORHP_DeviceSycamore::GetSampleRate() const
{
	Float64 sampleRate;
	UInt32 dataSize = sizeof(Float64);
	if (mWrappedDevice)
		AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyNominalSampleRate, &dataSize, &sampleRate);
	else
		sampleRate = 44100.;
	return sampleRate;
}

void	ZKMORHP_DeviceSycamore::GetCurrentTime(AudioTimeStamp& outTime)
{
	ThrowIf(!IsIOEngineRunning(), CAException(kAudioHardwareNotRunningError), "ZKMORHP_DeviceSycamore::GetCurrentTime: can't because the engine isn't running");
	
	if (mWrappedDevice) AudioDeviceGetCurrentTime(mWrappedDevice, &outTime);
}

void	ZKMORHP_DeviceSycamore::TranslateTime(const AudioTimeStamp& inTime, AudioTimeStamp& outTime)
{
	//	the input time stamp has to have at least one of the sample or host time valid
	ThrowIf((inTime.mFlags & kAudioTimeStampSampleHostTimeValid) == 0, CAException(kAudioHardwareIllegalOperationError), "ZKMORHP_Device::TranslateTime: have to have either sample time or host time valid on the input");
	ThrowIf(!IsIOEngineRunning(), CAException(kAudioHardwareNotRunningError), "ZKMORHP_Device::TranslateTime: can't because the engine isn't running");

	if (mWrappedDevice) AudioDeviceTranslateTime(mWrappedDevice, &inTime, &outTime);
}

#pragma mark _____ ZKMORConduitShim
OSStatus ZKMORDeviceShimCallback(	id							SELF,
									AudioUnitRenderActionFlags 	* ioActionFlags,
									const AudioTimeStamp 		* inTimeStamp,
									UInt32						inOutputBusNumber,
									UInt32						inNumberFrames,
									AudioBufferList				* ioData)
{
	// TODO -- Is clearing necessary?
	// clear out the buffer first
	AudioUnitRenderActionFlags junkActionFlags;
	ZKMORMakeBufferListSilent(ioData, &junkActionFlags);
	// call into the plug in
	ZKMORHP_DeviceSycamore* device = ((ZKMORDeviceShim*) SELF)->mPlugInImpl;

	ZKMORHP_ForeignThread& thread = device->GetIOThread()->GetForeignThread();
	thread.InitializeIfNecessary();
	thread.RunIteration();
	device->CopyOutputData(ioData);
	return noErr;
}


@implementation ZKMORDeviceShim

- (id)initWithImpl:(ZKMORHP_DeviceSycamore *)plugInImpl
{
	if (!(self = [super init])) return nil;
	mPlugInImpl = plugInImpl;
	_conduitType = kZKMORConduitType_Source;
	
	return self;
}

- (unsigned)numberOfInputBuses { return 0; }
- (BOOL)isNumberOfInputBusesSettable { return NO; }
- (unsigned)numberOfOutputBuses { return 1; }
- (BOOL)isNumberOfOutputBusesSettable { return NO; }

- (ZKMORRenderFunction)renderFunction { return ZKMORDeviceShimCallback; }

@end

