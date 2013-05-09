//
//  ZKMORQuickTime.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORQuickTime.h"
#import "ZKMORException.h"
#include "ZKMORQTReader.h"
#include "CAAudioUnitZKM.h"
#include "CAXException.h"

@interface ZKMORQTPlayer (ZKMORQTPlayerPrivate)

//  Initialization
- (void)mainThreadSendEndNotification:(id)ignored;

@end

static OSStatus QTRenderFunction(	id							SELF,
									AudioUnitRenderActionFlags 	* ioActionFlags,
									const AudioTimeStamp 		* inTimeStamp,
									UInt32						inOutputBusNumber,
									UInt32						inNumberFrames,
									AudioBufferList				* ioData)
{
	ZKMORQTPlayer* qtPlayer = (ZKMORQTPlayer*) SELF;
	CAAudioUnitZKM* converter = qtPlayer->mFormatConverter;
	return converter->Render(ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
}

static OSStatus QTPullAudioFunction(	void						* SELF,
										AudioUnitRenderActionFlags 	* ioActionFlags,
										const AudioTimeStamp 		* inTimeStamp,
										UInt32						inOutputBusNumber,
										UInt32						inNumberFrames,
										AudioBufferList				* ioData)
{
	ZKMORQTPlayer* qtPlayer = (ZKMORQTPlayer*) SELF;
	ZKMQTReader* qtReader = qtPlayer->mQTReader;
	UInt32 ioNumFrames = inNumberFrames;
	qtReader->PullBuffer(ioNumFrames, ioData);
	if (ioNumFrames < inNumberFrames) {
		ZKMORMakeBufferListTailSilent(ioData, ioActionFlags, ioNumFrames);
		if (qtReader->ReachedEndOfStream() && !qtPlayer->_sentEndNotification) {
			[qtPlayer 
				performSelectorOnMainThread: @selector(mainThreadSendEndNotification:)
				withObject: nil
				waitUntilDone: NO];
		}
	}
	return noErr;
}


@implementation ZKMORQTPlayer

- (void)dealloc
{
	if (mQTReader) delete mQTReader;
	if (mFormatConverter) delete mFormatConverter;
	if (_fileURL) [_fileURL release];
	[super dealloc];
}

- (id)init { return [self initWithNumberOfInternalBuffers: 8 size: 1920]; }

#pragma mark _____ Initialization
- (id)initWithNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers size:(unsigned)numberOfFrames
{
	if (!(self = [super init])) return nil;

	_conduitType = kZKMORConduitType_Source;
	mQTReader = new ZKMQTReader(numberOfInternalBuffers, numberOfFrames);

	CAComponent fcComponent('aufc', 'conv', 'appl');
	mFormatConverter = new CAAudioUnitZKM();
	OSStatus err = CAAudioUnitZKM::Open(fcComponent, *mFormatConverter);
	if (err) {
		[self autorelease];
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"init:create audio converter for QTPlayer>>error : %@", error);
	}
	
	_fileURL = nil;
	
	AURenderCallbackStruct callback;
	callback.inputProc = QTPullAudioFunction;
	callback.inputProcRefCon = self;
	mFormatConverter->SetRenderCallback(0, &callback);
	
	return self;
}

#pragma mark _____ Accessors
- (QTMovie *)qtMovie { return mQTReader->QTKitMovie(); }
- (QTTime)movieDuration { return mQTReader->MovieDuration(); };

- (NSURL *)fileURL { return _fileURL; }

- (void)setFileURL:(NSURL *)fileURL error:(NSError **)error
{
	if ([fileURL isEqualTo: _fileURL])
		return;
	
	[fileURL retain];
	if (_fileURL) [_fileURL release];
	_fileURL = fileURL;

	mFormatConverter->Uninitialize();
	mQTReader->SetFilePath((CFStringRef) [_fileURL path], error);
	CAStreamBasicDescription streamFormat = mQTReader->GetClientDataFormat();
	mFormatConverter->SetInputStreamFormat(0, streamFormat);
	mFormatConverter->Initialize();	
}

- (void)setFilePath:(NSString *)path error:(NSError **)error
{
	NSURL* fileURL = [NSURL fileURLWithPath: path];
	[self setFileURL: fileURL error: error];
}


- (QTTime)currentTime { return mQTReader->GetCurrentTime(); }
- (void)setCurrentTime:(QTTime)time { mQTReader->SetCurrentTime(time); }

- (double)currentPosition { return mQTReader->GetCurrentPosition(); }
- (void)setCurrentPosition:(double)position { mQTReader->SetCurrentPosition(position); }

- (id)delegate { return _delegate; }
- (void)setDelegate:(id)delegate { _delegate = delegate; }

#pragma mark _____ QT Reader Properties
- (unsigned)numberOfInternalBuffers { return mQTReader->GetNumberOfBuffers(); }
- (void)setNumberOfInternalBuffers:(unsigned)numberOfInternalBuffers 
{ 
	mQTReader = new ZKMQTReader(numberOfInternalBuffers, [self internalBufferSize]); 
}
- (unsigned)internalBufferSize { return mQTReader->GetBufferSizeFrames(); }
- (void)setInternalBufferSize:(unsigned)numberOfFrames
{
	mQTReader = new ZKMQTReader([self numberOfInternalBuffers], numberOfFrames); 
}

#pragma mark _____ Accessing Video
- (void)setVisualContext:(QTVisualContextRef)visualContext { mQTReader->SetVisualContext(visualContext); }

#pragma mark _____ Notifications
- (void)qtReaderDidEnd:(ZKMORQTPlayer *)player { }

- (void)mainThreadSendEndNotification:(id)ignored
{
	if (_sentEndNotification)
		return;

	_sentEndNotification = YES;
	if ([_delegate respondsToSelector: @selector(qtReaderDidEnd:)]) {
		[_delegate qtReaderDidEnd: self];
	}
}

#pragma mark _____ ZKMORConduit Overrides
- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return 1; }

- (void)getStreamFormatForBus:(ZKMORConduitBus*)bus 
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct*) bus;
	mFormatConverter->GetOutputStreamFormat(0, busStruct->_streamFormat);
}

- (void)setStreamFormatForBus:(ZKMORConduitBus*)bus 
{
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct*) bus;
	try {
		mFormatConverter->SetOutputStreamFormat(0, busStruct->_streamFormat);
	} catch (CAXException& e) {
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORThrow(AudioUnitError, @"QTPlayer setStreamFormatForBus:>>error: %s", errorStr);
	}
}

- (void)initialize 
{
	OSStatus err = mFormatConverter->Initialize();
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"QTPlayer initialize>>error: %@", error);
	}
	[super initialize];
}

- (void)globalReset 
{
	OSStatus err = mFormatConverter->GlobalReset();
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"QTPlayer globalReset>>error: %@", error);
	}
	[super globalReset];
}

- (void)uninitialize {
	[super uninitialize];
	OSStatus err = mFormatConverter->Uninitialize();
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"QTPlayer uninitialize>>error: %@", error);
	}
}

- (void)setMaxFramesPerSlice:(unsigned)maxFramesPerSlice
{
	try {
		mFormatConverter->SetMaximumFramesPerSlice(maxFramesPerSlice);
		[super setMaxFramesPerSlice: maxFramesPerSlice];
	} catch (CAXException& e) {
		char errorStr[255];
		e.FormatError(errorStr);
		ZKMORThrow(AudioUnitError, @"QTPlayer setMaxFramesPerSlice>>error %s", errorStr);
	}
}

- (ZKMORRenderFunction)renderFunction { return QTRenderFunction; }

#pragma mark _____ ZKMORStarting
- (void)preroll { }
- (void)start { _sentEndNotification = NO; mQTReader->StartVideo();}
- (void)stop { mQTReader->StopVideo(); }

@end
