//
//  ZirkoniumKernelDeviceInput.h
//  SimpleDeviceTest
//
//  Created by Jens on 27.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMORDeviceOutput.h"
#import "ZKMORConduit.h"
#import "AudioRingBuffer.h"

#define kSecondsInRingBuffer 2.


#ifndef __ZIRKONIUM_KERNEL_DEVICE_INPUT_H__
#define __ZIRKONIUM_KERNEL_DEVICE_INPUT_H__

enum IOProcState {
		kOff,
		kStarting,
		kRunning,
		kStopRequested
	};

@interface ZirkoniumKernelDeviceInput : ZKMORDeviceInput {
	
	AudioRingBuffer *mInputBuffer;

	AudioDeviceID					mID;
	bool							mIsInput;
	UInt32							mSafetyOffset;
	UInt32							mBufferSizeFrames;
	AudioStreamBasicDescription		mFormat;
	Float64							mSampleRate;

	bool			mRunning;
	bool			mMuting;
	bool			mThruing;
	UInt32			mBufferSize;

	SInt32			mExtraLatencyFrames;
	SInt32			mActualThruLatency;
	Float64			mLastInputSampleCount, mIODeltaSampleCount;
	Float64			mStartingInputSampleTime; 
	Float64			mInToOutSampleOffset;		// subtract from the output time to obtain input time

	IOProcState		mInputProcState, mOutputProcState;	
	
	Byte			*mWorkBuf;

}

-(void)startDevice;
-(void)stopDevice; 
-(void)computeThruOffset;

- (id)initWithDeviceOutput:(ZKMORDeviceOutput *)deviceOutput;


@end

typedef struct { @defs(ZirkoniumKernelDeviceInput) } ZirkoniumDeviceInputStruct;


#endif