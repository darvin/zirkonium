//
//  ZKMORMixer3D.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORMixer3D.h"
#import "ZKMORLogger.h"
#import "ZKMORUtilities.h"
#include "CAAudioChannelLayout.h"
#include "CAAudioUnitZKM.h"

#define BUSAUPTR (((ZKMORAudioUnitStruct*)_conduit)->mAudioUnit)

static OSStatus ZKMORMixer3DRenderFunction(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*) SELF;
	CAAudioUnitZKM* caAU = theAU->mAudioUnit;
	OSStatus err = caAU->Render(ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	UInt32 i, numberBuffers = ioData->mNumberBuffers;
	// Workaround an apparent bug in the Mixer3D -- it doesn't correctly set the size of the data in the buffer
	for (i = 0; i < numberBuffers; i++) ioData->mBuffers[i].mDataByteSize = inNumberFrames * sizeof(Float32);
	return err;
}

@implementation ZKMORMixer3D
- (void)dealloc {
	if (mChannelLayout) delete mChannelLayout;
	[super dealloc];
}

- (id)init
{
	Component comp;
	ComponentDescription desc;
	AudioUnit copyMixer3D;
	
	desc.componentType = kAudioUnitType_Mixer;
	desc.componentSubType = kAudioUnitSubType_3DMixer;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent(NULL, &desc);
	if (comp == NULL) return nil;
	if (OpenAComponent(comp, &copyMixer3D)) return nil;
	
	return [super initWithAudioUnit: copyMixer3D disposeWhenDone: YES];
}

#pragma mark _____ ZKMORConduit Overrides
- (id)initWithAudioUnit:(AudioUnit)audioUnit {
	if (self = [super initWithAudioUnit: audioUnit]) {
			// by default I have 64 input buses
		[self setNumberOfInputBuses: 1];
		mChannelLayout = new CAAudioChannelLayout;
		mAudioUnit->GetChannelLayout(kAudioUnitScope_Output, 0, *mChannelLayout);
	}
	return self;
}

- (Class)inputBusClass { return [ZKMORMixer3DInputBus class]; }
- (ZKMORRenderFunction)renderFunction { return ZKMORMixer3DRenderFunction; }

#pragma mark _____ Metring
- (BOOL)isMeteringOn 
{
	UInt32 isMeteringOn;
	UInt32 dataSize = sizeof(isMeteringOn);

	OSStatus err = mAudioUnit->GetProperty(	kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
											&isMeteringOn, &dataSize);
	if (err) {
		ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("isMeteringOn>>error : %i"), err);
		isMeteringOn = 0;
	}
	return (BOOL)isMeteringOn;
}

- (void)setMeteringOn:(BOOL)isMeteringOn 
{ 
	UInt32 meteringValue = isMeteringOn;
	UInt32 dataSize = sizeof(meteringValue);

	OSStatus err = mAudioUnit->SetProperty(	kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
											&meteringValue, dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setMeteringOn>>error : %i"), err);
}


#pragma mark _____ Channel Properties
- (AudioChannelLayoutTag)channelLayoutTag { return mChannelLayout->Tag(); }

- (void)setChannelLayoutTag:(AudioChannelLayoutTag)channelLayoutTag 
{
	mChannelLayout->SetWithTag(channelLayoutTag);
		// set it
	mAudioUnit->SetChannelLayout(kAudioUnitScope_Output, 0, *mChannelLayout);
		// retrieve it to get the current value
	mAudioUnit->GetChannelLayout(kAudioUnitScope_Output, 0, *mChannelLayout);
}

- (void)useStereo { [self setChannelLayoutTag: kAudioChannelLayoutTag_Stereo]; }
- (void)useStereoHeadphones { [self setChannelLayoutTag: kAudioChannelLayoutTag_StereoHeadphones]; }
- (void)useQuad { [self setChannelLayoutTag: kAudioChannelLayoutTag_Quadraphonic]; }
- (void)use5Dot0 { [self setChannelLayoutTag: kAudioChannelLayoutTag_MPEG_5_0_A]; }

#pragma mark _____ ZKMORConduit Overrides
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	
	char* speakerConfiguration;
	switch ([self channelLayoutTag]) {
		case kAudioChannelLayoutTag_Stereo:
			speakerConfiguration = "Stereo";
			break;
		case kAudioChannelLayoutTag_Quadraphonic:
			speakerConfiguration = "Quad";
			break;			
		case kAudioChannelLayoutTag_MPEG_5_0_A: 
			speakerConfiguration = "MPEG 5.0 L R C Ls Rs";
			break;
		default:
			speakerConfiguration = "Unknown";
	}
	short speakerConfigType;
	short speakerConfigNumChannels;
		// the top 2 bytes are the config type
	speakerConfigType = [self channelLayoutTag] >> 16;
		// the bottom 2 bytes are the number of channels
	speakerConfigNumChannels = ([self channelLayoutTag] & 0x0000FFFF);
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(myLevel, source, CFSTR("%s\tSpeaker Configuration: (%hu<<16) | %hu (%s)"), indentStr, speakerConfigType, speakerConfigNumChannels, speakerConfiguration);
}

@end

@implementation ZKMORMixer3DInputBus

#pragma mark _____ Spatialization Algorithm
- (unsigned)spatializationAlgorithm {
	UInt32 spatAlgoithm;
	UInt32 dataSize = sizeof(spatAlgoithm);
	ComponentResult err;
	err = BUSAUPTR->GetProperty(	kAudioUnitProperty_SpatializationAlgorithm, _scope, _busNumber,
									&spatAlgoithm, &dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("spatializationAlgorithm>>error %i"), err);
	return spatAlgoithm;
}

- (void)setSpatializationAlgorithm:(unsigned)spatAlgoithm {
	UInt32 dataSize = sizeof(spatAlgoithm);
	ComponentResult err;
	err = BUSAUPTR->SetProperty(	kAudioUnitProperty_SpatializationAlgorithm, _scope, _busNumber,
									&spatAlgoithm, dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setSpatializationAlgorithm>>error : %i"), err);
}

- (void)useEqualPowerPanning { [self setSpatializationAlgorithm: kSpatializationAlgorithm_EqualPowerPanning]; }
- (void)useSphericalHead { [self setSpatializationAlgorithm: kSpatializationAlgorithm_SphericalHead]; }
- (void)useHRTF { [self setSpatializationAlgorithm: kSpatializationAlgorithm_HRTF]; }
- (void)useSoundField { [self setSpatializationAlgorithm: kSpatializationAlgorithm_SoundField]; }
- (void)useVectorBasedPanning { [self setSpatializationAlgorithm: kSpatializationAlgorithm_VectorBasedPanning]; }
- (void)useStereoPassThrough { [self setSpatializationAlgorithm: kSpatializationAlgorithm_StereoPassThrough]; }

#pragma mark _____ Doppler Properties
- (BOOL)isDopplerShifting {
	UInt32 isDopplerShifting;
	UInt32 dataSize = sizeof(isDopplerShifting);
	ComponentResult err;
	err = BUSAUPTR->GetProperty(	kAudioUnitProperty_DopplerShift, _scope, _busNumber,
									&isDopplerShifting, &dataSize);
		
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("isDopplerShifting>>error : %i"), err);
	return isDopplerShifting;
}

- (void)setDopplerShifting:(BOOL)useDopplerShift {
	UInt32 dataSize = sizeof(useDopplerShift);
	ComponentResult err;
	err = BUSAUPTR->SetProperty(	kAudioUnitProperty_DopplerShift, _scope, _busNumber,
									&useDopplerShift, dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setDopplerShifting>>error : %i"), err);
}

- (void)setUseDopplerShifting { [self setDopplerShifting: YES]; }
- (void)setNoDopplerShifting { [self setDopplerShifting: NO]; }

#pragma mark _____ Rendering Flags
- (unsigned)renderingFlags {
	UInt32 renderFlags;
	UInt32 dataSize = sizeof(renderFlags);
	ComponentResult err;
	err = BUSAUPTR->GetProperty(	kAudioUnitProperty_3DMixerRenderingFlags, _scope, _busNumber,	
									&renderFlags, &dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("renderingFlags>>error : %i"), err);
	return renderFlags;
}

- (void)setRenderingFlags:(unsigned)renderingFlags {
	UInt32 dataSize = sizeof(renderingFlags);
	ComponentResult err;
	err = BUSAUPTR->SetProperty(	kAudioUnitProperty_3DMixerRenderingFlags, _scope, _busNumber,
									&renderingFlags, dataSize);
	if (err) ZKMORLogError(kZKMORLogSource_AudioUnit, CFSTR("setRenderingFlags>>error : %i"), err);
}


- (float)azimuth { return [self valueOfParameter: k3DMixerParam_Azimuth]; }
- (void)setAzimuth:(float)azimuth { [self setValueOfParameter: k3DMixerParam_Azimuth value: azimuth]; }
- (float)elevation { return [self valueOfParameter: k3DMixerParam_Elevation]; }
- (void)setElevation:(float)elevation { [self setValueOfParameter: k3DMixerParam_Elevation value: elevation]; }
- (float)distance { return [self valueOfParameter: k3DMixerParam_Distance]; }
- (void)setDistance:(float)distance { [self setValueOfParameter: k3DMixerParam_Distance value: distance]; }
- (void)setAzimuth:(float)azimuth elevation:(float)elevation distance:(float)distance {
	// works for now, but can be improved in the future to change these as a package
	[self setAzimuth: azimuth];
	[self setElevation: elevation];
	[self setDistance: distance];
}

#pragma mark _____ Parameters
- (float)gain { return [self valueOfParameter: k3DMixerParam_Gain]; }
- (void)setGain:(float)gain { [self setValueOfParameter: k3DMixerParam_Gain value: gain]; }
- (float)playbackRate { return [self valueOfParameter: k3DMixerParam_PlaybackRate]; }
- (void)setPlaybackRate:(float)rate { [self setValueOfParameter: k3DMixerParam_PlaybackRate value: rate]; }

#pragma mark _____ Metering
- (float)preAveragePower { return [self valueOfParameter: k3DMixerParam_PreAveragePower]; }
- (float)postAveragePower { return [self valueOfParameter: k3DMixerParam_PrePeakHoldLevel]; }
- (float)prePeakHoldLevelPower { return [self valueOfParameter: k3DMixerParam_PostAveragePower]; }
- (float)postPeakHoldLevelPower { return [self valueOfParameter: k3DMixerParam_PostPeakHoldLevel]; }

#pragma mark _____ ZKMORConduit Overrides
- (void)logAtLevel:(unsigned)level source:(unsigned)source indent:(unsigned)indent tag:(NSString *)tag
{
	[super logAtLevel: level source: source indent: indent tag: tag];
	unsigned myLevel = level | kZKMORLogLevel_Continue;
	
		// no trailing space at the end of the string, because
		// the print method for render flags inserts one.
	unsigned renderFlags = [self renderingFlags];
	char renderingStr[255];
	size_t strSize = 255;
	unsigned numPrinted = 0;
	if (k3DMixerRenderingFlags_InterAuralDelay & renderFlags)
		numPrinted += snprintf(&renderingStr[numPrinted], (strSize - numPrinted), "IAD ");
	if (k3DMixerRenderingFlags_DopplerShift & renderFlags)
		numPrinted += snprintf(&renderingStr[numPrinted], (strSize - numPrinted), "Doppler ");
	if (k3DMixerRenderingFlags_DistanceAttenuation & renderFlags)
		numPrinted += snprintf(&renderingStr[numPrinted], (strSize - numPrinted), "Distance Attenuation ");
	if (k3DMixerRenderingFlags_DistanceFilter & renderFlags)
		numPrinted += snprintf(&renderingStr[numPrinted], (strSize - numPrinted), "Distance Filter ");
	if (k3DMixerRenderingFlags_DistanceDiffusion & renderFlags)
		numPrinted += snprintf(&renderingStr[numPrinted], (strSize - numPrinted), "Distance Diffusion ");	
		
	char indentStr[16];
	ZKMORGenerateIndentString(indentStr, 16, indent);
	ZKMORLog(myLevel, source, CFSTR("%s\tRendering: %s"), indentStr, renderingStr);
	
	char* spatAlgo;
	switch ([self spatializationAlgorithm]) {
		case kSpatializationAlgorithm_EqualPowerPanning:
			spatAlgo = "Equal Power Panning";
			break;
		case kSpatializationAlgorithm_SphericalHead:
			spatAlgo = "Spherical Head";
			break;			
		case kSpatializationAlgorithm_HRTF: 
			spatAlgo = "HRTF";
			break;
		case kSpatializationAlgorithm_SoundField: 
			spatAlgo = "Sound Field";
			break;
		case kSpatializationAlgorithm_VectorBasedPanning: 
			spatAlgo = "Vector Based Panning";
			break;
		case kSpatializationAlgorithm_StereoPassThrough: 
			spatAlgo = "Stereo Pass Through";
			break;									
		default:
			spatAlgo = "Unknown";
	}
	ZKMORLog(myLevel, source, CFSTR("%s\tAlgorithm: %s"), indentStr, spatAlgo);
	ZKMORLog(myLevel, source, CFSTR("%s\t{ %7.2f, %7.2f, %7.2f }"), indentStr, 
		[self distance], [self azimuth], [self elevation]);
}						

@end
