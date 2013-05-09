//
//  ZKMRLPannerLight.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLPannerLight.h"
#import "ZKMRLMixerLight.h"


@implementation ZKMRLPannerLight

- (void)dealloc
{
	if (_panner) [_panner release];
	if (_mixer) [_mixer release]; 
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	_panner = [[ZKMNRVBAPPanner alloc] init];
	
	return self;
}

#pragma mark _____ Accessors
- (ZKMNRSpeakerLayout *)lampLayout { return [_panner speakerLayout]; }
- (void)setLampLayout:(ZKMNRSpeakerLayout *)lampLayout { [_panner setSpeakerLayout: lampLayout]; }

- (ZKMNRSpeakerPosition *)lampClosestToPoint:(ZKMNRSphericalCoordinate)point { return [_panner speakerClosestToPoint: point]; }

- (ZKMRLMixerLight *)mixer { return _mixer; }
- (void)setMixer:(ZKMRLMixerLight *)mixer
{
	if (mixer) [mixer retain];
	if (_mixer) [_mixer release];
	_mixer = mixer;
}

- (NSArray *)speakerMesh { return [_panner speakerMesh]; }

#pragma mark _____ Actions
- (void)transferPanningForSource:(ZKMNRPannerSource *)source index:(unsigned)idx
{
	unsigned j, outputCount = [_mixer numberOfOutputChannels];
	float* coeffs = [source mixerCoefficients];
	for (j = 0; j < outputCount; j++) {
		[_mixer setValue: coeffs[j] forCrosspointInput: idx output: j];
	}
	[source setSynchedWithMixer: YES];
}

- (void)transferPanningToMixer
{
	NSArray* activeSources = [_panner activeSources];
	unsigned i, numberOfSources = [activeSources count];
	NSNull* globalNull = [NSNull null];
	for (i = 0; i < numberOfSources; i++) {
		if (globalNull == [activeSources objectAtIndex: i]) continue;
		ZKMNRPannerSource* source = [activeSources objectAtIndex: i];
		[self transferPanningForSource: source index: i];
	}
	
	[_mixer updateOutputColors];
}

- (void)updatePanningToMixer
{
	NSArray* activeSources = [_panner activeSources];
	unsigned i, numberOfSources = [activeSources count];
	NSNull* globalNull = [NSNull null];
	for (i = 0; i < numberOfSources; i++) {
		if (globalNull == [activeSources objectAtIndex: i]) continue;
		ZKMNRPannerSource* source = [activeSources objectAtIndex: i];
		if ([source isSynchedWithMixer]) continue;
		[self transferPanningForSource: source index: i];
	}
}

#pragma mark _____ ZKMRLPannerLightSourceMagement
- (void)registerPannerSource:(ZKMNRPannerSource *)source { [_panner registerPannerSource: source]; }
- (void)unregisterPannerSource:(ZKMNRPannerSource *)source { [_panner unregisterPannerSource: source]; }

- (NSArray *)activeSources { return [_panner activeSources]; }

- (void)beginEditingActiveSources { [_panner beginEditingActiveSources]; }
- (void)setNumberOfActiveSources:(unsigned)numberOfSources { [_panner setNumberOfActiveSources: numberOfSources]; }
- (void)setActiveSource:(ZKMNRPannerSource *)source atIndex:(unsigned)idx { [_panner setActiveSource: source atIndex: idx]; }
- (void)setActiveSources:(NSArray *)sources { [_panner setActiveSources: sources]; }
- (void)endEditingActiveSources { [_panner endEditingActiveSources]; }

@end
