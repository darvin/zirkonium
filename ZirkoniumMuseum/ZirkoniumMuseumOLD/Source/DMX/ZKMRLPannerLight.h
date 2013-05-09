//
//  ZKMRLPannerLight.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>


@class ZKMRLMixerLight;
///  
///  ZKMRLPannerLight
///  
///  The Panner Light is a decorator on a VBAP Panner for light panning.
///
@interface ZKMRLPannerLight : NSObject {
	ZKMNRVBAPPanner*	_panner;
	ZKMRLMixerLight*	_mixer;
}

//  Accessors
- (ZKMNRSpeakerLayout *)lampLayout;
- (void)setLampLayout:(ZKMNRSpeakerLayout *)lampLayout;

- (ZKMNRSpeakerPosition *)lampClosestToPoint:(ZKMNRSphericalCoordinate)point;

	/// The mixer this panner controls. The user is responsible for keeping the number of inputs / outputs 
	/// in synch with the panner's number of sources / speaker layout.
- (ZKMRLMixerLight *)mixer;
- (void)setMixer:(ZKMRLMixerLight *)mixer;

- (NSArray *)speakerMesh;

//  Actions
	/// Transfers panning for all sources, whether or not they think they are synched
- (void)transferPanningToMixer;
	/// Transfers panning only for sources that are not synched
- (void)updatePanningToMixer;

@end


@interface ZKMRLPannerLight (ZKMRLPannerLightSourceMagement)
- (void)registerPannerSource:(ZKMNRPannerSource *)source;
- (void)unregisterPannerSource:(ZKMNRPannerSource *)source;

- (NSArray *)activeSources;

- (void)beginEditingActiveSources;
- (void)setNumberOfActiveSources:(unsigned)numberOfSources;
- (void)setActiveSource:(ZKMNRPannerSource *)source atIndex:(unsigned)idx;
	// internally calls setNumberOfActiveSources: and setActiveSource
- (void)setActiveSources:(NSArray *)sources;
- (void)endEditingActiveSources;
@end

