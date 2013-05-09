//
//  ZKMORQTReader.mm
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORQTReader.h"
#include "ZKMORLogger.h"

// I have a component which doesn't want to run on the
// worker thread, so need to stick with the non-thread-safe 
// version for the moment. Alas.
#define NOT_THREAD_SAFE
// #define DEBUG_ZONE_QT

#pragma mark _____ ZKMQTReader
ZKMQTReader::~ZKMQTReader()
{

}

#pragma mark _____ Accessors
void	ZKMQTReader::SetFilePath(CFStringRef filePath, NSError** error)
{
#ifdef NOT_THREAD_SAFE
	RemoveFromWorkerThread();
	DisposeBuffers();
	
	SynchronousCreateMovie(filePath, error);

	AddToWorkerThread();
#else
	ZKMORLogError(kZKMORLogSource_Zone, CFSTR("ZKMQTReader::SetFilePath not implemented"));
#endif	

}

double	ZKMQTReader::GetCurrentPosition() const
{
	return double(GetCurrentFrame()) / double(GetNumberFrames());
}

void	ZKMQTReader::SetCurrentPosition(double loc)
{
	QTTime timeNew = MovieDuration();
	timeNew.timeValue = (long long) (timeNew.timeValue * loc);
	SetCurrentTime(timeNew);
}

SInt64	ZKMQTReader::GetCurrentFrame() const
{
	if (mEndOfStream) return GetNumberFrames();
	
	const QTReadBuffer *b = static_cast<const QTReadBuffer*>(GetCurrentBuffer());
	if (!b) return 0;
		// the buffer from which we're reading
	UInt32 startFrame, endFrame;
	b->GetLocation(startFrame, endFrame);
	return b->mBufferStartTime.timeValue + startFrame;
}

QTTime	ZKMQTReader::GetCurrentTime() const
{
	QTTime currentTime = MovieDuration();
	currentTime.timeValue = (long long) (currentTime.timeValue * GetCurrentPosition());
	return currentTime;
}

void	ZKMQTReader::SetCurrentTime(QTTime time)
{
	RemoveFromWorkerThread();
		SynchronousSetCurrentTime(time);
	AddToWorkerThread();
}

void	ZKMQTReader::AsyncSetCurrentTime(QTTime time)
{
	SetTimeAction* action = mSetTimeQueue.GetWriteItem();
	if (action) {
		action->time = time;
		mSetTimeQueue.ReturnWrittenItem(action);
		MarkNeedsToRun();
	} else {
		ZKMORLog(kZKMORLogLevel_Error, kZKMORLogSource_Zone, CFSTR("QT reader 0x%x -- could not set current time (queue full)"), this);
	}
}

#pragma mark _____ Visual Accessors
void	ZKMQTReader::SetVisualContext(QTVisualContextRef visualContext)
{
	if (mQTVisualContext == visualContext) return;
	
	QTVisualContextRelease(mQTVisualContext);
	mQTVisualContext = visualContext;	
	QTVisualContextRetain(mQTVisualContext);
	
	if (!mQTVisualContext || !mQTMovie) return;
	OSStatus err = SetMovieVisualContext([mQTMovie quickTimeMovie], mQTVisualContext);
	if (err) ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Could not set QT visual context, error: %i"), err);	
}

void	ZKMQTReader::StartVideo() { [mQTMovie play]; } 
void	ZKMQTReader::StopVideo() { [mQTMovie stop]; }

/* 
 * This doesn't work because QT is more efficient at decompressing than the naive approach taken here.
 * That's why I've given up on this an gone to using QT to handling the video playback. I do sent the
 * volume to 0 so that there isn't any disturbance from playing back the QT movie simultaneously.
void	ZKMQTReader::PullVideoFrame(CVImageBufferRef* outImageBufferRef, const CVTimeStamp* timeStamp)
{
	bool isValid = false;
	*outImageBufferRef = NULL;

	if (ReachedEndOfStream() || !mBuffersAreValid || (mBufferQueueState == kZKMORBufferQueueState_Paused))
		return;
	
		// get the current frame
	const QTReadBuffer* b = static_cast<const QTReadBuffer *>(GetCurrentBuffer());
	b->GrabVideoFrame(isValid, outImageBufferRef);
}
*/

#pragma mark _____ Internal Functions
void	ZKMQTReader::SetClientDataFormat(const CAStreamBasicDescription& format)
{
	SetFormat(format);
	
	mUnderflowCount = 0;
	mEndOfStream = false;
	Prime();
}

void	ZKMQTReader::RunIteration()
{
	QTReadBuffer *b;
#ifdef DEBUG_ZONE_QT
	ZKMORLogDebug(CFSTR("0x%x RunIteration -- Start %u"), this, GetNumberOfValidBuffers());
#endif
	mSetTimeQueue.BeginReading();
		if (mSetTimeQueue.Count() > 0) {
			unsigned i, count = mSetTimeQueue.Count() - 1;
				// skip the first n - 1 items
			SetTimeAction* action;
			for (i = 0; i < count; ++i) {
				action = mSetTimeQueue.GetReadItem();
				mSetTimeQueue.ReturnReadItem(action);
			}
				// process the last one
			action = mSetTimeQueue.GetReadItem();
			SynchronousSetCurrentTime(action->time);
			mSetTimeQueue.ReturnReadItem(action);
				// clean-up and leave
			mSetTimeQueue.EndReading();
			return;
		}
	mSetTimeQueue.EndReading();
	
	while (b = static_cast<QTReadBuffer*>(mBufferQueue.WriteItem())) {
		ReadAudioBuffer(b);
			// don't read the video buffer because QT does a better job of decompressing movies
//		ReadVideoBuffer(b);
		mBufferQueue.AdvanceWritePtr();
	}
#ifdef DEBUG_ZONE_QT
	ZKMORLogDebug(CFSTR("0x%x RunIteration -- End %u"), this, GetNumberOfValidBuffers());	
#endif
}


void	ZKMQTReader::SynchronousSetCurrentTime(QTTime time)
{		
	TimeRecord now;
	if (!QTGetTimeRecord(time, &now)) {
		ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Could not convert time to time record"));
		return;
	}
	
	OSStatus err = 
		MovieAudioExtractionSetProperty(	mAudioExtraction, kQTPropertyClass_MovieAudioExtraction_Movie,
											kQTMovieAudioExtractionMoviePropertyID_CurrentTime,
											sizeof(TimeRecord), &now);
	if (err)
		ZKMORLogError(kZKMORLogSource_Zone, CFSTR("MovieAudioExtractionSetProperty failed %i"), err);
		
	// prime the buffers
	Prime();
	
	Pause();
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//		StopVideo();
		[mQTMovie setCurrentTime: time];
		mCurrentTime = [mQTMovie currentTime];
//		StartVideo();	
	[pool release];
	Unpause();
}

void	ZKMQTReader::SynchronousCreateMovie(CFStringRef filePath, NSError** error)
{
#ifdef NOT_THREAD_SAFE

#else
	EnterMoviesOnThread(0);
#endif
	if (mQTMovie) {	
		MovieAudioExtractionEnd(mAudioExtraction); mAudioExtraction = NULL;
		[mQTMovie release], mQTMovie = nil;
	}

	if (!filePath) { mAudioExtraction = NULL;  mMovieDuration = QTMakeTime(0, 25); mCurrentTime = QTMakeTime(0, 25); return; } 
	
	NSError* qtError = nil;
	mQTMovie = [[QTMovie alloc] initWithFile: (NSString*)filePath error: &qtError];
	if (!mQTMovie) {
		if (error) 
			*error = qtError;
		else 
			ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Could not create movie %@ %@"), filePath, qtError);
			
		mMovieDuration = QTMakeTime(0, 25);
		mCurrentTime = QTMakeTime(0, 25);
		mWorkerAtEndOfStream = true;
		return;
	}
	
	mMovieDuration = [[[mQTMovie movieAttributes] objectForKey: QTMovieDurationAttribute] QTTimeValue];
//	mCurrentTime = [[[mQTMovie movieAttributes] objectForKey: QTMovieCurrentTimeAttribute] QTTimeValue];
	mCurrentTime = [mQTMovie currentTime];

		// initialize audio
	MovieAudioExtractionBegin([mQTMovie quickTimeMovie], 0, &mAudioExtraction);
	MovieAudioExtractionGetProperty(	mAudioExtraction, kQTPropertyClass_MovieAudioExtraction_Audio,
										kQTMovieAudioExtractionAudioPropertyID_AudioStreamBasicDescription,
										sizeof(mClientDataFormat), &mClientDataFormat, NULL);
	SetClientDataFormat(mClientDataFormat);
	
		// the number of frames is the duration at the audio rate
	QTTime audioRateDuration = QTMakeTimeScaled(mMovieDuration, (long int) mClientDataFormat.mSampleRate);
	mNumberOfFrames = audioRateDuration.timeValue;
	OSStatus err;
	
		// initialize video
	if (mQTVisualContext) {
		err = SetMovieVisualContext([mQTMovie quickTimeMovie], mQTVisualContext);
		if (err) {
			if (error)
				*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
			else 
				ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Could not set QT visual context, error: %i"), err);		
		} 
	}
	SetMoviePlayHints([mQTMovie quickTimeMovie], hintsHighQuality, hintsHighQuality);
	[mQTMovie setVolume: 0.f];
	mWorkerAtEndOfStream = false;
}


#pragma mark _____ ZKMQTReader::QTReadBuffer
ZKMQTReader::QTReadBuffer::QTReadBuffer(ZKMORBufferQueue *queue, const CAStreamBasicDescription &fmt, UInt32 nBytes) : 
	ZKMORBufferQueue::Buffer(queue, fmt, nBytes), mVisualFrame(NULL), mIsVisualFrameValid(false)
{
//	printf("new QTReadBuffer 0x%x\t0x%x\n", (unsigned)this, mMemory->GetBufferList().mBuffers[0].mData);
//	fmt.PrintFormat(stdout, "\t", "AudioStreamBasicDescription:", true);
}

ZKMQTReader::QTReadBuffer::~QTReadBuffer()
{

}

void	ZKMQTReader::QTReadBuffer::AboutToDisposeBuffer()
{
	if(mIsVisualFrameValid) CVOpenGLTextureRelease(mVisualFrame);
}

void	ZKMQTReader::QTReadBuffer::UpdateAfterRead(TimeRecord movieNow, UInt32 nFramesRead, UInt32 audioFlags)
{
	mEndFrame = nFramesRead;
	mEndOfStream = (audioFlags & kQTMovieAudioExtractionComplete) || (nFramesRead == 0);
	mBufferStartTime = QTMakeTimeWithTimeRecord(movieNow);

		// we have new audio data -- clear the stale visual data
	if(mIsVisualFrameValid) CVOpenGLTextureRelease(mVisualFrame);
	mVisualFrame = NULL; mIsVisualFrameValid = NO;
}

bool	ZKMQTReader::QTReadBuffer::GrabVideoFrame(bool &isValid, CVImageBufferRef *outImageBufferRef) const
{
	if (mIsVisualFrameValid) {
		isValid = true;
		*outImageBufferRef = mVisualFrame;
		return true;
	}
	return false;
}

void	ZKMQTReader::DisposeBuffer(Buffer *b)
{
	static_cast<QTReadBuffer*>(b)->AboutToDisposeBuffer();
	ZKMORBufferQueue::DisposeBuffer(b);
}

void	ZKMQTReader::ReadAudioBuffer(QTReadBuffer *b)
{
	// read the audio
	b->SetEmpty();
	
	CABufferList *ioMemory = b->GetBufferList();
	CABufferList *fileBuffers = GetBufferList();
	fileBuffers->SetFrom(ioMemory);

	if (mWorkerAtEndOfStream || !mQTMovie) {
		return;
	}
	
	UInt32 nFrames = GetBufferSizeFrames();
	UInt32 audioFlags;

	ByteCount sizeReturned = 0;
	TimeRecord bufferStartTime;
	OSStatus err = 
		MovieAudioExtractionGetProperty(	mAudioExtraction, kQTPropertyClass_MovieAudioExtraction_Movie,
											kQTMovieAudioExtractionMoviePropertyID_CurrentTime,
											sizeof(TimeRecord), &bufferStartTime,	&sizeReturned);

	if (err) ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Error getting current position %i"), err);
	err = 	
		MovieAudioExtractionFillBuffer(		mAudioExtraction, 
											&nFrames,
											&fileBuffers->GetModifiableBufferList(),
											&audioFlags);
	if (err) ZKMORLogError(kZKMORLogSource_Conduit, CFSTR("Error getting audio %i"), err);
		// has to happen before reading the video so that mBufferStartTime is correct
	b->UpdateAfterRead(bufferStartTime, nFrames, audioFlags);
	mWorkerAtEndOfStream = b->ReachedEndOfStream();
}

/* 
 * This doesn't work because QT is more efficient at decompressing than the naive approach taken here.
 * That's why I've given up on this an gone to using QT to handling the video playback. I do sent the
 * volume to 0 so that there isn't any disturbance from playing back the QT movie simultaneously.
void	ZKMQTReader::ReadVideoBuffer(QTReadBuffer *b)
{
	if (!mQTVisualContext) return;
	
	Movie movie = [mQTMovie quickTimeMovie];
	
		// nothing to read
	if (mWorkerAtEndOfStream) return;

		// cache the current time in the correct time scale
	QTTime bufferStartTime = QTMakeTimeScaled(b->mBufferStartTime, mCurrentTime.timeScale);
	
		// cache the end time of the buffer (in the correct time scale)
	TimeRecord bufferEndTimeRecord;
	ByteCount sizeReturned = 0;
	OSStatus err = 
		MovieAudioExtractionGetProperty(	mAudioExtraction, kQTPropertyClass_MovieAudioExtraction_Movie,
											kQTMovieAudioExtractionMoviePropertyID_CurrentTime,
											sizeof(TimeRecord), &bufferEndTimeRecord, &sizeReturned);
	QTTime bufferEndTime = QTMakeTimeWithTimeRecord(bufferEndTimeRecord);
	bufferEndTime = QTMakeTimeScaled(bufferEndTime, mCurrentTime.timeScale);
	
		// look for the next interesting time (i.e., the next visual frame)
	TimeValue currentTimeValue = 0, interestingTime = 0, interestingDuration = 0;	
	OSType mediaTypes[1];
	mediaTypes[0] = VisualMediaCharacteristic;
	currentTimeValue = bufferStartTime.timeValue;
	GetMovieNextInterestingTime(movie, nextTimeMediaSample | nextTimeEdgeOK, 1, mediaTypes, currentTimeValue, fixed1, &interestingTime, &interestingDuration);

	// if the next interesting time is after the end of the buffer, then duplicate the current image
	if (interestingTime > bufferEndTime.timeValue) {
		mCurrentTime.timeValue = bufferStartTime.timeValue;
		[mQTMovie setCurrentTime: b->mBufferStartTime];
		MoviesTask(movie, 0);
	} else {
		// the interesting time is within our range -- go to that time and extract the image
		mCurrentTime.timeValue = interestingTime;
		[mQTMovie setCurrentTime: mCurrentTime];
		MoviesTask(movie, 0);		
	}

	b->mIsVisualFrameValid = YES;
	err = QTVisualContextCopyImageForTime(mQTVisualContext, kCFAllocatorDefault, NULL, &b->mVisualFrame);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Zone, CFSTR("Error getting video frame %i"), err);
		b->mVisualFrame = NULL;
		b->mIsVisualFrameValid = NO;
	}
}
*/
