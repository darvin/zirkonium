/*
*	File:		Zirk2.cpp
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
#include "Zirk2.h"
#include "ZKMRNDeviceConstants.h"

static CFStringRef kAzimuthName = CFSTR("Azimuth");
static CFStringRef kZenithName = CFSTR("Zenith");
static CFStringRef kGainName = CFSTR("Gain");
static CFStringRef kChannelSpacingName = CFSTR("Channel Spacing");
static CFStringRef kChannelOffsetName = CFSTR("Channel Offset");


//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

COMPONENT_ENTRY(Zirk2)


//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::Zirk2
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Zirk2::Zirk2(AudioUnit component)
	: AUEffectBase(component)
{
	CreateElements();
	Globals()->UseIndexedParameters(kNumberOfParameters);
	AUEffectBase::SetParameter(kAzimuthParameter, kDefaultValue_Azimuth);
	AUEffectBase::SetParameter(kZenithParameter, kDefaultValue_Zenith);
	AUEffectBase::SetParameter(kGainParameter, kDefaultValue_Gain);
	AUEffectBase::SetParameter(kChannelSpacingParameter, kDefaultValue_ChannelSpacing);
	AUEffectBase::SetParameter(kChannelOffsetParameter, kDefaultValue_ChannelOffset);
	
		// initialize ivars
	mTrackNumber = 0;
	mChannelNumber = 0;
        
#if AU_DEBUG_DISPATCHER
	mDebugDispatcher = new AUDebugDispatcher (this);
#endif
	
}

Zirk2::~Zirk2 () 
{
//	mZirkClient->SendDisconnect();
	
#if AU_DEBUG_DISPATCHER
	delete mDebugDispatcher;
#endif
}


//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::GetParameterValueStrings
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ComponentResult		Zirk2::GetParameterValueStrings(	AudioUnitScope			inScope,
														AudioUnitParameterID	inParameterID,
                                                        CFArrayRef *			outStrings)
{
	if (kChannelOffsetParameter == inParameterID) {
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



//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::GetParameterInfo
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ComponentResult		Zirk2::GetParameterInfo(AudioUnitScope		inScope,
                                                        AudioUnitParameterID	inParameterID,
                                                        AudioUnitParameterInfo	&outParameterInfo )
{
	ComponentResult result = noErr;

	outParameterInfo.flags = 	kAudioUnitParameterFlag_IsWritable
						|		kAudioUnitParameterFlag_IsReadable;
    
    if (inScope == kAudioUnitScope_Global) {
        switch(inParameterID)
        {
            case kAzimuthParameter:
                AUBase::FillInParameterName (outParameterInfo, kAzimuthName, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
                outParameterInfo.minValue = -4.f;
                outParameterInfo.maxValue = 4.f;
                outParameterInfo.defaultValue = kDefaultValue_Azimuth;
                break;
            case kZenithParameter:
                AUBase::FillInParameterName (outParameterInfo, kZenithName, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
                outParameterInfo.minValue = 0.f;
                outParameterInfo.maxValue = 0.5f;
                outParameterInfo.defaultValue = kDefaultValue_Zenith;
                break;
            case kGainParameter:
                AUBase::FillInParameterName (outParameterInfo, kGainName, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_LinearGain;
                outParameterInfo.minValue = 0.f;
                outParameterInfo.maxValue = 5.f;
                outParameterInfo.defaultValue = kDefaultValue_Gain;
                break;
            case kChannelSpacingParameter:
                AUBase::FillInParameterName (outParameterInfo, kChannelSpacingName, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Phase;
                outParameterInfo.minValue = -1.f;
                outParameterInfo.maxValue = 1.f;
                outParameterInfo.defaultValue = kDefaultValue_ChannelSpacing;
                break;
			case kChannelOffsetParameter:
				AUBase::FillInParameterName (outParameterInfo, kChannelOffsetName, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Indexed;
                outParameterInfo.minValue = 1.f;
                outParameterInfo.maxValue = (Float32) DEVICE_NUM_CHANNELS;
                outParameterInfo.defaultValue = kDefaultValue_ChannelOffset;
                break;
            default:
                result = kAudioUnitErr_InvalidParameter;
                break;
            }
	} else {
        result = kAudioUnitErr_InvalidParameter;
    }
    


	return result;
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::GetPropertyInfo
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ComponentResult		Zirk2::GetPropertyInfo (AudioUnitPropertyID	inID,
                                                        AudioUnitScope		inScope,
                                                        AudioUnitElement	inElement,
                                                        UInt32 &		outDataSize,
                                                        Boolean &		outWritable)
{
	return AUEffectBase::GetPropertyInfo (inID, inScope, inElement, outDataSize, outWritable);
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::GetProperty
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ComponentResult		Zirk2::GetProperty(	AudioUnitPropertyID		inID,
										AudioUnitScope			inScope,
										AudioUnitElement		inElement,
										void *					outData )
{
	if (inScope == kAudioUnitScope_Global) {
		switch (inID) {
			case kTrackNumberProperty:
				*((UInt32*) outData) = mTrackNumber;
				return noErr;
			case kChannelNumberProperty:
				*((UInt32*) outData) = mChannelNumber;
				return noErr;
		}
	}
	return AUEffectBase::GetProperty (inID, inScope, inElement, outData);
}

ComponentResult		Zirk2::SetProperty(			AudioUnitPropertyID 	inID,
												AudioUnitScope 			inScope,
												AudioUnitElement 		inElement,
												const void *			inData,
												UInt32 					inDataSize)
{
	if (inScope == kAudioUnitScope_Global) {
		switch (inID) {
			case kTrackNumberProperty:
				mTrackNumber = *((UInt32*) inData);
				return noErr;
			case kChannelNumberProperty:
				mChannelNumber = *((UInt32*) inData);
		}
	}
	return AUEffectBase::SetProperty (inID, inScope, inElement, inData, inDataSize);
}

ComponentResult 	Zirk2::SetParameter(			AudioUnitParameterID			inID,
													AudioUnitScope 					inScope,
													AudioUnitElement 				inElement,
													Float32							inValue,
													UInt32							inBufferOffsetInFrames)
{
	ComponentResult ans =  AUBase::SetParameter(inID, inScope, inElement, inValue, inBufferOffsetInFrames);
	if (ans == noErr) mChangedParameter = true;
	
	UInt32 i, numberOfChannels = 1;
	float azimuthDelta = GetParameter(kChannelSpacingParameter);
	UInt32 initialChannel = (UInt32) (GetParameter(kChannelOffsetParameter) - 1.f);

	for (i = 0; i < numberOfChannels; i++) {
		mZirkClient->SendPan(initialChannel + i, GetParameter(kAzimuthParameter) + (azimuthDelta * i), GetParameter(kZenithParameter), 0.f, 0.f, GetParameter(kGainParameter));
	}
	mChangedParameter = false;
	
	return ans;
}	

ComponentResult 	Zirk2::Render(	AudioUnitRenderActionFlags &ioActionFlags,
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
/*
	if (!mChangedParameter) return noErr;
	
	UInt32 i, numberOfChannels = theInput->NumberChannels();
	float azimuthDelta = GetParameter(kChannelSpacingParameter);
	UInt32 initialChannel = (UInt32) (GetParameter(kChannelOffsetParameter) - 1.f);

	for (i = 0; i < numberOfChannels; i++) {
		mZirkClient->SendPan(initialChannel + i, GetParameter(kAzimuthParameter) + (azimuthDelta * i), GetParameter(kZenithParameter), 0.f, 0.f, GetParameter(kGainParameter));
	}
	mChangedParameter = false;
*/
	return result;
}


ComponentResult		Zirk2::Initialize()
{
	mZirkClient = new Zirk2PortClient();
	mZirkClient->SendConnect();
	
	return AUEffectBase::Initialize();
}

void	Zirk2::Cleanup()
{
	mZirkClient->SendDisconnect();
	delete mZirkClient; mZirkClient = NULL;
	
	AUEffectBase::Cleanup();
}


#pragma mark ____Zirk2EffectKernel


//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::Zirk2Kernel::Reset()
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
void		Zirk2::Zirk2Kernel::Reset()
{
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//	Zirk2::Zirk2Kernel::Process
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
void Zirk2::Zirk2Kernel::Process(	const Float32 	*inSourceP,
                                                    Float32		 	*inDestP,
                                                    UInt32 			inFramesToProcess,
                                                    UInt32			inNumChannels, // for version 2 AudioUnits inNumChannels is always 1
                                                    bool			&ioSilence )
{
	// don't alter the data
	memcpy(inDestP, inSourceP, inFramesToProcess * inNumChannels * sizeof(Float32));
}

