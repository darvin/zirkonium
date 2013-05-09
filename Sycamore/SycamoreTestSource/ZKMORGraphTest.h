//
//  ZKMORGraphTest.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 29.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <Sycamore/Sycamore.h>


@interface ZKMORGraphTest : SenTestCase {
		//  Graph Objects
	ZKMORGraph*				graph;
	ZKMORWhiteNoise*		noise;
	ZKMORMixerMatrix*		mixer;
	ZKMORRenderSimulator*	simulator;

@public
	BOOL			wasPreRenderCalled;
	BOOL			wasPostRenderCalled;
	BOOL			wereNotificationsCalledInOrder;
	BOOL			wereNotificationsCalledAfterRemoval;
	unsigned		callNumber;
}

@end
