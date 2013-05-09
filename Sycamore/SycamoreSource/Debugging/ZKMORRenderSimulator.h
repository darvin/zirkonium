//
//  ZKMORRenderSimulator.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 28.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORConduit.h"
#import "ZKMOROutput.h"

///
///  ZKMORRenderSimulator
///
///  Simulates the rendering of a conduit -- useful for debugging
///
@interface ZKMORRenderSimulator : NSObject {
	ZKMORConduit*	_conduit;
	NSError*		_error;
}

//  Accessing
- (ZKMORConduit *)conduit;
- (void)setConduit:(ZKMORConduit *)conduit;
- (NSError *)error;

//  Actions
- (void)simulateNumCalls:(unsigned)numCalls numFrames:(unsigned)numFrames bus:(unsigned)busNumber;

@end


///
///  ZKMOROutputSimulator
///
///  Simulates the rendering of a graph -- useful for debugging
///
ZKMDECLCPPT(AUOutputBL)
ZKMDECLCPPT(CAAudioTimeStamp)
@interface ZKMOROutputSimulator : ZKMOROutput {
	ZKMCPPT(AUOutputBL)			mBufferList;
	ZKMCPPT(CAAudioTimeStamp)	mTimeStamp;
	NSError*					_error;
}

//  Accessing
- (NSError *)error;

//  Actions
- (void)simulateNumCalls:(unsigned)numCalls numFrames:(unsigned)numFrames;

@end
