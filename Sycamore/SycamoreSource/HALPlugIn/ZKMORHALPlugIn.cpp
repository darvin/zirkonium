/*
 *  ZKMORHALPlugIn.cpp
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 26.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "ZKMORHALPlugIn.h"

#include "CAAudioHardwareSystem.h"
#include "CAStreamBasicDescription.h"

#pragma mark _____ Global Functions / Data
ZKMORHALPlugInImpl* ZKMORHALPlugInImpl::GetPlugInImpl(AudioHardwarePlugInRef plugIn)
{
	return reinterpret_cast<ZKMORHALPlugIn*>(plugIn)->mPlugInImpl;
}

//  Assumes the sample time is valid and is obtained directly from the device
static OSStatus ZKMORSynchTimeStampToDevice(const CAAudioTimeStamp& reference, CAAudioTimeStamp& timeStamp, AudioDeviceID deviceID)
{
	CAAudioTimeStamp changed = timeStamp;
//	changed.mFlags = kAudioTimeStampSampleTimeValid;
		// we want to synch the host time and sample time
	timeStamp.mFlags |= (kAudioTimeStampHostTimeValid | kAudioTimeStampSampleTimeValid);
	return AudioDeviceTranslateTime(deviceID, &changed, &timeStamp);
}

#pragma mark _____ CTOR / DTOR
ZKMORHALPlugInImpl::ZKMORHALPlugInImpl(AudioHardwarePlugInRef plugIn) : mPlugIn(plugIn), mNumberOfInputChannels(2), mNumberOfOutputChannels(2), mSampleRate(44100.0), mRunningIOProcCount(0), mIsInitialized(false), mDeviceID(0), mOutputStreamIDs(NULL), mInputStreamIDs(NULL), mWrappedDevice(0), mWrappedDeviceInputSafteyOffset(0), mWrappedDeviceOutputSafteyOffset(0), mWrappedDeviceBufferFrameSize(0), mWrappedDeviceUID(NULL), mDeviceName(NULL), mDeviceManu(NULL), mDeviceUID(NULL), mModelUID(NULL), mConfigApplication(NULL), mDefaultsDomain(NULL),
	mInputBL(NULL)
{

}

ZKMORHALPlugInImpl::~ZKMORHALPlugInImpl()
{
	if (mOutputStreamIDs) free(mOutputStreamIDs);
	if (mInputStreamIDs) free(mInputStreamIDs);	
	if (mWrappedDeviceUID) CFRelease(mWrappedDeviceUID);
	if (mInputBL) delete mInputBL;
}

OSStatus	ZKMORHALPlugInImpl::RenderClients(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames, AudioBufferList *ioData)
{
	// set up the timestamps for rendering
	CAAudioTimeStamp outputTime(*inTimeStamp);
	
		// now is current time and get the sample time from the device
	CAAudioTimeStamp now(AudioGetCurrentHostTime());
	OSStatus err = ZKMORSynchTimeStampToDevice(outputTime, now, mWrappedDevice);
	if (err) ZKMCNDebugPrintf("Could not synth time stamp %4.4s\n", &err);
	
		// decrement the sample time for the input and get a host time from the device
		// the input time calculation comes from an email from Jeff Moore
	CAAudioTimeStamp inputTime(outputTime.mSampleTime - (mWrappedDeviceInputSafteyOffset + mWrappedDeviceOutputSafteyOffset + 2 * mWrappedDeviceBufferFrameSize));
	err = ZKMORSynchTimeStampToDevice(now, inputTime, mWrappedDevice);
	if (err) ZKMCNDebugPrintf("Could not synch time stamp %4.4s\n", &err);
	
	// silence the buffer to start with
	// ZKMORMakeBufferListSilent -- can't call this function because I don't want to include ZKMORConduit here
	unsigned numBuffers = ioData->mNumberBuffers;
	unsigned i;
	for (i = 0; i < numBuffers; i++) {
		memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
	}
	
//	ReadInputFromWrappedDevice(&inputTime, inNumberFrames);
	ReadInputFromWrappedDevice(&outputTime, inNumberFrames);
	
	ZKMORIOProcMap::iterator procs = mIOProcs.begin();
	ZKMORIOProcMap::iterator end = mIOProcs.end();
	UInt32 numProcsRendered = 0;
	while (procs != end) {
		IOProcState state = (*procs).second;
		if(state.mIsRunning) {
				// need to read data from the device...
			err = state.mProc(mDeviceID, &now, mInputBL->ABL(), &inputTime, ioData, &outputTime, state.mRefCon);
			if (err) {
				ZKMCNDebugPrintf("Error rendering client %u / %4.4s\n", err, &err);
				ZKMCNDebugPrintf("\tABL {%u {%u %u}}\n", mInputBL->ABL()->mNumberBuffers, mInputBL->ABL()->mBuffers[0].mNumberChannels, mInputBL->ABL()->mBuffers[0].mDataByteSize);				
			}
		}
		++procs; ++numProcsRendered;
	}

	return noErr;
}

OSStatus	ZKMORHALPlugInImpl::Initialize()
{
    OSStatus err = kAudioHardwareNoError;

    UInt32 theSize = 0;
    UInt32 outData = 0;
    err = AudioHardwareGetPropertyInfo(kAudioHardwarePropertyProcessIsMaster, &theSize, NULL);
    err = AudioHardwareGetProperty(kAudioHardwarePropertyProcessIsMaster, &theSize, &outData);

    err = AudioHardwareClaimAudioDeviceID(mPlugIn, &mDeviceID);
	if (err != kAudioHardwareNoError) return err;
	
    err = AudioHardwareDevicesCreated(mPlugIn, 1, &mDeviceID);
	if (err != kAudioHardwareNoError) {
		return err;
	}
	
	err = CreateStreams();
	if (err) return err;

	mIsInitialized = true;
	
	//  Can't initialize the wrapped device here because the HAL is still constructing the
	//  device list. See below.
//	InitializeWrappedDevice();

    return err;
}

OSStatus	ZKMORHALPlugInImpl::Teardown()
{
	if (mIsInitialized) {
		OSStatus err = DestroyStreams();
		err = AudioHardwareDevicesDied(mPlugIn, 1, &mDeviceID);
		mDeviceID = 0;
	} else {
	
	}
    return kAudioHardwareNoError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceAddIOProc(AudioDeviceID inDevice, AudioDeviceIOProc proc, void* data)
{
	if (inDevice != mDeviceID) return kAudioHardwareBadDeviceError;
	
	mIOProcs[proc] = IOProcState(proc, data);
	return kAudioHardwareNoError;
} 

OSStatus	ZKMORHALPlugInImpl::DeviceRemoveIOProc(AudioDeviceID inDevice, AudioDeviceIOProc proc)
{
	if (inDevice != mDeviceID) return kAudioHardwareBadDeviceError;
	if (mIOProcs.find(proc) == mIOProcs.end()) return kAudioHardwareNoError;
	
	mIOProcs.erase(mIOProcs.find(proc));
	
	return kAudioHardwareNoError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceStart(AudioDeviceID inDevice, AudioDeviceIOProc proc)
{
	if (inDevice != mDeviceID) return kAudioHardwareBadDeviceError;
	
	if (NULL == proc) {
		IncrementRunningIOProcCount();
		return kAudioHardwareNoError;
	}
	
	ZKMORIOProcMap::iterator pos = mIOProcs.find(proc);
	if (pos == mIOProcs.end()) return paramErr;
	
	if (!(*pos).second.mIsRunning) {
		(*pos).second.mIsRunning = true;
		IncrementRunningIOProcCount();
	}
	
	return kAudioHardwareNoError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceStop(AudioDeviceID inDevice, AudioDeviceIOProc proc)
{
	if (inDevice != mDeviceID) return kAudioHardwareBadDeviceError;
	if (NULL == proc) {
		DecrementRunningIOProcCount();
		return kAudioHardwareNoError;
	}
	
	ZKMORIOProcMap::iterator pos = mIOProcs.find(proc);
	if (pos == mIOProcs.end()) return paramErr;
	
	if ((*pos).second.mIsRunning) {
		(*pos).second.mIsRunning = false;
		DecrementRunningIOProcCount();
	}
	
	return kAudioHardwareNoError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceRead(AudioDeviceID inDevice, const AudioTimeStamp* inStartTime, AudioBufferList* outData)
{
//	return (mWrappedDevice) ? AudioDeviceRead(mWrappedDevice, inStartTime, outData) : kAudioHardwareNotRunningError;
	OSStatus err = (mWrappedDevice) ? AudioDeviceRead(mWrappedDevice, inStartTime, outData) : kAudioHardwareNotRunningError;
	if (err) ZKMCNDebugPrintf("DeviceRead Error %4.4s\n", &err);
	return err;
}

OSStatus	ZKMORHALPlugInImpl::DeviceGetCurrentTime(AudioDeviceID inDevice, AudioTimeStamp* outTime)
{
	return (mWrappedDevice) ? AudioDeviceGetCurrentTime(mWrappedDevice, outTime) : kAudioHardwareNotRunningError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceTranslateTime(AudioDeviceID inDevice, const AudioTimeStamp* inTime, AudioTimeStamp* outTime)
{
	return (mWrappedDevice) ? AudioDeviceTranslateTime(mWrappedDevice, inTime, outTime) : kAudioHardwareNotRunningError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceGetPropertyInfo(AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable)
{	
	OSStatus err = kAudioHardwareNoError;
	if (inDevice != mDeviceID) {
		ZKMCNDebugPrintf("Get property info for device 0x%X (I am 0x%X)\n", inDevice, mDeviceID);
		return kAudioHardwareBadDeviceError;
	}
		// Most properties are not writeable. Overidden by the writable selectors.
	if (outWritable != NULL) *outWritable = false;
	
	bool	isPropertySupportedDirectly = true;
	UInt32 numChannels = (isInput) ? mNumberOfInputChannels : mNumberOfOutputChannels;
	
	//  properties I support directly
	switch (inPropertyID) {
#pragma mark _____ AudioDevice Properties
		case kAudioDevicePropertyPlugIn:
			err = kAudioHardwareUnknownPropertyError;
			break;
		case kAudioDevicePropertyConfigurationApplication: 
			if (outSize) *outSize = sizeof(CFStringRef); 
			break;
		case kAudioDevicePropertyDeviceUID:
		case kAudioDevicePropertyModelUID:
			if (outSize) *outSize = sizeof(CFStringRef);
			break;
		case kAudioDevicePropertyTransportType: 
			if (outSize) *outSize = sizeof(UInt32); 
			break;
		case kAudioDevicePropertyRelatedDevices:
			if (outSize) *outSize = sizeof(AudioDeviceID);
//		case kAudioDevicePropertyClockDomain:
		case kAudioDevicePropertyDeviceIsAlive: 
			if (outSize) *outSize = sizeof(UInt32); 
			break;
//		case kAudioDevicePropertyDeviceHasChanged:
		case kAudioDevicePropertyDeviceIsRunning:
		case kAudioDevicePropertyDeviceIsRunningSomewhere:
			if (outSize) *outSize = sizeof(UInt32);
			break;
		case kAudioDevicePropertyDeviceCanBeDefaultDevice:
		case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
		case kAudioDeviceProcessorOverload:
			if (outSize) *outSize = sizeof(UInt32);
			break;
		case kAudioDevicePropertyHogMode: 
			if (outSize) *outSize = sizeof(pid_t); 
			break;
		case kAudioDevicePropertyStreams:
 			if (outSize) *outSize = sizeof(AudioStreamID) * numChannels;
			break;
		case kAudioDevicePropertyStreamConfiguration:
			if (outSize) *outSize = offsetof(AudioBufferList, mBuffers) + sizeof(AudioBuffer) * numChannels;
			break;
		case kAudioDevicePropertyIOProcStreamUsage:
			if (outSize) *outSize = offsetof(AudioHardwareIOProcStreamUsage, mStreamIsOn) + sizeof(UInt32) * numChannels;
			if (outWritable) *outWritable = true;
			break;
		case kAudioDevicePropertyPreferredChannelsForStereo:
			if (outSize) *outSize = sizeof(UInt32) * 2;
			break;
		case kAudioDevicePropertyPreferredChannelLayout:
			if (outSize) *outSize = offsetof(AudioChannelLayout, mChannelDescriptions) + sizeof(AudioChannelDescription) * numChannels;
			break;
#pragma mark _____ AudioControl Properties
			// don't support any of these
		case kAudioDevicePropertyJackIsConnected:
		case kAudioDevicePropertyVolumeScalar:
		case kAudioDevicePropertyVolumeDecibels:
		case kAudioDevicePropertyVolumeRangeDecibels:
		case kAudioDevicePropertyVolumeScalarToDecibels:
		case kAudioDevicePropertyVolumeDecibelsToScalar:
		case kAudioDevicePropertyStereoPan:
		case kAudioDevicePropertyStereoPanChannels:
		case kAudioDevicePropertyMute:
		case kAudioDevicePropertySolo:
		case kAudioDevicePropertyDataSource:
		case kAudioDevicePropertyDataSources:
		case kAudioDevicePropertyDataSourceNameForID:
		case kAudioDevicePropertyDataSourceNameForIDCFString:
		case kAudioDevicePropertyClockSource:
		case kAudioDevicePropertyClockSources:
		case kAudioDevicePropertyClockSourceNameForID:
		case kAudioDevicePropertyClockSourceNameForIDCFString:
		case kAudioDevicePropertyPlayThru:
		case kAudioDevicePropertyPlayThruSolo:
		case kAudioDevicePropertyPlayThruVolumeScalar:
		case kAudioDevicePropertyPlayThruVolumeDecibels:
		case kAudioDevicePropertyPlayThruVolumeRangeDecibels:
		case kAudioDevicePropertyPlayThruVolumeScalarToDecibels:
		case kAudioDevicePropertyPlayThruVolumeDecibelsToScalar:
		case kAudioDevicePropertyPlayThruStereoPan:
		case kAudioDevicePropertyPlayThruStereoPanChannels:
		case kAudioDevicePropertyPlayThruDestination:
		case kAudioDevicePropertyPlayThruDestinations:
		case kAudioDevicePropertyPlayThruDestinationNameForIDCFString:
		case kAudioDevicePropertyChannelNominalLineLevel:
		case kAudioDevicePropertyChannelNominalLineLevels:
		case kAudioDevicePropertyChannelNominalLineLevelNameForIDCFString:
		case kAudioDevicePropertyDriverShouldOwniSub:
		case kAudioDevicePropertySubVolumeScalar:
		case kAudioDevicePropertySubVolumeDecibels:
		case kAudioDevicePropertySubVolumeRangeDecibels:
		case kAudioDevicePropertySubVolumeScalarToDecibels:
		case kAudioDevicePropertySubVolumeDecibelsToScalar:
		case kAudioDevicePropertySubMute:
			err = kAudioHardwareUnknownPropertyError;
			break;
			
#pragma mark _____ Deprecated Properties
		case kAudioDevicePropertyDeviceName:
			if (outSize) *outSize = CFStringGetLength(mDeviceName) + 1;
			break;
		case kAudioDevicePropertyDeviceManufacturer:
			if (outSize) *outSize = CFStringGetLength(mDeviceManu) + 1;
			break;
		case kAudioDevicePropertyDeviceNameCFString:
		case kAudioDevicePropertyDeviceManufacturerCFString:
			if (outSize) *outSize = sizeof(CFStringRef);
			break;
		case kAudioDevicePropertyRegisterBufferList:
//			if (outSize) *outSize = 4 + sizeof(AudioBuffer) * (mNumberOfOutputChannels + mNumberOfInputChannels);
			err = kAudioHardwareUnknownPropertyError;
			break;
//		kAudioDevicePropertyChannelName
//		kAudioDevicePropertyChannelNameCFString
//		kAudioDevicePropertyChannelCategoryName
//		kAudioDevicePropertyChannelCategoryNameCFString
//		kAudioDevicePropertyChannelNumberName
//		kAudioDevicePropertyChannelNumberNameCFString
		case kAudioDevicePropertySupportsMixing:
			if (outSize) *outSize = sizeof(UInt32);
			break;
		case kAudioDevicePropertyStreamFormat:
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription);
			if (outWritable) *outWritable = true;
			break;
		case kAudioDevicePropertyStreamFormats: 
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription); 
			break;
		case kAudioDevicePropertyStreamFormatSupported:
		case kAudioDevicePropertyStreamFormatMatch:
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription);
			break;
		default:
			isPropertySupportedDirectly = false;
			break;
	}
	
	if (isPropertySupportedDirectly) {
		if (err && (kAudioHardwareUnknownPropertyError != err)) {
			fflush(stdout);
		}
		return err;
	};
	
	// initialize the wrapped device, if necessary
	if (!IsWrappedDeviceInitialized()) InitializeWrappedDevice();


	switch (inPropertyID) {
#pragma mark _____ AudioDevice Properties
		case kAudioDevicePropertyLatency: 
		case kAudioDevicePropertyBufferFrameSize:
		case kAudioDevicePropertyBufferFrameSizeRange: 
		case kAudioDevicePropertyUsesVariableBufferFrameSizes:
		case kAudioDevicePropertySafetyOffset:
//		case kAudioDevicePropertyIOCycleUsage:
		case kAudioDevicePropertyNominalSampleRate:
		case kAudioDevicePropertyAvailableNominalSampleRates: 
		case kAudioDevicePropertyActualSampleRate:

#pragma mark _____ Deprecated Properties
		case kAudioDevicePropertyBufferSize:
		case kAudioDevicePropertyBufferSizeRange:
		{
			err = AudioDeviceGetPropertyInfo(mWrappedDevice, inChannel, isInput, inPropertyID, outSize, outWritable);
			if (outWritable) *outWritable = false;
		} break;

		default:
		{
//			ZKMCNDebugPrintf("default: Get property info for device 0x%X : %4.4s\n", inDevice, &inPropertyID);
			err = kAudioHardwareUnknownPropertyError;
		} break;
	}

	if (err) {
		ZKMCNDebugPrintf("Get property info for device 0x%X (0x%X) : %4.4s : %4.4s\n", inDevice, mWrappedDevice, &inPropertyID, &err);
		fflush(stdout);
	}

	return err;
}

OSStatus	ZKMORHALPlugInImpl::DeviceGetProperty(AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData)
{
	OSStatus err = kAudioHardwareNoError;
	
	if (NULL == ioPropertyDataSize) return kAudioHardwareBadPropertySizeError;
	if (NULL == outPropertyData) {
		*ioPropertyDataSize = 0;
		return paramErr;
	}
	
	if (inDevice != mDeviceID) {
		ZKMCNDebugPrintf("Get property info for device 0x%X (I am 0x%X)\n", inDevice, mDeviceID);
		return kAudioHardwareBadDeviceError;
	}
	
	bool	isPropertySupportedDirectly = true;
	UInt32 numChannels = (isInput) ? mNumberOfInputChannels : mNumberOfOutputChannels;
	
	//  properties I support directly
	switch (inPropertyID) {
#pragma mark _____ AudioDevice Properties
		case kAudioDevicePropertyPlugIn:
			err = kAudioHardwareUnknownPropertyError;
			break;
		case kAudioDevicePropertyConfigurationApplication:
			if (*ioPropertyDataSize < sizeof(CFStringRef)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				CFStringRef* outString = (CFStringRef*) outPropertyData;
				*outString = CFStringCreateCopy(NULL, mConfigApplication);
				*ioPropertyDataSize = sizeof(CFStringRef);
			}
			break;
		case kAudioDevicePropertyDeviceUID:
			if (*ioPropertyDataSize < sizeof(CFStringRef)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				CFStringRef* outString = (CFStringRef*) outPropertyData;
				*outString = CFStringCreateCopy(NULL, mDeviceUID);
				*ioPropertyDataSize = sizeof(CFStringRef);
			}
			break;
		case kAudioDevicePropertyModelUID:
			if (*ioPropertyDataSize < sizeof(CFStringRef)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				CFStringRef* outString = (CFStringRef*) outPropertyData;
				*outString = CFStringCreateCopy(NULL, mModelUID);
				*ioPropertyDataSize = sizeof(CFStringRef);
			}
			break;
		case kAudioDevicePropertyTransportType:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*((UInt32*) outPropertyData) = kIOAudioDeviceTransportTypeOther;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioDevicePropertyRelatedDevices:
			if (*ioPropertyDataSize < sizeof(AudioDeviceID)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*((AudioDeviceID*) outPropertyData) = mDeviceID;
				*ioPropertyDataSize = sizeof(AudioDeviceID);
			}
			break;
//		case kAudioDevicePropertyClockDomain:
		case kAudioDevicePropertyDeviceIsAlive:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*((UInt32*) outPropertyData) = IsAlive();
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
			// don't need to implement
//		case kAudioDevicePropertyDeviceHasChanged:
		case kAudioDevicePropertyDeviceIsRunning:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*((UInt32*) outPropertyData) = IsRunning();
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioDevicePropertyDeviceIsRunningSomewhere:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*((UInt32*) outPropertyData) = IsRunning();
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioDevicePropertyDeviceCanBeDefaultDevice:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*(UInt32*) outPropertyData = true;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*(UInt32*) outPropertyData = false;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioDevicePropertyHogMode:
			if (*ioPropertyDataSize < sizeof(pid_t)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				pid_t* pid = (pid_t*) outPropertyData;
				*pid = -1;
				*ioPropertyDataSize = sizeof(pid_t);
			}
			break;
		case kAudioDevicePropertyStreams:
			AudioStreamID* streamID = (AudioStreamID*) outPropertyData;
			if (*ioPropertyDataSize < sizeof(AudioStreamID) * numChannels)
				err = kAudioHardwareBadPropertySizeError;
			else if (isInput) {
				*ioPropertyDataSize = sizeof(AudioStreamID) * mNumberOfInputChannels;
				memcpy(streamID, mInputStreamIDs, *ioPropertyDataSize);
			} else {
				*ioPropertyDataSize = sizeof(AudioStreamID) * mNumberOfOutputChannels;
				memcpy(streamID, mOutputStreamIDs, *ioPropertyDataSize);
			}
			break;
		case kAudioDevicePropertyStreamConfiguration: {
			UInt32 dataSize = offsetof(AudioBufferList, mBuffers) + sizeof(AudioBuffer) * numChannels;
			if (*ioPropertyDataSize < dataSize) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioBufferList* abl = (AudioBufferList*) outPropertyData;
				abl->mNumberBuffers = numChannels;

				for (unsigned int i = 0; i < abl->mNumberBuffers; i++) {
					abl->mBuffers[i].mNumberChannels = 1;
					abl->mBuffers[i].mDataByteSize = BufferSizeInFrames() * sizeof(float);
					abl->mBuffers[i].mData = NULL;
				}

				*ioPropertyDataSize = sizeof(UInt32) + sizeof(AudioBuffer) * dataSize;
			}
			break;
		}
		case kAudioDevicePropertyIOProcStreamUsage: {
			UInt32 dataSize = offsetof(AudioHardwareIOProcStreamUsage, mStreamIsOn) + sizeof(UInt32) * numChannels;
			if (*ioPropertyDataSize < dataSize) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioHardwareIOProcStreamUsage* outData = (AudioHardwareIOProcStreamUsage*) outPropertyData;
				outData->mNumberStreams = numChannels;
				for (unsigned int i = 0; i < outData->mNumberStreams; i++) outData->mStreamIsOn[i] = true;
				
				*ioPropertyDataSize = dataSize;
			}
			break;
		}
		case kAudioDevicePropertyPreferredChannelsForStereo:
			if (*ioPropertyDataSize < sizeof(UInt32) * 2) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				UInt32* channels = (UInt32*) outPropertyData;
				channels[0] = 1;
				channels[1] = 2;
				*ioPropertyDataSize = sizeof(UInt32) * 2;
			}
			break;
		case kAudioDevicePropertyPreferredChannelLayout:
			if (*ioPropertyDataSize < sizeof(AudioChannelLayout)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioChannelLayout *acl = (AudioChannelLayout*) outPropertyData;
				acl->mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelDescriptions;
				acl->mChannelBitmap = 0;
				acl->mNumberChannelDescriptions = mNumberOfOutputChannels;

				int channelLabel = kAudioChannelLabel_Left;

				for (int i = 0; i < mNumberOfOutputChannels; i++) {
					acl->mChannelDescriptions[i].mChannelLabel = channelLabel;
					channelLabel++;
				}

				*ioPropertyDataSize = sizeof(AudioChannelLayout);
			}
			break;
#pragma mark _____ AudioControl Properties
			// don't support any of these
		case kAudioDevicePropertyJackIsConnected:
		case kAudioDevicePropertyVolumeScalar:
		case kAudioDevicePropertyVolumeDecibels:
		case kAudioDevicePropertyVolumeRangeDecibels:
		case kAudioDevicePropertyVolumeScalarToDecibels:
		case kAudioDevicePropertyVolumeDecibelsToScalar:
		case kAudioDevicePropertyStereoPan:
		case kAudioDevicePropertyStereoPanChannels:
		case kAudioDevicePropertyMute:
		case kAudioDevicePropertySolo:
		case kAudioDevicePropertyDataSource:
		case kAudioDevicePropertyDataSources:
		case kAudioDevicePropertyDataSourceNameForID:
		case kAudioDevicePropertyDataSourceNameForIDCFString:
		case kAudioDevicePropertyClockSource:
		case kAudioDevicePropertyClockSources:
		case kAudioDevicePropertyClockSourceNameForID:
		case kAudioDevicePropertyClockSourceNameForIDCFString:
		case kAudioDevicePropertyPlayThru:
		case kAudioDevicePropertyPlayThruSolo:
		case kAudioDevicePropertyPlayThruVolumeScalar:
		case kAudioDevicePropertyPlayThruVolumeDecibels:
		case kAudioDevicePropertyPlayThruVolumeRangeDecibels:
		case kAudioDevicePropertyPlayThruVolumeScalarToDecibels:
		case kAudioDevicePropertyPlayThruVolumeDecibelsToScalar:
		case kAudioDevicePropertyPlayThruStereoPan:
		case kAudioDevicePropertyPlayThruStereoPanChannels:
		case kAudioDevicePropertyPlayThruDestination:
		case kAudioDevicePropertyPlayThruDestinations:
		case kAudioDevicePropertyPlayThruDestinationNameForIDCFString:
		case kAudioDevicePropertyChannelNominalLineLevel:
		case kAudioDevicePropertyChannelNominalLineLevels:
		case kAudioDevicePropertyChannelNominalLineLevelNameForIDCFString:
		case kAudioDevicePropertyDriverShouldOwniSub:
		case kAudioDevicePropertySubVolumeScalar:
		case kAudioDevicePropertySubVolumeDecibels:
		case kAudioDevicePropertySubVolumeRangeDecibels:
		case kAudioDevicePropertySubVolumeScalarToDecibels:
		case kAudioDevicePropertySubVolumeDecibelsToScalar:
		case kAudioDevicePropertySubMute:
			err = kAudioHardwareUnknownPropertyError;
			break;
#pragma mark _____ Deprecated Properties
		case kAudioDevicePropertyDeviceName:
			if (*ioPropertyDataSize < CFStringGetLength(mDeviceName) + 1) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				char* buffer = (char*) outPropertyData;
				CFStringGetCString(mDeviceName, buffer, *ioPropertyDataSize, kCFStringEncodingASCII);
				*ioPropertyDataSize = CFStringGetLength(mDeviceName) + 1;
			}
			break;
		case kAudioDevicePropertyDeviceManufacturer:
			if (*ioPropertyDataSize < CFStringGetLength(mDeviceManu) + 1) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				char* buffer = (char*) outPropertyData;
				CFStringGetCString(mDeviceName, buffer, *ioPropertyDataSize, kCFStringEncodingASCII);
				*ioPropertyDataSize = CFStringGetLength(mDeviceManu) + 1;
			}
			break;
		case kAudioDevicePropertyDeviceNameCFString:
			if (*ioPropertyDataSize < sizeof (CFStringRef)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				CFStringRef* outString = (CFStringRef*) outPropertyData;
				*outString = CFStringCreateCopy(NULL, mDeviceName);
				*ioPropertyDataSize = sizeof(CFStringRef);
			}
			break;
		case kAudioDevicePropertyDeviceManufacturerCFString:
			if (*ioPropertyDataSize < sizeof (CFStringRef)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				CFStringRef* outString = (CFStringRef*) outPropertyData;
				*outString = CFStringCreateCopy(NULL, mDeviceManu);
				*ioPropertyDataSize = sizeof(CFStringRef);
			}
			break;
//		kAudioDevicePropertyChannelName
//		kAudioDevicePropertyChannelNameCFString
//		kAudioDevicePropertyChannelCategoryName
//		kAudioDevicePropertyChannelCategoryNameCFString
//		kAudioDevicePropertyChannelNumberName
//		kAudioDevicePropertyChannelNumberNameCFString			
		case kAudioDevicePropertySupportsMixing:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*(UInt32*) outPropertyData = false;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioDevicePropertyStreamFormat:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription *) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(numChannels, false); 
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
			break;
		case kAudioDevicePropertyStreamFormats: 
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription *) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(numChannels, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
			break;
		case kAudioDevicePropertyStreamFormatSupported:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription *) outPropertyData;
				CAStreamBasicDescription proposedStreamFormat(*absd);
				bool isSupported = proposedStreamFormat.NumberChannels() == (isInput) ? mNumberOfInputChannels : mNumberOfOutputChannels;
				isSupported = isSupported & proposedStreamFormat.IsPCM();
				isSupported = isSupported & !(proposedStreamFormat.IsInterleaved());
				isSupported = isSupported & proposedStreamFormat.mSampleRate == mSampleRate;
				if (!isSupported) err = kAudioDeviceUnsupportedFormatError;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
		case kAudioDevicePropertyStreamFormatMatch:
			err = kAudioHardwareUnknownPropertyError;
			break;

		default:
			isPropertySupportedDirectly = false;
			break;
	}
	
	if (isPropertySupportedDirectly) {
		if (err && (err != kAudioHardwareUnknownPropertyError)) {
			ZKMCNDebugPrintf("Get supported property for device 0x%X : %4.4s\n", inDevice, &inPropertyID);
			fflush(stdout);
		}
		return err;
	};
	
	// initialize the wrapped device, if necessary
	if (!IsWrappedDeviceInitialized()) InitializeWrappedDevice();
	if (!mWrappedDevice) kAudioHardwareNotRunningError;


	switch (inPropertyID) {
#pragma mark _____ AudioDevice Properties
		case kAudioDevicePropertyLatency:
		case kAudioDevicePropertyBufferFrameSize:
		case kAudioDevicePropertyBufferFrameSizeRange:
		case kAudioDevicePropertyUsesVariableBufferFrameSizes:
		case kAudioDevicePropertySafetyOffset:
		case kAudioDevicePropertyNominalSampleRate:
		case kAudioDevicePropertyAvailableNominalSampleRates:
		case kAudioDevicePropertyActualSampleRate:
		{
			err = AudioDeviceGetProperty(mWrappedDevice, inChannel, isInput, inPropertyID, ioPropertyDataSize, outPropertyData);
		} break;

#pragma mark _____ Deprecated Properties
		case kAudioDevicePropertyBufferSize:
		{
			UInt32 bufferSizeInFrames = BufferSizeInFrames();
			CAStreamBasicDescription streamFormat;
			streamFormat.SetCanonical(numChannels, false); 
			*(UInt32*) outPropertyData = bufferSizeInFrames * streamFormat.mBytesPerFrame;
			*ioPropertyDataSize = sizeof(UInt32);
		} break;
		case kAudioDevicePropertyBufferSizeRange:
		{
			AudioValueRange bufferSizeRangeInFrames = BufferSizeRangeInFrames();
			CAStreamBasicDescription streamFormat;
			streamFormat.SetCanonical(numChannels, false); 
			((AudioValueRange*) outPropertyData)->mMinimum = bufferSizeRangeInFrames.mMinimum * streamFormat.mBytesPerFrame;
			((AudioValueRange*) outPropertyData)->mMaximum = bufferSizeRangeInFrames.mMaximum * streamFormat.mBytesPerFrame;
			*ioPropertyDataSize = sizeof(AudioValueRange);
		} break;

		default:
			err = kAudioHardwareUnknownPropertyError;
			break;
	}
	

	if (err) {
		ZKMCNDebugPrintf("Get unsupported property for device 0x%X : %4.4s\n", inDevice, &inPropertyID);
		fflush(stdout);
	}
	return err;
}

OSStatus	ZKMORHALPlugInImpl::DeviceSetProperty(AudioDeviceID inDevice, const AudioTimeStamp* inWhen, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData)
{
    OSStatus err = kAudioHardwareNoError;
	
	if (inDevice != mDeviceID) {
		ZKMCNDebugPrintf("Get property info for device 0x%X (I am 0x%X)\n", inDevice, mDeviceID);
		return kAudioHardwareBadDeviceError;
	}

	switch (inPropertyID) {
		case kAudioDevicePropertyIOProcStreamUsage:
				// ignore
			break;

		default:
			err = kAudioHardwareUnknownPropertyError;
			break;
	}
	
	if (err) {
		ZKMCNDebugPrintf("Set property for device 0x%X : %4.4s\n", inDevice, &inPropertyID);
		fflush(stdout);
	}
	
	return err;
}

OSStatus	ZKMORHALPlugInImpl::StreamGetPropertyInfo(AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable)
{

	OSStatus err = kAudioHardwareNoError;
	SInt32 i, streamIndex = -1;
	bool isInput = false;
	for (i = 0; i < mNumberOfOutputChannels; ++i) {
		if (inStream == mOutputStreamIDs[i]) {
			streamIndex = i; isInput = false; break;
		}
	}
	for (i = 0; i < mNumberOfInputChannels; ++i) {
		if (inStream == mInputStreamIDs[i]) {
			streamIndex = i; isInput = true; break;
		}
	}
	if (streamIndex < 0) return kAudioHardwareBadStreamError;
	
		// Most properties are not writeable. Overidden by the writable selectors.
	if (outWritable != NULL) *outWritable = false;
	
	bool isPropertySupported = true;

	switch (inPropertyID) {
#pragma mark _____ AudioObject Properties
		case kAudioObjectPropertyName: 
			if (outSize) *outSize = sizeof(CFStringRef); 
			break;
#pragma mark _____ AudioControl Properties
			// don't support jacks or data sources
		case kAudioDevicePropertyJackIsConnected:
		case kAudioDevicePropertyDataSource:
			err = kAudioHardwareUnknownPropertyError;
			break;
#pragma mark _____ AudioDevice Deprecated Properties
		case kAudioDevicePropertyStreamFormats: 
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription); 
			break;
#pragma mark _____ AudioStream Properties
		case kAudioStreamPropertyDirection: 
		case kAudioStreamPropertyTerminalType:
		case kAudioStreamPropertyStartingChannel:
		case kAudioStreamPropertyLatency: 
			if (outSize) *outSize = sizeof(UInt32); 
			break;		
		case kAudioStreamPropertyVirtualFormat:
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription);
			if (outWritable) *outWritable = true;
			break;
		case kAudioStreamPropertyAvailableVirtualFormats:
			if (outSize) *outSize = sizeof(AudioStreamRangedDescription);
			break;
		case kAudioStreamPropertyPhysicalFormat: 
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription);
			if (outWritable) *outWritable = true;
			break;
		case kAudioStreamPropertyAvailablePhysicalFormats:
			if (outSize) *outSize = sizeof(AudioStreamRangedDescription);
			break;
#pragma mark _____ AudioStream Deprecated
		case kAudioStreamPropertyOwningDevice:
			if (outSize) *outSize = sizeof(AudioObjectID);
			break;
		case kAudioStreamPropertyPhysicalFormats:
		case kAudioStreamPropertyPhysicalFormatSupported:
		case kAudioStreamPropertyPhysicalFormatMatch:
			if (outSize) *outSize = sizeof(AudioStreamBasicDescription);
			break;
		default:
			err = kAudioHardwareUnknownPropertyError;
			isPropertySupported = false;
			break;
	}
	
	if (err && !isPropertySupported) {
		fflush(stdout);
	}
	return err;
}

OSStatus	ZKMORHALPlugInImpl::StreamGetProperty(AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData)
{
    OSStatus err = kAudioHardwareNoError;
	
	if (NULL == ioPropertyDataSize) return kAudioHardwareBadPropertySizeError;
	if (NULL == outPropertyData) {
		*ioPropertyDataSize = 0;
		return paramErr;
	}

	SInt32 i, streamIndex = -1;
	bool isInput = false;
	for (i = 0; i < mNumberOfOutputChannels; ++i) {
		if (inStream == mOutputStreamIDs[i]) {
			streamIndex = i; isInput = false; break;
		}
	}
	for (i = 0; i < mNumberOfInputChannels; ++i) {
		if (inStream == mInputStreamIDs[i]) {
			streamIndex = i; isInput = true; break;
		}
	}
	if (streamIndex < 0) return kAudioHardwareBadStreamError;
	bool isPropertySupported = true;

	switch (inPropertyID) {
#pragma mark _____ AudioObject Properties
		case kAudioObjectPropertyName:
			if (*ioPropertyDataSize < sizeof(CFStringRef)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				CFStringRef* outString = (CFStringRef*) outPropertyData;
				if (isInput)
					*outString = CFStringCreateWithFormat(NULL, NULL, CFSTR("Input  %i"), streamIndex + 1);
				else 
					*outString = CFStringCreateWithFormat(NULL, NULL, CFSTR("Output %i"), streamIndex + 1);
				*ioPropertyDataSize = sizeof(CFStringRef);
			}
			break;
#pragma mark _____ AudioControl Properties
			// don't support jacks or data sources
		case kAudioDevicePropertyJackIsConnected:
		case kAudioDevicePropertyDataSource: 
			err = kAudioHardwareUnknownPropertyError;
			break;
#pragma mark _____ AudioDevice Deprecated Properties
		case kAudioDevicePropertyStreamFormats: 
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription *) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
			break;
#pragma mark _____ AudioStream Properties
		case kAudioStreamPropertyDirection:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				UInt32* direction = (UInt32*) outPropertyData;
					// 0 is output
				*direction = isInput;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioStreamPropertyTerminalType:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				UInt32* termType = (UInt32*) outPropertyData;
				*termType = (isInput) ? (UInt32) INPUT_UNDEFINED : (UInt32) OUTPUT_UNDEFINED;
//				*termType = (UInt32) PROCESSOR_GENERAL;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioStreamPropertyStartingChannel:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				UInt32* channel = (UInt32*) outPropertyData;
				*channel = 1 + streamIndex;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioStreamPropertyLatency:
			if (*ioPropertyDataSize < sizeof(UInt32)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				UInt32* latency = (UInt32*) outPropertyData;
				*latency = 0;
				*ioPropertyDataSize = sizeof(UInt32);
			}
			break;
		case kAudioStreamPropertyVirtualFormat:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
			break;
		case kAudioStreamPropertyAvailableVirtualFormats:
			if (*ioPropertyDataSize < sizeof(AudioStreamRangedDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamRangedDescription* abrd = (AudioStreamRangedDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				abrd->mFormat = streamFormat;
				abrd->mSampleRateRange.mMinimum = mSampleRate;
				abrd->mSampleRateRange.mMaximum = mSampleRate;
				*ioPropertyDataSize = sizeof(AudioStreamRangedDescription);
			}
			break;
		case kAudioStreamPropertyPhysicalFormat:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
			break;
		case kAudioStreamPropertyAvailablePhysicalFormats:
			if (*ioPropertyDataSize < sizeof(AudioStreamRangedDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamRangedDescription* abrd = (AudioStreamRangedDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				abrd->mFormat = streamFormat;
				abrd->mSampleRateRange.mMinimum = mSampleRate;
				abrd->mSampleRateRange.mMaximum = mSampleRate;
				*ioPropertyDataSize = sizeof(AudioStreamRangedDescription);
			}
			break;
#pragma mark _____ AudioStream Deprecated
		case kAudioStreamPropertyOwningDevice:
			if (*ioPropertyDataSize < sizeof(AudioObjectID)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				*((AudioObjectID*) outPropertyData) = mDeviceID;
				*ioPropertyDataSize = sizeof(AudioObjectID);
			}
		case kAudioStreamPropertyPhysicalFormats:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
		case kAudioStreamPropertyPhysicalFormatSupported:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
		case kAudioStreamPropertyPhysicalFormatMatch:
			if (*ioPropertyDataSize < sizeof(AudioStreamBasicDescription)) {
				err = kAudioHardwareBadPropertySizeError;
			} else {
				AudioStreamBasicDescription* absd = (AudioStreamBasicDescription*) outPropertyData;
				CAStreamBasicDescription streamFormat;
				streamFormat.SetCanonical(1, false);
				streamFormat.mSampleRate = mSampleRate;
				*absd = streamFormat;
				*ioPropertyDataSize = sizeof(AudioStreamBasicDescription);
			}
			break;
		default:
			err = kAudioHardwareUnknownPropertyError;
			isPropertySupported = false;
			break;
	}
	
	if (err && !isPropertySupported) {
		ZKMCNDebugPrintf("Get property info for stream 0x%X : %4.4s\n", inStream, &inPropertyID);
		fflush(stdout);
	}
	return err;
}

OSStatus	ZKMORHALPlugInImpl::StreamSetProperty(AudioStreamID inStream, const AudioTimeStamp* inWhen, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData)
{
	ZKMCNDebugPrintf("Set property info for stream 0x%X : %4.4s\n", inStream, &inPropertyID);
	fflush(stdout);
	return kAudioHardwareBadStreamError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceStartAtTime(AudioDeviceID inDevice, AudioDeviceIOProc inProc, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags)
{
	return kAudioHardwareUnspecifiedError;
}

OSStatus	ZKMORHALPlugInImpl::DeviceGetNearestStartTime(AudioDeviceID inDevice, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags)
{
	return kAudioHardwareUnspecifiedError;
}

#pragma mark _____ Accessors
UInt32		ZKMORHALPlugInImpl::BufferSizeInFrames()
{ 
	UInt32 bufferSize;
	UInt32 dataSize = sizeof(UInt32);
	if (mWrappedDevice)
		AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyBufferFrameSize, &dataSize, &bufferSize);
	else
		bufferSize = 512;
	return bufferSize;
}

AudioValueRange		ZKMORHALPlugInImpl::BufferSizeRangeInFrames()
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

Float64		ZKMORHALPlugInImpl::GetSampleRate()
{
	Float64 sampleRate;
	UInt32 dataSize = sizeof(Float64);
	if (mWrappedDevice)
		AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyNominalSampleRate, &dataSize, &sampleRate);
	else
		sampleRate = 44100.;
	return sampleRate;
}

#pragma mark _____ Actions
void		ZKMORHALPlugInImpl::InitializeWrappedDevice()
{
	ReadWrappedDeviceUID();
	if (!mWrappedDeviceUID) return;
	
	CFStringRef uid = mWrappedDeviceUID;
	
	AudioDeviceID wrappedID;
	AudioValueTranslation value = { &uid, sizeof(CFStringRef), &wrappedID, sizeof(AudioDeviceID) };
	UInt32 valueSize = sizeof(AudioValueTranslation);
	OSStatus reterr = AudioHardwareGetProperty(kAudioHardwarePropertyDeviceForUID, &valueSize, &value);
	if (noErr != reterr) {
		return;
	}

	mWrappedDevice = wrappedID;
	
	valueSize = sizeof(UInt32);
		// initialize the safety offsets
	AudioDeviceGetProperty(mWrappedDevice, 0, true, kAudioDevicePropertySafetyOffset, &valueSize, &mWrappedDeviceInputSafteyOffset);
	valueSize = sizeof(UInt32);
	AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertySafetyOffset, &valueSize, &mWrappedDeviceOutputSafteyOffset);
	
	valueSize = sizeof(UInt32);
	AudioDeviceGetProperty(mWrappedDevice, 0, false, kAudioDevicePropertyBufferFrameSize, &valueSize, &mWrappedDeviceBufferFrameSize);
}

void		ZKMORHALPlugInImpl::IncrementRunningIOProcCount()
{
	++mRunningIOProcCount;
	if (mRunningIOProcCount > 1) return;
	if (!IsDeviceOutputInitialized()) InitializeDeviceOutput();
	
	// the running state changed, take action
	StartWrappedDevice();
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, false, kAudioDevicePropertyDeviceIsRunning);
//	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, true, kAudioDevicePropertyDeviceIsRunning);
}

void		ZKMORHALPlugInImpl::DecrementRunningIOProcCount()
{
	--mRunningIOProcCount;
	if (mRunningIOProcCount > 0) return;
	// the running state changed, take action
	StopWrappedDevice();
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, false, kAudioDevicePropertyDeviceIsRunning);
//	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, true, kAudioDevicePropertyDeviceIsRunning);
}

void		ZKMORHALPlugInImpl::ReadWrappedDeviceUID()
{
	if (NULL == mWrappedDeviceUID)  {
		mWrappedDeviceUID = (CFStringRef) CFPreferencesCopyAppValue(CFSTR("Device"), mDefaultsDomain);
	}
}

OSStatus	ZKMORHALPlugInImpl::CreateStreams()
{
	OSStatus err;
	//  Claim IDs for the output streams
	if (mOutputStreamIDs) free(mOutputStreamIDs);
	mOutputStreamIDs = (AudioStreamID*) malloc(sizeof(AudioStreamID) * mNumberOfOutputChannels);
	for (int i = 0; i < mNumberOfOutputChannels; i++) {
		err = AudioHardwareClaimAudioStreamID(mPlugIn, mDeviceID, &mOutputStreamIDs[i]);
		if (err != kAudioHardwareNoError) return err;
	}
	
	//  Claim IDs for the input streams
	if (mInputStreamIDs) free(mInputStreamIDs);
	mInputStreamIDs = (AudioStreamID*) malloc(sizeof(AudioStreamID) * mNumberOfInputChannels);
	for (int i = 0; i < mNumberOfInputChannels; i++) {
		err = AudioHardwareClaimAudioStreamID(mPlugIn, mDeviceID, &mInputStreamIDs[i]);
		if (err != kAudioHardwareNoError) return err;
	}
	
	// Notify the HAL that we've created some IDs
	err = AudioHardwareStreamsCreated(mPlugIn, mDeviceID, mNumberOfOutputChannels, mOutputStreamIDs);
	if (err != kAudioHardwareNoError) return err;
	err = AudioHardwareStreamsCreated(mPlugIn, mDeviceID, mNumberOfInputChannels, mInputStreamIDs);
	return err;
}

OSStatus	ZKMORHALPlugInImpl::DestroyStreams()
{
	// notify the hall that the streams and device are going away
	OSStatus err = AudioHardwareStreamsDied(mPlugIn, mDeviceID, mNumberOfOutputChannels, mOutputStreamIDs);
	if (err) return err;
	err = AudioHardwareStreamsDied(mPlugIn, mDeviceID, mNumberOfInputChannels, mInputStreamIDs);
	return err;
}

void		ZKMORHALPlugInImpl::SetNumberOfChannels(unsigned numberOfInputs, unsigned numberOfOutputs)
{
	DestroyStreams();
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, 0, kAudioDevicePropertyDeviceHasChanged);
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, 0, kAudioDevicePropertyStreamConfiguration);
	
	mNumberOfInputChannels = numberOfInputs;
	mNumberOfOutputChannels = numberOfOutputs;
	
	CreateStreams();
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, 0, kAudioDevicePropertyDeviceHasChanged);
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, 0, kAudioDevicePropertyStreamConfiguration);
}

#pragma mark _____ Queries
bool	ZKMORHALPlugInImpl::IsRunning() { return mRunningIOProcCount > 0; }
bool	ZKMORHALPlugInImpl::IsAlive() 
{ 
	ReadWrappedDeviceUID();
	return (NULL != mWrappedDeviceUID);
}
bool	ZKMORHALPlugInImpl::IsWrappedDeviceInitialized() { return mWrappedDevice != 0; }

#pragma mark _____ COM API  - Uninteresting
HRESULT	ZKMORHALPlugInImpl::PlugInQueryInterface(void * obj, REFIID iid, LPVOID *ppv)
{
	// Create a CoreFoundation UUIDRef for the requested interface.
	CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(NULL, iid);
	bool knownInterface = 
		CFEqual(interfaceID, kAudioHardwarePlugInInterfaceID) || 
		CFEqual(interfaceID, kAudioHardwarePlugInInterface2ID) ||
		CFEqual(interfaceID, IUnknownUUID);
	CFRelease(interfaceID);
	ZKMORHALPlugIn* THIS = (ZKMORHALPlugIn *)obj;
	
	// Test the requested ID against the valid interfaces.
	if (knownInterface) {
		// If the hardwarePlugInInterface or IUnknown was requested, bump the ref count,
		// set the ppv parameter equal to the instance, and
		// return good status.
		THIS->mAHInterface->AddRef(obj);
		*ppv = obj;
		return S_OK;
	} else {
		// Requested interface unknown, bail with error.
		*ppv = NULL;
		return E_NOINTERFACE;
	}
}

ULONG	ZKMORHALPlugInImpl::PlugInAddRef(void * obj)
{
	ZKMORHALPlugIn* THIS = (ZKMORHALPlugIn *)obj;
	THIS->mRefCount += 1;
	return THIS->mRefCount;
}

#pragma mark _____ HAL Plug-in API - Uninteresting
OSStatus ZKMORHALPlugInImpl::Initialize(AudioHardwarePlugInRef inSelf) {  return GetPlugInImpl(inSelf)->Initialize(); }

OSStatus ZKMORHALPlugInImpl::Teardown(AudioHardwarePlugInRef inSelf) { return GetPlugInImpl(inSelf)->Teardown(); }

OSStatus ZKMORHALPlugInImpl::DeviceAddIOProc(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc, void* data) 
{ 
	return GetPlugInImpl(inSelf)->DeviceAddIOProc(inDevice, proc, data); 
}

OSStatus ZKMORHALPlugInImpl::DeviceRemoveIOProc(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc)
{
	return GetPlugInImpl(inSelf)->DeviceRemoveIOProc(inDevice, proc);
}

OSStatus ZKMORHALPlugInImpl::DeviceStart(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc)
{
	return GetPlugInImpl(inSelf)->DeviceStart(inDevice, proc);
}

OSStatus ZKMORHALPlugInImpl::DeviceStop(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc)
{
	return GetPlugInImpl(inSelf)->DeviceStop(inDevice, proc);
}

OSStatus ZKMORHALPlugInImpl::DeviceRead(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, const AudioTimeStamp* inStartTime, AudioBufferList* outData)
{
	return GetPlugInImpl(inSelf)->DeviceRead(inDevice, inStartTime, outData);
}

OSStatus ZKMORHALPlugInImpl::DeviceGetCurrentTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioTimeStamp* outTime)
{
	return GetPlugInImpl(inSelf)->DeviceGetCurrentTime(inDevice, outTime);
}

OSStatus ZKMORHALPlugInImpl::DeviceTranslateTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, const AudioTimeStamp* inTime, AudioTimeStamp* outTime)
{
	return GetPlugInImpl(inSelf)->DeviceTranslateTime(inDevice, inTime, outTime);
}

OSStatus ZKMORHALPlugInImpl::DeviceGetPropertyInfo(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable)
{
	return GetPlugInImpl(inSelf)->DeviceGetPropertyInfo(inDevice, inChannel, isInput, inPropertyID, outSize, outWritable);
}

OSStatus ZKMORHALPlugInImpl::DeviceGetProperty(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData)
{
	return GetPlugInImpl(inSelf)->DeviceGetProperty(inDevice, inChannel, isInput, inPropertyID, ioPropertyDataSize, outPropertyData);
}

OSStatus ZKMORHALPlugInImpl::DeviceSetProperty(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, const AudioTimeStamp* inWhen, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData)
{
	return GetPlugInImpl(inSelf)->DeviceSetProperty(inDevice, inWhen, inChannel, isInput, inPropertyID, inPropertyDataSize, inPropertyData);
}

OSStatus ZKMORHALPlugInImpl::StreamGetPropertyInfo(AudioHardwarePlugInRef inSelf, AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable)
{
	return GetPlugInImpl(inSelf)->StreamGetPropertyInfo(inStream, inChannel, inPropertyID, outSize, outWritable);
}

OSStatus ZKMORHALPlugInImpl::StreamGetProperty(AudioHardwarePlugInRef inSelf, AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData)
{
	return GetPlugInImpl(inSelf)->StreamGetProperty(inStream, inChannel, inPropertyID, ioPropertyDataSize, outPropertyData);
}

OSStatus ZKMORHALPlugInImpl::StreamSetProperty(AudioHardwarePlugInRef inSelf, AudioStreamID inStream, const AudioTimeStamp* inWhen, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData)
{
	return GetPlugInImpl(inSelf)->StreamSetProperty(inStream, inWhen, inChannel, inPropertyID, inPropertyDataSize, inPropertyData);
}

OSStatus ZKMORHALPlugInImpl::DeviceStartAtTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc inProc, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags)
{
	return GetPlugInImpl(inSelf)->DeviceStartAtTime(inDevice, inProc, ioRequestedStartTime, inFlags);
}

OSStatus ZKMORHALPlugInImpl::DeviceGetNearestStartTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags)
{
	return GetPlugInImpl(inSelf)->DeviceGetNearestStartTime(inDevice, ioRequestedStartTime, inFlags);
}
