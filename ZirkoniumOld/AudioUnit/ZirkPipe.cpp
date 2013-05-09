/*
*	File:		ZirkPipe.cpp
*	
*	Version:	1.0
* 
*	Created:	19.05.06
*	
*	Copyright:  Copyright © 2007 C. Ramakrishnan/ZKM, All Rights Reserved
* 
*	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in 
*				consideration of your agreement to the following terms, and your use, installation, modification 
*				or redistribution of this Apple software constitutes acceptance of these terms.  If you do 
*				not agree with these terms, please do not use, install, modify or redistribute this Apple 
*				software.
*
*				In consideration of your agreement to abide by the following terms, and subject to these terms, 
*				Apple grants you a personal, non-exclusive license, under Apple's copyrights in this 
*				original Apple software (the "Apple Software"), to use, reproduce, modify and redistribute the 
*				Apple Software, with or without modifications, in source and/or binary forms; provided that if you 
*				redistribute the Apple Software in its entirety and without modifications, you must retain this 
*				notice and the following text and disclaimers in all such redistributions of the Apple Software. 
*				Neither the name, trademarks, service marks or logos of Apple Computer, Inc. may be used to 
*				endorse or promote products derived from the Apple Software without specific prior written 
*				permission from Apple.  Except as expressly stated in this notice, no other rights or 
*				licenses, express or implied, are granted by Apple herein, including but not limited to any 
*				patent rights that may be infringed by your derivative works or by other works in which the 
*				Apple Software may be incorporated.
*
*				The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, EXPRESS OR 
*				IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY 
*				AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE 
*				OR IN COMBINATION WITH YOUR PRODUCTS.
*
*				IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
*				DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
*				OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
*				REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER 
*				UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN 
*				IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*/
#include "ZirkPipe.h"
#include "ZKMRNDeviceConstants.h"
#include <algorithm>

ZirkPipe::ZirkPipe(AudioUnit component)
	: AUEffectBase(component)
{
	CreateElements();
	mNumberOfChannels = 2;

#if AU_DEBUG_DISPATCHER
	mDebugDispatcher = new AUDebugDispatcher (this);
#endif
}

ZirkPipe::~ZirkPipe () 
{
//	mZirkClient->SendDisconnect();
	
#if AU_DEBUG_DISPATCHER
	delete mDebugDispatcher;
#endif
}


ComponentResult		ZirkPipe::GetParameterValueStrings(	AudioUnitScope			inScope,
														AudioUnitParameterID	inParameterID,
                                                        CFArrayRef *			outStrings)
{
	if (kChannelNumberParameter == inParameterID) {
		if (outStrings == NULL) return noErr;

		CFMutableArrayRef stringArray = CFArrayCreateMutable(NULL, DEVICE_NUM_CHANNELS, &kCFTypeArrayCallBacks);
		unsigned i, count = DEVICE_NUM_CHANNELS;
		for (i = 0; i < count; ++i) {
			CFStringRef stringValue = CFStringCreateWithFormat(NULL, NULL, CFSTR("%u"), i + 1);
			CFArrayAppendValue(stringArray, stringValue);
			CFRelease(stringValue);
		}
		*outStrings = stringArray;
		return noErr;
	}
		
    return kAudioUnitErr_InvalidProperty;
}


ComponentResult		ZirkPipe::GetParameterInfo(		AudioUnitScope			inScope,
                                                    AudioUnitParameterID	inParameterID,
                                                    AudioUnitParameterInfo	&outParameterInfo )
{
	if ((kAudioUnitScope_Global == inScope) && (kChannelNumberParameter == inParameterID))
	{
		outParameterInfo.flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable;
	
		AUBase::FillInParameterName(outParameterInfo, CFSTR("Channel"), false);
		outParameterInfo.unit = kAudioUnitParameterUnit_Indexed;
		outParameterInfo.minValue = 0.f;
		outParameterInfo.maxValue = (Float32)   - 1.f;
		outParameterInfo.defaultValue = 0.f;
		return noErr;
	}
    
	return kAudioUnitErr_InvalidParameter;
}

ComponentResult		ZirkPipe::GetPropertyInfo(	AudioUnitPropertyID	inID,
												AudioUnitScope		inScope,
												AudioUnitElement	inElement,
												UInt32 &			outDataSize,
												Boolean &			outWritable)
{
	if ((kAudioUnitScope_Global == inScope) && (kAudioUnitProperty_ParameterClumpName == inID))
	{
		outDataSize = sizeof(AudioUnitParameterNameInfo);
		outWritable = false;
		return noErr;
	}
	
	return AUEffectBase::GetPropertyInfo (inID, inScope, inElement, outDataSize, outWritable);
}

ComponentResult		ZirkPipe::GetProperty(	AudioUnitPropertyID		inID,
											AudioUnitScope			inScope,
											AudioUnitElement		inElement,
											void *					outData )
{
	if ((kAudioUnitScope_Global == inScope) && (kAudioUnitProperty_ParameterClumpName == inID))
	{
		AudioUnitParameterNameInfo* parameterNameInfo = (AudioUnitParameterNameInfo *) outData;
		parameterNameInfo->outName = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Channel %u"), parameterNameInfo->inID);
		return noErr;
	}
	
	return AUEffectBase::GetProperty (inID, inScope, inElement, outData);
}

ComponentResult		ZirkPipe::SetProperty(		AudioUnitPropertyID 	inID,
												AudioUnitScope 			inScope,
												AudioUnitElement 		inElement,
												const void *			inData,
												UInt32 					inDataSize)
{
	if (kAudioUnitProperty_StreamFormat == inID) 
	{
		const AudioStreamBasicDescription* absd = (const AudioStreamBasicDescription *) inData;
		mNumberOfChannels = std::min((UInt32) DEVICE_NUM_CHANNELS, absd->mChannelsPerFrame);
	}
	return AUEffectBase::SetProperty (inID, inScope, inElement, inData, inDataSize);
}

ComponentResult 	ZirkPipe::Render(	AudioUnitRenderActionFlags &ioActionFlags,
											const AudioTimeStamp &		inTimeStamp,
											UInt32						nFrames)
{
	if (!HasInput(0)) return kAudioUnitErr_NoConnection;

	ComponentResult result = noErr;
	AUOutputElement *theOutput = GetOutput(0);	// throws if error

	AUInputElement *theInput = GetInput(0);
	result = theInput->PullInput(ioActionFlags, inTimeStamp, 0, nFrames);
	
	if (result != noErr)
		return result;

	if(ProcessesInPlace())
	{
		theOutput->SetBufferList(theInput->GetBufferList());
	} else {
		theInput->CopyBufferContentsTo(theOutput->GetBufferList());
	}
	
	return result;
}


ComponentResult		ZirkPipe::Initialize()
{
	mZirkClient = new Zirk2PortClient();
	mZirkClient->SendConnect();
	
	return AUEffectBase::Initialize();
}

void	ZirkPipe::Cleanup()
{
	mZirkClient->SendDisconnect();
	delete mZirkClient; mZirkClient = NULL;
	
	AUEffectBase::Cleanup();
}

#pragma mark _____ ZirkAz
COMPONENT_ENTRY(ZirkAz)

ComponentResult		ZirkAz::GetParameterInfo(		AudioUnitScope			inScope,
                                                    AudioUnitParameterID	inParameterID,
                                                    AudioUnitParameterInfo	&outParameterInfo )
{

	if (kAudioUnitScope_Global != inScope) return kAudioUnitErr_InvalidParameter;
	
	ComponentResult result = noErr;
	outParameterInfo.flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_HasClump;
	outParameterInfo.clumpID = inParameterID >> 16;
	switch((inParameterID & 0xFFFF))
	{
		case kAzimuthParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Azimuth %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
			outParameterInfo.minValue = -4.f;
			outParameterInfo.maxValue = 4.f;
			outParameterInfo.defaultValue = kDefaultValue_Azimuth;
			break;
		case kZenithParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Zenith %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 0.5f;
			outParameterInfo.defaultValue = kDefaultValue_Zenith;
			break;
		case kAzimuthSpanParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Azimuth Span %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 2.f;
			outParameterInfo.defaultValue = kDefaultValue_AzimuthSpan;
			break;
		case kZenithSpanParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Zenith Span %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 0.5f;
			outParameterInfo.defaultValue = kDefaultValue_ZenithSpan;
			break;
		case kGainParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Gain %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_LinearGain;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 2.f;
			outParameterInfo.defaultValue = kDefaultValue_Gain;
			break;
		default:
			result = kAudioUnitErr_InvalidParameter;
			break;
	}
    
	if (noErr == result) return noErr;
	return ZirkPipe::GetParameterInfo(inScope, inParameterID, outParameterInfo);
}

ComponentResult 	ZirkAz::SetParameter(			AudioUnitParameterID			inID,
													AudioUnitScope 					inScope,
													AudioUnitElement 				inElement,
													Float32							inValue,
													UInt32							inBufferOffsetInFrames)
{
	ComponentResult ans =  AUBase::SetParameter(inID, inScope, inElement, inValue, inBufferOffsetInFrames);
	if (ans == noErr) mChangedParameter = true;
	
	UInt32 i, numberOfChannels = mNumberOfChannels;
	UInt32 initialChannel = (UInt32) (GetParameter(kChannelNumberParameter));

	for (i = 0; i < numberOfChannels; i++) {
		unsigned topByte = (i & 0xFFFF) << 16;
		float az = GetParameter(topByte | kAzimuthParameter);
		float zn = GetParameter(topByte | kZenithParameter);
		float azs = GetParameter(topByte | kAzimuthSpanParameter);
		float zns = GetParameter(topByte | kZenithSpanParameter);
		float gain = GetParameter(topByte | kGainParameter);
		printf("mZirkClient->SendPanAz(%u, %.2f, %.2f, %.2f, %.2f, %.2f)\n", initialChannel + i, az, zn, azs, zns, gain);
		mZirkClient->SendPan(initialChannel + i, az, zn, azs, zns, gain);
	}
	mChangedParameter = false;
	
	return ans;
}	

void ZirkAz::InitializeParameters()
{
	AUEffectBase::SetParameter(kChannelNumberParameter, 0);
	
	for (unsigned i = 0; i < mNumberOfChannels; i++) {
		unsigned topByte = (i & 0xFFFF) << 16;
		AUEffectBase::SetParameter(topByte | kAzimuthParameter, kDefaultValue_Azimuth);
		AUEffectBase::SetParameter(topByte | kZenithParameter, kDefaultValue_Zenith);
		AUEffectBase::SetParameter(topByte | kAzimuthSpanParameter, kDefaultValue_AzimuthSpan);
		AUEffectBase::SetParameter(topByte | kZenithSpanParameter, kDefaultValue_ZenithSpan);
		AUEffectBase::SetParameter(topByte | kGainParameter, kDefaultValue_Gain);		
	}
}

#pragma mark _____ ZirkXy
COMPONENT_ENTRY(ZirkXy)

ComponentResult		ZirkXy::GetParameterInfo(		AudioUnitScope			inScope,
                                                    AudioUnitParameterID	inParameterID,
                                                    AudioUnitParameterInfo	&outParameterInfo )
{

	if (kAudioUnitScope_Global != inScope) return kAudioUnitErr_InvalidParameter;
	
	ComponentResult result = noErr;
	outParameterInfo.flags = kAudioUnitParameterFlag_IsWritable | kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_HasClump;
	outParameterInfo.clumpID = inParameterID >> 16;
	switch((inParameterID & 0xFFFF))
	{
		case kAzimuthParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("X %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Generic;
			outParameterInfo.minValue = -1.f;
			outParameterInfo.maxValue = 1.f;
			outParameterInfo.defaultValue = kDefaultValue_X;
			break;
		case kZenithParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Y %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Generic;
			outParameterInfo.minValue = -1.f;
			outParameterInfo.maxValue = 1.f;
			outParameterInfo.defaultValue = kDefaultValue_Y;
			break;
		case kAzimuthSpanParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("X Span %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Generic;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 2.f;
			outParameterInfo.defaultValue = kDefaultValue_XSpan;
			break;
		case kZenithSpanParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Y Span %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_Generic;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 2.f;
			outParameterInfo.defaultValue = kDefaultValue_YSpan;
			break;
		case kGainParameter:
			AUBase::FillInParameterName(	outParameterInfo, 
											CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Gain %i"), outParameterInfo.clumpID),
											true);
			outParameterInfo.unit = kAudioUnitParameterUnit_LinearGain;
			outParameterInfo.minValue = 0.f;
			outParameterInfo.maxValue = 2.f;
			outParameterInfo.defaultValue = kDefaultValue_Gain;
			break;
		default:
			result = kAudioUnitErr_InvalidParameter;
			break;
	}
    
	if (noErr == result) return noErr;
	return ZirkPipe::GetParameterInfo(inScope, inParameterID, outParameterInfo);
}

ComponentResult 	ZirkXy::SetParameter(			AudioUnitParameterID			inID,
													AudioUnitScope 					inScope,
													AudioUnitElement 				inElement,
													Float32							inValue,
													UInt32							inBufferOffsetInFrames)
{
	ComponentResult ans =  AUBase::SetParameter(inID, inScope, inElement, inValue, inBufferOffsetInFrames);
	if (ans == noErr) mChangedParameter = true;
	
	UInt32 i, numberOfChannels = mNumberOfChannels;
	UInt32 initialChannel = (UInt32) (GetParameter(kChannelNumberParameter));

	for (i = 0; i < numberOfChannels; i++) {
		unsigned topByte = (i & 0xFFFF) << 16;
		float x = GetParameter(topByte | kXParameter);
		float y = GetParameter(topByte | kYParameter);
		float xs = GetParameter(topByte | kXSpanParameter);
		float ys = GetParameter(topByte | kYSpanParameter);
		float gain = GetParameter(topByte | kGainParameter);
		printf("mZirkClient->SendPanXY(%u, %.2f, %.2f, %.2f, %.2f, %.2f)\n", initialChannel + i, x, y, xs, ys, gain);
//		mZirkClient->SendPanXY(initialChannel + i, az, zn, azs, zns, gain);
	}
	mChangedParameter = false;
	
	return ans;
}	

void ZirkXy::InitializeParameters()
{
	AUEffectBase::SetParameter(kChannelNumberParameter, 0);
	
	for (unsigned i = 0; i < mNumberOfChannels; i++) {
		unsigned topByte = (i & 0xFFFF) << 16;
		AUEffectBase::SetParameter(topByte | kXParameter, kDefaultValue_X);
		AUEffectBase::SetParameter(topByte | kYParameter, kDefaultValue_Y);
		AUEffectBase::SetParameter(topByte | kXSpanParameter, kDefaultValue_XSpan);
		AUEffectBase::SetParameter(topByte | kYSpanParameter, kDefaultValue_YSpan);
		AUEffectBase::SetParameter(topByte | kGainParameter, kDefaultValue_Gain);		
	}
}
