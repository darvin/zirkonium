#pragma once

#include <AudioToolbox/AudioUnitUtilities.h>
#include "ZirkalloyVersion.h"
#include "ZirkalloyKernel.h"
#include <math.h>
#include "AUEffectBase.h"
#include "ZKMRNDeviceConstants.h"

typedef struct PolarAngles
{
    Float32     azimuth;
    Float32     zenith;
} PolarAngles;

enum
{
    kZirkalloyParam_Azimuth = 0,
    kZirkalloyParam_Zenith = 1,
    kZirkalloyParam_AzimuthSpan = 2,
    kZirkalloyParam_ZenithSpan = 3,
    kZirkalloyParam_Gain = 4,
    kZirkalloyParam_Channel = 5
};

const float kDefault_Azimuth = 0.0f;
const float kMin_Azimuth = -1.0f;
const float kMax_Azimuth = 1.0f;

const float kDefault_Zenith = 0.0f;
const float kMin_Zenith = 0.0f;
const float kMax_Zenith = 0.5f;

const float kDefault_AzimuthSpan = 0.0f;
const float kMin_AzimuthSpan = 0.0f;
const float kMax_AzimuthSpan = kMax_Azimuth * 2;

const float kDefault_ZenithSpan = 0.0f;
const float kMin_ZenithSpan = 0.0f;
const float kMax_ZenithSpan = kMax_Zenith;

const float kDefault_Gain = 1.0f;
const float kMin_Gain = 0.0f;
const float kMax_Gain = 1.0f;

const int kDefault_Channel = 0; // Zero indexed?
const int kMin_Channel = kDefault_Channel;
const int kMax_Channel = DEVICE_NUM_CHANNELS - 1;

class Zirkalloy : public AUEffectBase
{
public:
    Zirkalloy(AudioUnit component);
    
    virtual ComponentResult		Version() { return kZirkalloyVersion; }
    
    virtual ComponentResult		Initialize();
    virtual void                Cleanup();
    
    virtual AUKernelBase *		NewKernel() { return new ZirkalloyKernel(this); }

    virtual ComponentResult		GetParameterValueStrings(	AudioUnitScope			inScope,
                                                            AudioUnitParameterID	inParameterID,
                                                         CFArrayRef *			outStrings);
    
    virtual ComponentResult		GetPropertyInfo(	AudioUnitPropertyID		inID,
                                                AudioUnitScope			inScope,
                                                AudioUnitElement		inElement,
                                                UInt32 &				outDataSize,
                                                Boolean	&				outWritable );
    
    virtual ComponentResult		GetProperty(		AudioUnitPropertyID 	inID,
                                            AudioUnitScope 			inScope,
                                            AudioUnitElement 		inElement,
                                            void 					* outData );
    
    virtual ComponentResult		GetParameterInfo(	AudioUnitScope			inScope,
                                                 AudioUnitParameterID	inParameterID,
                                                 AudioUnitParameterInfo	&outParameterInfo );
    
    virtual ComponentResult     SetParameter(AudioUnitParameterID			inID,
                                             AudioUnitScope 					inScope,
                                             AudioUnitElement 				inElement,
                                             Float32							inValue,
                                             UInt32							inBufferOffsetInFrames);

    virtual	bool				SupportsTail () { return true; }
    virtual Float64				GetTailTime() {return 0.0;}
    virtual Float64				GetLatency() {return 0.0;}
    
    
protected:
	Zirk2PortClient*	mZirkClient;
    
    int                 mChannelCount;
};

