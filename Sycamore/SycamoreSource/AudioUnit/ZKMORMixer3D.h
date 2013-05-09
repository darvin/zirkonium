//
//  ZKMORMixer3D.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnit.h"

ZKMDECLCPPT(CAAudioChannelLayout)

///
///  ZKMORMixer3D
///  
///  The 3D spatializing mixer
/// 
@interface ZKMORMixer3D : ZKMORAudioUnit {
	ZKMCPPT(CAAudioChannelLayout)	mChannelLayout;
}

//  Metring
- (BOOL)isMeteringOn;
- (void)setMeteringOn:(BOOL)isMeteringOn;

//  Channel Properties
	/// speaker layouts -- the 3DMixer only supports tagged layouts
- (AudioChannelLayoutTag)channelLayoutTag;
- (void)setChannelLayoutTag:(AudioChannelLayoutTag)channelLayoutTag;

- (void)useStereo;
- (void)useStereoHeadphones;
- (void)useQuad;
- (void)use5Dot0;

@end

@interface ZKMORMixer3DInputBus : ZKMORAudioUnitInputBus {

}

//  Spatialization Algorithm
- (unsigned)spatializationAlgorithm;
- (void)setSpatializationAlgorithm:(unsigned)spatAlgoithm;

	// methods for the specific spatialization algorithms
- (void)useEqualPowerPanning;
- (void)useSphericalHead;
- (void)useHRTF;
- (void)useSoundField;
- (void)useVectorBasedPanning;
- (void)useStereoPassThrough;

//  Doppler Properties
- (BOOL)isDopplerShifting;
- (void)setDopplerShifting:(BOOL)useDopplerShift;
- (void)setUseDopplerShifting;
- (void)setNoDopplerShifting;

//  Rendering Flags
	/// rendering flags -- a bitfield that can be used to turn on/off various rendering
	/// options -- see k3DMixerRenderingFlags_InterAuralDelay, etc in AudioUnitProperties.h
- (unsigned)renderingFlags;
- (void)setRenderingFlags:(unsigned)renderingFlags;

//  Parameters
- (float)azimuth;						///< -180->180
- (void)setAzimuth:(float)azimuth;

- (float)elevation;						///< -90->90
- (void)setElevation:(float)elevation;

- (float)distance;						///< 0->10000 (Meters)
- (void)setDistance:(float)distance;
- (void)setAzimuth:(float)azimuth elevation:(float)elevation distance:(float)distance;

- (float)gain;							///< -120->20 (dB)
- (void)setGain:(float)gain;

- (float)playbackRate;					///< 0.5 -> 2.0
- (void)setPlaybackRate:(float)rate;

//  Metering
- (float)preAveragePower;
- (float)postAveragePower;
- (float)prePeakHoldLevelPower;
- (float)postPeakHoldLevelPower;

@end

