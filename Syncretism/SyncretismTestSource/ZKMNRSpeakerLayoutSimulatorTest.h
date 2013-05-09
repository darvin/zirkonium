//
//  ZKMNRSpeakerLayoutSimulatorTest.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 20.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "ZKMNRAbstractProcessorTest.h"


@interface ZKMNRSpeakerLayoutSimulatorTest : ZKMNRAbstractProcessorTest {
	ZKMNRSpeakerLayoutSimulator*	speakerSimulator;
	ZKMORAudioFileOutput*			fileOutput;
	
	ZKMORPinkNoise*			pinkNoise;
}

@end
