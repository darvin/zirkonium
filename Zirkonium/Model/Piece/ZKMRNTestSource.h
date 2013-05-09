//
//  ZKMRNTestSource.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import "ZKMRNAudioSource.h"


@interface ZKMRNTestSource : ZKMRNAudioSource {
	// internally cached objects
		// also stored in the ManagedObject store at conduit
	ZKMORGraph*			_noiseGraph;
	ZKMORMixerMatrix*	_noiseMixer;
	ZKMORPinkNoise*		_pinkNoise;
	ZKMORWhiteNoise*	_whiteNoise;
}

@end
