//
//  ZKMNRPannerEventTest.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 17.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "ZKMNRAbstractProcessorTest.h"


@interface ZKMNRPannerEventTest : ZKMNRAbstractProcessorTest {
	ZKMNREventScheduler*		scheduler;
	ZKMNRVBAPPanner*			panner;
	ZKMNRPannerSource*			source;
}

@end
