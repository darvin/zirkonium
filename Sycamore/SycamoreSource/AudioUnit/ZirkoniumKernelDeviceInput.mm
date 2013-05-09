//
//  ZirkoniumKernelDeviceInput.m
//  SimpleDeviceTest
//
//  Created by Jens on 27.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZirkoniumKernelDeviceInput.h"
#import "ZKMORAudioUnit.h"
#import "ZKMORGraph.h"
#import "ZKMORLogger.h"
#import "ZKMORAudioHardwareSystem.h"
#import "ZKMORException.h"
#import "ZKMORClock.h"
#include "CAAudioHardwareSystem.h"
#include "CAAudioHardwareDevice.h"
#include "CAAudioUnitZKM.h"
#include "CAException.h"

// Input IO Proc
// Receiving input for 1 buffer + safety offset into the past
OSStatus InputIOProc (	AudioDeviceID			inDevice,
						const AudioTimeStamp*	inNow,
						const AudioBufferList*	inInputData,
						const AudioTimeStamp*	inInputTime,
						AudioBufferList*		outOutputData,
						const AudioTimeStamp*	inOutputTime,
						void*					inClientData)
{
	//NSLog(@"InputIOProc");
	ZirkoniumDeviceInputStruct* theInput = (ZirkoniumDeviceInputStruct*) inClientData;
	
	switch (theInput->mInputProcState) {
	case kStarting:
		theInput->mInputProcState = kRunning;
		theInput->mStartingInputSampleTime = inInputTime->mSampleTime;
		break;
	case kStopRequested:
		//AudioDeviceStop(inDevice, InputIOProc);
		theInput->mInputProcState = kOff;
		return noErr;
	default:
		break;
	}
	
	theInput->mLastInputSampleCount = inInputTime->mSampleTime - theInput->mStartingInputSampleTime;
	theInput->mInputBuffer->Store((const Byte *)inInputData->mBuffers[0].mData, 
								theInput->mBufferSizeFrames,
								UInt64(/*inInputTime->mSampleTime*/theInput->mLastInputSampleCount));
	//theInput->mInputBuffer->Debug();
	//NSLog(@"IN: time: %d", (int)theInput->mLastInputSampleCount);	

	return noErr;
}


static OSStatus ZKMORZirkoniumDeviceInputRenderFunc(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	//NSLog(@"Zirkonium Device Input Render Func");
	ZirkoniumDeviceInputStruct* theInput = (ZirkoniumDeviceInputStruct*) SELF;
	ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*)theInput->_outputUnit;
	CAAudioUnitZKM* caAU = theAU->mAudioUnit;
	//OSStatus status = caAU->Render(ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);

	switch (theInput->mOutputProcState) {
	case kStarting:
		if (theInput->mInputProcState == kRunning) {
			theInput->mOutputProcState = kRunning;
			theInput->mIODeltaSampleCount = inTimeStamp->mSampleTime - theInput->mLastInputSampleCount;
		}
		return noErr;
	case kStopRequested:
		//AudioDeviceStop(inDevice, This->mOutputIOProc);
		theInput->mOutputProcState = kOff;
		//return noErr;
	default:
		break;
	}
	
	double delta = theInput->mInputBuffer->Fetch(theInput->mWorkBuf, 
						theInput->mBufferSizeFrames, UInt64(inTimeStamp->mSampleTime - theInput->mInToOutSampleOffset));
	
	//NSLog(@"Delta: %f", delta);
	
	UInt32 innchnls = theInput->mFormat.mChannelsPerFrame;
	//NSLog(@"In Channels: %d", innchnls); 		
	for (UInt32 buf = 0; buf < ioData->mNumberBuffers; buf++)
	{	//
		//NSLog(@"Buffer %d", (int)buf);
		UInt32 outnchnls = ioData->mBuffers[buf].mNumberChannels;
		//NSLog(@"Out Channels: %d", outnchnls);
		for (UInt32 chan = 0; chan < innchnls; chan++) {
			//NSLog(@"Channel %d", (int)chan);
			UInt32 outChan = chan;		
			
			if (outChan >= 0 && outChan < outnchnls) {
				// odd-even
				//NSLog(@"Process ... Channel %d", (int)outChan);
				
				float *inP  = (float *)theInput->mWorkBuf + (chan % innchnls); 
				//NSLog(@"Processing WorkBuffer Channel: %d", (chan % innchnls)); 
				float *outP = (float *)ioData->mBuffers[buf].mData + outChan;		
				long framesize = outnchnls * sizeof(float);

				for (UInt32 frame = 0; frame < ioData->mBuffers[buf].mDataByteSize; frame += framesize ) {
					//NSLog(@"Frame %d", (int)frame);
					*outP += *inP;
					inP += innchnls;
					outP += outnchnls;
				}
			}
		}
	}

	//NSLog(@"OUT: time %d", (int)inTimeStamp->mSampleTime);
	
	return noErr; //status;
}

@implementation ZirkoniumKernelDeviceInput

- (id)initWithDeviceOutput:(ZKMORDeviceOutput *)deviceOutput
{
	if(self = [super init]) { //WithDeviceOutput:deviceOutput]) {
	
		_conduitType = kZKMORConduitType_Source;

		_deviceOutput = deviceOutput;
		_outputUnit = [_deviceOutput outputUnit];
	
		mInputBuffer = new AudioRingBuffer(4, 88200);
		
		mIsInput = YES;
		mWorkBuf = NULL;
		mRunning = false;
		mMuting = false;
		mThruing = true;
		mBufferSize = 512; 
		mExtraLatencyFrames = 0; 

	}
	
	return self; 
}

-(void)dealloc
{
	delete mInputBuffer;
	
	[super dealloc];
}

- (ZKMORRenderFunction)renderFunction { return ZKMORZirkoniumDeviceInputRenderFunc; }

-(void)startDevice
{
	if (mRunning) return;
	
	//todo: possibly match sample rates ...

	mID = [[[super deviceOutput] outputDevice] audioDeviceID]; 
	
	UInt32 propsize;
	
	propsize = sizeof(UInt32);
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertySafetyOffset, &propsize, &mSafetyOffset));
	
	propsize = sizeof(UInt32);
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertyBufferFrameSize, &propsize, &mBufferSizeFrames));
	
	mFormat = [[self outputBusAtIndex:0] streamFormat];
	mSampleRate = mFormat.mSampleRate;

	mInputBuffer->Allocate([[self outputBusAtIndex:0] streamFormat].mBytesPerFrame, UInt32(kSecondsInRingBuffer * [[self outputBusAtIndex:0] streamFormat].mSampleRate));

	NSLog(@"WorkBuffer: Byte[%d]", mBufferSizeFrames * mFormat.mBytesPerFrame);
	mWorkBuf = new Byte[mBufferSizeFrames * mFormat.mBytesPerFrame];
	memset(mWorkBuf, 0, mBufferSizeFrames * mFormat.mBytesPerFrame);
		
	mRunning = true;
	
	mInputProcState = kStarting;
	mOutputProcState = kStarting;
	
	verify_noerr (AudioDeviceAddIOProc(mID, InputIOProc, self));
	verify_noerr (AudioDeviceStart(mID, InputIOProc));
	
	//while (mInputProcState != kRunning || mOutputProcState != kRunning)
	//	usleep(1000);
		
	[self computeThruOffset];
	

}

-(void)stopDevice
{
	if (!mRunning) return;
	mRunning = false;
	
	mInputProcState = kStopRequested;
	mOutputProcState = kStopRequested;
	
	mInputBuffer->Clear();
	
	//while (mInputProcState != kOff || mOutputProcState != kOff)
	//	usleep(5000);

	//Todo: remove IO Proc
	AudioDeviceRemoveIOProc(mID, InputIOProc);
	//AudioDeviceRemoveIOProc(mInputDevice.mID, InputIOProc);
	//AudioDeviceRemoveIOProc(mOutputDevice.mID, mOutputIOProc);
	
	if (mWorkBuf) {
		delete[] mWorkBuf;
		mWorkBuf = NULL;
	}
}

-(void)computeThruOffset
{
	if (!mRunning) {
		mActualThruLatency = 0;
		mInToOutSampleOffset = 0;
		return;
	}
	
	mActualThruLatency = SInt32(mSafetyOffset + mBufferSizeFrames + mExtraLatencyFrames);
	mInToOutSampleOffset = SInt32(-512); //mActualThruLatency + mIODeltaSampleCount;
	NSLog(@"InOutSampleOffset: %d", (int)mInToOutSampleOffset);
}

- (void)outputDeviceChanged
{
	[self stopDevice];
	[super outputDeviceChanged];
	[self startDevice];

	/*
	if (![_deviceOutput isInputEnabled]) return;
	
	[self uninitialize];
	Float64 sampleRate = [[_deviceOutput outputDevice] nominalSampleRate];
	ZKMORConduitBus* outputBus = [self outputBusAtIndex: 0];
	[outputBus setSampleRate: sampleRate];
	[self initialize];	
	*/
}


@end


