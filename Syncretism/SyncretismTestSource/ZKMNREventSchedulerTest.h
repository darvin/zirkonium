//
//  ZKMNREventSchedulerTest.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 10.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "ZKMNRAbstractProcessorTest.h"

@interface ZKMNRSchedulerTestEvent : ZKMNREvent {

}

@end

@interface ZKMNREventSchedulerTest : ZKMNRAbstractProcessorTest <ZKMNRTimeDependent> {
	ZKMNREventScheduler*		scheduler;
	ZKMNRSchedulerTestEvent*	testEvent;
	BOOL					wasEventInvoked;
	BOOL					wasEventInvokedEarly;
	BOOL					wasEventInvokedTwice;
}

@end
