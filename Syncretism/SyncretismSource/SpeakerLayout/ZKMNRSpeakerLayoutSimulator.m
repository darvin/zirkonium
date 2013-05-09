//
//  ZKMNRSpeakerLayoutSimulator.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 20.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRSpeakerLayoutSimulator.h"
#import "ZKMORMixer3D.h"
#import "ZKMNRSpeakerLayout.h"

@interface ZKMNRSpeakerLayoutSimulator (ZKMNRSpeakerLayoutSimulatorPrivate)
- (void)synchronizeMixerToSpeakerLayout;
@end


@implementation ZKMNRSpeakerLayoutSimulator
#pragma mark _____ NSObject Overrides
- (void)dealloc
{
	if (_mixer3D) [_mixer3D release];
	if (_speakerLayout) [_speakerLayout release];
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	_speakerLayout = nil;
	_mixer3D = [[ZKMORMixer3D alloc] init];
	[self setSimulationMode: kZKMNRSpeakerLayoutSimulationMode_Headphones];
	return self;
}

#pragma mark _____ Accessors
- (ZKMNRSpeakerLayout *)speakerLayout { return _speakerLayout; }
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout 
{ 
	if (_speakerLayout) [_speakerLayout release];
	_speakerLayout = speakerLayout;
	if (_speakerLayout) [_speakerLayout retain];
	
	[self synchronizeMixerToSpeakerLayout];
}

- (ZKMNRSimulationMode)simulationMode { return _simulationMode; }
- (void)setSimulationMode:(ZKMNRSimulationMode)simulationMode 
{ 
	_simulationMode = simulationMode;
	[self synchronizeMixerToSpeakerLayout];
}

- (ZKMORMixer3D *)mixer3D { return _mixer3D; }

#pragma mark _____ ZKMNRSpeakerLayoutSimulator
- (void)synchronizeMixerToSpeakerLayout
{
	BOOL using5Dot0 = (kZKMNRSpeakerLayoutSimulationMode_5Dot0 == _simulationMode);

	unsigned i, numberOfSpeakers = [_speakerLayout numberOfSpeakers];
	[_mixer3D uninitialize];
	[_mixer3D setNumberOfInputBuses: numberOfSpeakers];
	
	AudioStreamBasicDescription streamFormat = [[_mixer3D outputBusAtIndex: 0] streamFormat];
		// set the speaker configuration
	if (using5Dot0) {
		ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 5);
		[[_mixer3D outputBusAtIndex: 0] setStreamFormat: streamFormat];
		[_mixer3D use5Dot0];
	} else {
		ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 2);
		[[_mixer3D outputBusAtIndex: 0] setStreamFormat: streamFormat];
		[_mixer3D useStereoHeadphones];
	}
	
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
		// position the buses
	for (i = 0; i < numberOfSpeakers; i++) {
		ZKMORMixer3DInputBus* mixerBus = (ZKMORMixer3DInputBus*) [_mixer3D inputBusAtIndex: i];
		[mixerBus setStreamFormat: streamFormat];
		ZKMNRSpeakerPosition* speakerPosition = [[_speakerLayout speakerPositions] objectAtIndex: i];
		ZKMNRSphericalCoordinate coord = [speakerPosition coordPhysical];
		
		[mixerBus setAzimuth: ZKMNRSphericalCoordinateMixer3DAzimuth(&coord)];		
		[mixerBus setElevation: ZKMNRSphericalCoordinateMixer3DElevation(&coord)];
		[mixerBus setDistance: ZKMNRSphericalCoordinateMixer3DDistance(&coord)];
		(using5Dot0) ? [mixerBus useVectorBasedPanning] : [mixerBus useHRTF];
		[mixerBus setRenderingFlags: k3DMixerRenderingFlags_InterAuralDelay];
	}
}

@end
