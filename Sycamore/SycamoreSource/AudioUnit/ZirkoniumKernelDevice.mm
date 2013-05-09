//
//  ZirkoniumKernelEngine.m
//  SimpleDeviceTest
//
//  Created by Jens on 27.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZirkoniumKernelDevice.h"
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


static OSStatus ZirkoniumDeviceRenderFunction(	id							SELF,
										AudioUnitRenderActionFlags 	* ioActionFlags,
										const AudioTimeStamp 		* inTimeStamp,
										UInt32						inOutputBusNumber,
										UInt32						inNumberFrames,
										AudioBufferList				* ioData)
{
	//NSLog(@"Zirkonium Device Render Func");  
	ZirkoniumDeviceStruct* deviceOutputStruct = (ZirkoniumDeviceStruct*) SELF;
	ZKMORGraph* graph = deviceOutputStruct->_graph;
	
	OSStatus err = GraphRenderFunction(graph, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	deviceOutputStruct->_lastError = err;
	
	
	/*
	ZirkoniumDeviceInputStruct* theInput = (ZirkoniumDeviceInputStruct*) deviceOutputStruct->_kernelInput;
	//ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*)theInput->_outputUnit;
	//CAAudioUnitZKM* caAU = theAU->mAudioUnit;


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

	//NSLog(@"delta %f", delta);

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

	//return noErr;
	*/
	return err; 
}

@implementation ZirkoniumKernelDevice

- (id)init
{
	if (![super init]) return nil;
	
	[self stopDeviceRunning];
	//change the input to our Input Device
	
	if(_deviceInput) {
		[_deviceInput release];
		_deviceInput = nil; 
	}

	AURenderCallbackStruct callback = { (AURenderCallback) ZirkoniumDeviceRenderFunction, self };
	[[super outputUnit] setCallback: &callback busNumber: 0];
	
	_kernelInput = [[ZirkoniumKernelDeviceInput alloc] initWithDeviceOutput:self]; 
	
	if ([super canDeliverInput]) {
		[super setInputEnabled: YES];
	}
	
	[self startDeviceRunning];
	
	return self;
}

-(void)startDeviceRunning
{
	//todo: possibly match sample rates ...
	if(_kernelInput)
		[(ZirkoniumKernelDeviceInput*)_kernelInput startDevice];
	
	[super startDeviceRunning];
}

-(void)stopDeviceRunning
{
	if(_kernelInput)
		[(ZirkoniumKernelDeviceInput*)_kernelInput stopDevice];
		
	[super stopDeviceRunning];
}

- (ZKMORDeviceInput *)deviceInput 
{ 
	return (ZKMORDeviceInput*)_kernelInput; 
}

@end
