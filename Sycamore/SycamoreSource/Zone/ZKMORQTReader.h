//
//  ZKMORQTReader.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMQTReader_h__
#define __ZKMQTReader_h__

#include "ZKMORZone.h"
#include "ZKMMPQueue.h"
#import <QTKit/QTKit.h>

///
///  ZKMORFileReader
///
///  Reads audio files.
/// 
class ZKMQTReader : public ZKMORPullBufferQueue {
public:
//  CTOR
	ZKMQTReader(int nBuffers, UInt32 bufferSizeFrames) :
		ZKMORPullBufferQueue(nBuffers, bufferSizeFrames),
		mQTMovie(NULL), mNumberOfFrames(-1), mWorkerAtEndOfStream(false), 
		mQTVisualContext(NULL), mSetTimeQueue(4), mCreateMovieQueue(2)
	{ 
		mSetTimeQueue.FinishInitializing();
		mCreateMovieQueue.FinishInitializing();
	}
		
	~ZKMQTReader();

//  Accessors
	void		SetFilePath(CFStringRef filePath, NSError** error);
	QTMovie*	QTKitMovie() const		{ return mQTMovie; }
	QTTime		MovieDuration() const	{ return mMovieDuration; }
	
		/// returns a value between 0. -> 1. for the position in the file
	double		GetCurrentPosition() const;
		/// accepts a value between 0. -> 1. for the position in the file -- removes from worker thread
	void		SetCurrentPosition(double loc);
		
	SInt64		GetCurrentFrame() const;
	SInt64		GetNumberFrames() const    { return mNumberOfFrames; }

		/// return the current QT time
	QTTime		GetCurrentTime() const;
		/// sets the current QT time
		///		Removes the object from the worker thread, sets the time, and re-adds to the worker thread
	void		SetCurrentTime(QTTime time);
		/// sets the current QT time
		///		Can be called while audio is running, but may not be processed for an indeterminate amount of time
	void		AsyncSetCurrentTime(QTTime time);
	
	//  Format Accessors
		/// The format that the reader outputs	
	const CAStreamBasicDescription&		GetClientDataFormat() const { return mClientDataFormat; }

	//  Visual Accessors
		/// Sets the visual context the video frames will be drawn in. This must be set if 
		/// you want to access the video from the QT file.
	void		SetVisualContext(QTVisualContextRef visualContext);
	
	void		StartVideo();
	void		StopVideo();


protected:
//  Internal Functions
	void		SetClientDataFormat(const CAStreamBasicDescription& format);
	void		RunIteration();
	void		SynchronousSetCurrentTime(QTTime time);
	void		SynchronousCreateMovie(CFStringRef filePath, NSError** error);
	
//  Internal State
	QTMovie*	mQTMovie;
	SInt64		mNumberOfFrames;
	bool		mWorkerAtEndOfStream;
	QTTime		mMovieDuration;
	QTTime		mCurrentTime;
	int			mCurrentVideoBuffer;
	bool		mIsPaused;

	//  Audio/Video State
	MovieAudioExtractionRef		mAudioExtraction;
	CAStreamBasicDescription	mClientDataFormat;
	QTVisualContextRef			mQTVisualContext;

//  Buffer Reading -- Need a subclass of buffer and a ReadBuffer method that uses the subclass
	class QTReadBuffer : public ZKMORBufferQueue::Buffer {
	public:
		QTReadBuffer(ZKMORBufferQueue *queue, const CAStreamBasicDescription &fmt, UInt32 nBytes);
		~QTReadBuffer();
		void			AboutToDisposeBuffer();
		
		void			UpdateAfterRead(TimeRecord movieNow, UInt32 nFramesRead, UInt32 audioFlags);
		void			GetLocation(UInt32 &frm0, UInt32 &frame1) const {
							frm0 = mStartFrame; frame1 = mEndFrame;
						}
		bool			GrabVideoFrame(bool &isValid, CVImageBufferRef *outImageBufferRef) const;
		
		QTTime				mBufferStartTime;
			// the visual frame
		CVImageBufferRef	mVisualFrame;
		bool				mIsVisualFrameValid;
	};
	
	ZKMORBufferQueue::Buffer *	CreateBuffer(const CAStreamBasicDescription &fmt, UInt32 nBytes) {
							return new QTReadBuffer(this, fmt, nBytes);
						}
	virtual void		DisposeBuffer(Buffer *b);
	
	void				ReadAudioBuffer(QTReadBuffer *b);

//  Asynchronous actions
	struct SetTimeAction {
		QTTime time; 
		SetTimeAction*	get_next() { return mNext; }
		void			set_next(SetTimeAction* next) { mNext = next; }
		SetTimeAction*	mNext;
	};
	
	struct CreateMovieAction {
		CFStringRef			mFilePath; 
		CreateMovieAction*	get_next() { return mNext; }
		void				set_next(CreateMovieAction* next) { mNext = next; }
		CreateMovieAction*	mNext;
	};
		
	typedef	TManagedQueue<SetTimeAction> SetTimeQueue;
	typedef	TManagedQueue<CreateMovieAction> CreateMovieQueue;
	SetTimeQueue		mSetTimeQueue;
	CreateMovieQueue	mCreateMovieQueue;
};

#endif __ZKMQTReader_h__
