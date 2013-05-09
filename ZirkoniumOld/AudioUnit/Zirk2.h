/*
*	File:		Zirk2.h
*	
*	Version:	1.0
* 
*	Created:	19.05.06
*	
*	Copyright:  Copyright © 2006 C. Ramakrishnan/ZKM, All Rights Reserved
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

#include "AUEffectBase.h"
#include "Zirk2Version.h"
#if AU_DEBUG_DISPATCHER
#include "AUDebugDispatcher.h"
#endif

#ifndef __Zirk2_h__
#define __Zirk2_h__

#include "ZKMRNZirk2Protocol.h"

#pragma mark ____Zirk2 Parameters
static const float kDefaultValue_Azimuth = 0.f;
static const float kDefaultValue_Zenith = 0.f;
static const float kDefaultValue_Gain = 1.f;
static const float kDefaultValue_ChannelSpacing = 1.f;
static const float kDefaultValue_ChannelOffset = 1.f;

enum {
	kAzimuthParameter = 0,
	kZenithParameter = 1,
	kGainParameter = 2,
	kChannelSpacingParameter = 3,
	kChannelOffsetParameter = 4,
	//Add more parameters here
	kNumberOfParameters = kChannelOffsetParameter + 1
};

#pragma mark ____Zirk2 Properties

enum {
	kTrackNumberProperty = 64000,
	kChannelNumberProperty = 64001,
	//Add more parameters here
	kNumberOfProperties = kTrackNumberProperty + 1
};

#pragma mark ____Zirk2 
class Zirk2 : public AUEffectBase
{
public:
	Zirk2(AudioUnit component);
	virtual ~Zirk2();
	
	virtual AUKernelBase *		NewKernel() { return new Zirk2Kernel(this); }
	
	virtual	ComponentResult		GetParameterValueStrings(AudioUnitScope			inScope,
														 AudioUnitParameterID		inParameterID,
														 CFArrayRef *			outStrings);
    
	virtual	ComponentResult		GetParameterInfo(AudioUnitScope			inScope,
												 AudioUnitParameterID	inParameterID,
												 AudioUnitParameterInfo	&outParameterInfo);
    
	virtual ComponentResult		GetPropertyInfo(AudioUnitPropertyID		inID,
												AudioUnitScope			inScope,
												AudioUnitElement		inElement,
												UInt32 &			outDataSize,
												Boolean	&			outWritable );
	
	virtual ComponentResult		GetProperty(AudioUnitPropertyID inID,
											AudioUnitScope		inScope,
											AudioUnitElement	inElement,
											void *			outData);

	virtual ComponentResult		SetProperty(	AudioUnitPropertyID 	inID,
												AudioUnitScope 			inScope,
												AudioUnitElement 		inElement,
												const void *			inData,
												UInt32 					inDataSize);

	ComponentResult				SetParameter(	AudioUnitParameterID			inID,
												AudioUnitScope 					inScope,
												AudioUnitElement 				inElement,
												Float32							inValue,
												UInt32							inBufferOffsetInFrames);
											
	virtual ComponentResult		Initialize();
	virtual void				Cleanup();
	
	virtual ComponentResult		Render(	AudioUnitRenderActionFlags &ioActionFlags,
										const AudioTimeStamp &		inTimeStamp,
										UInt32						nFrames);											
	
   	virtual	bool				SupportsTail () { return false; }
	
	/*! @method Version */
	virtual ComponentResult	Version() { return kZirk2Version; }
	
	int		GetNumCustomUIComponents () { return 1; }
	
	void	GetUIComponentDescs (ComponentDescription* inDescArray) {
        inDescArray[0].componentType = kAudioUnitCarbonViewComponentType;
        inDescArray[0].componentSubType = Zirk2_COMP_SUBTYPE;
        inDescArray[0].componentManufacturer = Zirk2_COMP_MANF;
        inDescArray[0].componentFlags = 0;
        inDescArray[0].componentFlagsMask = 0;
	}

protected:
		// Connection State
	int					mTrackNumber;
	int					mChannelNumber;
		// port state
	Zirk2PortClient*		mZirkClient;
	bool				mChangedParameter;
	
protected:
		class Zirk2Kernel : public AUKernelBase		// most real work happens here
	{
		public:
		Zirk2Kernel(AUEffectBase *inAudioUnit )
		: AUKernelBase(inAudioUnit)
		{

		}
		
		// *Required* overides for the process method for this effect
		// processes one channel of interleaved samples
        virtual void 		Process(	const Float32 	*inSourceP,
										Float32		 	*inDestP,
										UInt32 			inFramesToProcess,
										UInt32			inNumChannels,
										bool			&ioSilence);
		
        virtual void		Reset();
		
		//private: //state variables...
	};
};
#endif