#include "Zirkalloy.h"


#pragma mark ____Zirkalloy

COMPONENT_ENTRY(Zirkalloy)

static CFStringRef kAzimuth_Name = CFSTR("azimuth");
static CFStringRef kZenith_Name = CFSTR("zenith");
static CFStringRef kAzimuthSpan_Name = CFSTR("azimuth span");
static CFStringRef kZenithSpan_Name = CFSTR("zenith span");
static CFStringRef kGain_Name = CFSTR("gain");
static CFStringRef kChannel_Name = CFSTR("channel");

#pragma mark ____Construction_Initialization


Zirkalloy::Zirkalloy(AudioUnit component)
	: AUEffectBase(component), mZirkClient(NULL)
{
	// all the parameters must be set to their initial values here
	//
	// these calls have the effect both of defining the parameters for the first time
	// and assigning their initial values
	//
    AUEffectBase::SetParameter(kZirkalloyParam_Channel, kDefault_Channel);
	AUEffectBase::SetParameter(kZirkalloyParam_Azimuth, kDefault_Azimuth);
	AUEffectBase::SetParameter(kZirkalloyParam_Zenith, kDefault_Zenith);
    AUEffectBase::SetParameter(kZirkalloyParam_AzimuthSpan, kDefault_AzimuthSpan);
    AUEffectBase::SetParameter(kZirkalloyParam_ZenithSpan, kDefault_ZenithSpan);
    AUEffectBase::SetParameter(kZirkalloyParam_Gain, kDefault_Gain);
    
    /// @todo This line may not be necessary
	SetParamHasSampleRateDependency(true);
}

ComponentResult		Zirkalloy::Initialize()
{
	ComponentResult result = AUEffectBase::Initialize();
    
    // Defaults to stereo samples
    mChannelCount = 2;
	
	if(result == noErr )
	{
        mZirkClient = new Zirk2PortClient();
        mZirkClient->SendConnect(); 
	}
	
	return result;
}

void	Zirkalloy::Cleanup()
{
	mZirkClient->SendDisconnect();
	delete mZirkClient;
    mZirkClient = NULL;
	
	AUEffectBase::Cleanup();
}

#pragma mark ____Parameters
ComponentResult		Zirkalloy::GetParameterValueStrings(	AudioUnitScope			inScope,
                                                       AudioUnitParameterID	inParameterID,
                                                       CFArrayRef *			outStrings)
{
    ComponentResult result = noErr;
    
	switch (inParameterID)
    {
        case kZirkalloyParam_Channel:
        {
            if (outStrings == NULL) return noErr;
            
            CFMutableArrayRef stringArray = CFArrayCreateMutable(NULL, DEVICE_NUM_CHANNELS, &kCFTypeArrayCallBacks);
            
            for (unsigned int i = 0; i < DEVICE_NUM_CHANNELS; i += 2)
            {
                CFStringRef stringValue = CFStringCreateWithFormat(NULL, NULL, CFSTR("%u-%u"), i, i + 1);
                CFArrayAppendValue(stringArray, stringValue);
                CFRelease(stringValue);
            }
            
            *outStrings = stringArray;
            break;
        }
            
        default:
            result = kAudioUnitErr_InvalidParameter;
            break;
	}
    
    return result;
}

ComponentResult		Zirkalloy::GetParameterInfo(	AudioUnitScope			inScope,
												AudioUnitParameterID	inParameterID,
												AudioUnitParameterInfo	&outParameterInfo )
{
	ComponentResult result = noErr;

	outParameterInfo.flags = 	kAudioUnitParameterFlag_IsWritable
						+		kAudioUnitParameterFlag_IsReadable;
		
	if (inScope == kAudioUnitScope_Global)
    {
		switch(inParameterID)
		{
            case kZirkalloyParam_Azimuth:
                AUBase::FillInParameterName (outParameterInfo, kAzimuth_Name, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Degrees;
                outParameterInfo.minValue = kMin_Azimuth;
                outParameterInfo.maxValue = kMax_Azimuth;
                outParameterInfo.defaultValue = kDefault_Azimuth;
                
                //outParameterInfo.flags += kAudioUnitParameterFlag_IsHighResolution;
                break;
                
            case kZirkalloyParam_Zenith:
                AUBase::FillInParameterName (outParameterInfo, kZenith_Name, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Degrees;
                outParameterInfo.minValue = kMin_Zenith;
                outParameterInfo.maxValue = kMax_Zenith;
                outParameterInfo.defaultValue = kDefault_Zenith;
                
                //outParameterInfo.flags += kAudioUnitParameterFlag_IsHighResolution;
                break;
                
            case kZirkalloyParam_AzimuthSpan:
                AUBase::FillInParameterName (outParameterInfo, kAzimuthSpan_Name, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Degrees;
                outParameterInfo.minValue = kMin_AzimuthSpan;
                outParameterInfo.maxValue = kMax_AzimuthSpan;
                outParameterInfo.defaultValue = kDefault_AzimuthSpan;
                
                //outParameterInfo.flags += kAudioUnitParameterFlag_IsHighResolution;
                break;
                
            case kZirkalloyParam_ZenithSpan:
                AUBase::FillInParameterName (outParameterInfo, kZenithSpan_Name, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Degrees;
                outParameterInfo.minValue = kMin_ZenithSpan;
                outParameterInfo.maxValue = kMax_ZenithSpan;
                outParameterInfo.defaultValue = kDefault_ZenithSpan;
                
                //outParameterInfo.flags += kAudioUnitParameterFlag_IsHighResolution;
                break;
                
            case kZirkalloyParam_Gain:
                AUBase::FillInParameterName (outParameterInfo, kGain_Name, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_LinearGain;
                outParameterInfo.minValue = kMin_Gain;
                outParameterInfo.maxValue = kMax_Gain;
                outParameterInfo.defaultValue = kDefault_Gain;
                
                //outParameterInfo.flags += kAudioUnitParameterFlag_IsHighResolution;
                break;
                
            case kZirkalloyParam_Channel:
                AUBase::FillInParameterName (outParameterInfo, kChannel_Name, false);
                outParameterInfo.unit = kAudioUnitParameterUnit_Indexed;
                outParameterInfo.minValue = kMin_Channel;
                outParameterInfo.maxValue = kMax_Channel;
                outParameterInfo.defaultValue = kDefault_Channel;
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

#pragma mark ____Properties
ComponentResult		Zirkalloy::GetPropertyInfo (	AudioUnitPropertyID				inID,
												AudioUnitScope					inScope,
												AudioUnitElement				inElement,
												UInt32 &						outDataSize,
												Boolean &						outWritable)
{
	if (inScope == kAudioUnitScope_Global)
	{
		switch (inID)
		{
			case kAudioUnitProperty_CocoaUI:
				outWritable = false;
				outDataSize = sizeof (AudioUnitCocoaViewInfo);
				return noErr;
		}
	}
	
	return AUEffectBase::GetPropertyInfo (inID, inScope, inElement, outDataSize, outWritable);
}

ComponentResult		Zirkalloy::GetProperty (	AudioUnitPropertyID 		inID,
											AudioUnitScope 				inScope,
											AudioUnitElement			inElement,
											void *						outData)
{
	if (inScope == kAudioUnitScope_Global)
	{
		switch (inID)
		{
			// This property allows the host application to find the UI associated with this
			// AudioUnit
			//
			case kAudioUnitProperty_CocoaUI:
			{
				// Look for a resource in the main bundle by name and type.
				CFBundleRef bundle = CFBundleGetBundleWithIdentifier( CFSTR("de.zkm.audiounit.Zirkalloy") );
				
				if (bundle == NULL) return fnfErr;
                
				CFURLRef bundleURL = CFBundleCopyResourceURL( bundle, 
                    CFSTR("CocoaDomeView"),	// this is the name of the cocoa bundle as specified in the CocoaViewFactory.plist
                    CFSTR("bundle"),			// this is the extension of the cocoa bundle
                    NULL);
                
                if (bundleURL == NULL) return fnfErr;
                
				CFStringRef className = CFSTR("Zirkalloy_ViewFactory");	// name of the main class that implements the AUCocoaUIBase protocol
				AudioUnitCocoaViewInfo cocoaInfo = { bundleURL, className };
				*((AudioUnitCocoaViewInfo *)outData) = cocoaInfo;
				
				return noErr;
			}
		}
	}
	
	// if we've gotten this far, handles the standard properties
	return AUEffectBase::GetProperty (inID, inScope, inElement, outData);
}

ComponentResult     Zirkalloy::SetParameter(AudioUnitParameterID			inID,
                                         AudioUnitScope 					inScope,
                                         AudioUnitElement 				inElement,
                                         Float32							inValue,
                                         UInt32							inBufferOffsetInFrames)
{
    ComponentResult ans =  AUBase::SetParameter(inID, inScope, inElement, inValue, inBufferOffsetInFrames);
    
    if (ans == noErr)    
    {
        int initialChannel = GetParameter(kZirkalloyParam_Channel) * 2;
        
        float az = GetParameter(kZirkalloyParam_Azimuth);
        float zn = GetParameter(kZirkalloyParam_Zenith);
        float azs = GetParameter(kZirkalloyParam_AzimuthSpan);
        float zns = GetParameter(kZirkalloyParam_ZenithSpan);
        float gain = 1.0f;
//        float gain = GetParameter(kGainParameter);
        printf("mZirkClient->SendPanAz(%u, %.2f, %.2f, %.2f, %.2f, %.2f)\n", initialChannel, az, zn, azs, zns, gain);
        mZirkClient->SendPan(initialChannel, az, zn, azs, zns, gain);
    }
    
    return ans;
}