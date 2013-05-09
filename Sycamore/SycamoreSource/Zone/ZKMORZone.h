/*
 *  ZKMORZone.h
 *  Sycamore
 *
 *  Created by Chandrasekhar Ramakrishnan on 01.09.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __ZKMORZone_h__
#define __ZKMORZone_h__

#include "CAPThread.h"
#include "CAGuard.h"
#include "CAStreamBasicDescription.h"
#include "CABufferList.h"
#include <algorithm>
#include "ZKMMPRingBuffer.h"

///
///  ZKMORFileZoneObject
///
///  The file zone the zone in which file IO occurs. It owns a thread (which is global to the zone)
///  and defines a way for other thread (in particular, the audio thread) to communicate with objects
///  in this zone.
///
///  The implementation is based on the thread-management portion of CABufferQueue from the 
///  Apple CoreAudio sample code.
/// 
class ZKMORFileZoneObject {
public:
//  CTOR
				ZKMORFileZoneObject();
	virtual		~ZKMORFileZoneObject();

protected:
	class WorkThread : public CAPThread {
	public:
		WorkThread();
		~WorkThread();
		
		static void * ThreadEntry(void *param)
		{
			static_cast<WorkThread *>(param)->RunThread();
			return NULL;
		}
		void	RunThread();
		void	StopThread();
		void	NotifyThread();
		
		void	AddObject(ZKMORFileZoneObject *object);
		void	RemoveObject(ZKMORFileZoneObject *object);
	
	private:
		bool								mStopped;
		CAGuard								mRunGuard;
			/// objects in the zone that need to be run
		CFMutableSetRef						mZoneObjects;
	};
	
private:
		/// the WorkThread shared by all objects in the zone.
	static WorkThread *	sWorkThread;
	
protected:
		/// Called by the worker thread -- runs one iteration in the worker thread
	virtual void	RunIteration() = 0;
	
//  Actions
		/// Flags this object as needing to run in the worker thread
	void	MarkNeedsToRun(); 
		///  Removes this object from the worker thread. Useful if you want to do some initializing. This is
		///  a sychronous call (won't return until the object has been removed).
	void	RemoveFromWorkerThread();
		///  Adds this object to the worker thread. Call after removing if you want this object to continue
		///  functioning in the file zone.
	void	AddToWorkerThread();

		/// the thread I run in
	WorkThread *			mWorkThread;
	volatile bool			mNeedsToRun;
	
};


///
///  ZKMORBufferQueueState
///
///  Enums for the volitilie state of the buffer queue during rendering.
///
enum
{
	kZKMORBufferQueueState_Free = 0,
	kZKMORBufferQueueState_Rendering = 1,
	kZKMORBufferQueueState_Paused = 2
};


///
///  ZKMORBufferQueue
///
///  An abstract superclass for things that move buffers between threads. Based on the buffer-
///  management part of CABufferQueue.
/// 
class ZKMORBufferQueue : public ZKMORFileZoneObject {
public:
//  CTOR
				ZKMORBufferQueue(int nBuffers, UInt32 bufferSizeFrames);
	virtual		~ZKMORBufferQueue();

//  Accessors
	UInt32		GetNumberOfBuffers() const { return mNumberBuffers; }
	UInt32		GetBufferSizeFrames() const { return mBufferSizeFrames; }
	
		/// Get the number of times the audio thread outstripped the worker thread
	int			UnderflowCount() const { return mUnderflowCount; }
	void		ResetUnderflowCount() { mUnderflowCount = 0; }
	
//  Debugging
	virtual int SNPrint(char* destStr, size_t strLen) const;
	
	
	// -----
	class Buffer {
	public:
		Buffer(ZKMORBufferQueue *owner, const CAStreamBasicDescription &fmt, UInt32 nBytes);
		~Buffer() { delete mMemory; }
		
		ZKMORBufferQueue *	Queue() { return mQueue; }
		CABufferList *		GetBufferList() { return mMemory; }
		UInt32				FrameCount() { return mEndFrame - mStartFrame; }
		void				SetEmpty() { mStartFrame = mEndFrame = 0; }
		
		bool				ReachedEndOfStream() const { return mEndOfStream; }

		bool				CopyInto(AudioBufferList *destBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired);	// return true if buffer emptied

		bool				CopyFrom(const AudioBufferList *srcBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired); // return true if buffer filled and not end-of-stream
		
	protected:
		ZKMORBufferQueue *	mQueue;
		CABufferList *		mMemory;
		UInt32				mByteSize;
		
		bool				mEndOfStream;				// true if the operation resulted in end-of-stream
		UInt32				mStartFrame, mEndFrame;		// produce/consume pointers within the buffer
	};

protected:
	typedef TZKMMPRingBuffer<Buffer>	BufferQueue;
	
	virtual Buffer *	CreateBuffer(const CAStreamBasicDescription &fmt, UInt32 nBytes) = 0;
	virtual void		DisposeBuffer(Buffer *b);
	void				DisposeBuffers(); 
	
			/// Set the format of the buffers in the queue
	void				SetFormat(const CAStreamBasicDescription &fmt);
	CABufferList *		GetBufferList() { return mBufferList; }
	const Buffer *		GetCurrentBuffer() const { return mBufferQueue.ReadItem(); }
	UInt32				GetBytesPerFrame() const { return mBytesPerFrame; }
	
	int					GetNumberOfValidBuffers() const { return mBufferQueue.NumberOfValidReadItems(); }

//  Actions
		/// When paused, the buffer queue will return buffers of silence on Pulls
		/// This is a synchronous operation (blocks until the queue is paused)
	void				Pause();
		/// When paused, the buffer queue will return buffers of silence on Pulls
		/// This is a synchronous operation (blocks until the queue is unpaused)		
	void				Unpause();

	int					mNumberBuffers;
	int					mValidBufferThreshold;		///< mark myself for running if I fall below/above the threshold
	
	
	BufferQueue			mBufferQueue;
	bool				mBuffersAreValid;
	
	UInt32				mBufferSizeFrames;
	UInt32				mBytesPerFrame;				// function of client format
	CABufferList *		mBufferList;				// maintained in SetFormat
protected:
	int					mUnderflowCount;
	volatile UInt32		mBufferQueueState;
};



///
///  ZKMORPullBufferQueue
///
///  An abstract subclass for things in the file zone that read buffers from files.
/// 
class ZKMORPullBufferQueue : public ZKMORBufferQueue {
public:
//  CTOR
	ZKMORPullBufferQueue(int nBuffers, UInt32 bufferSizeFrames) :
		ZKMORBufferQueue(nBuffers, bufferSizeFrames), mEndOfStream(true), mIsPrimed(false) { }
	~ZKMORPullBufferQueue() { }
	
//  Actions	
		/// produce initial buffers -- this pauses the reader because it is not thread safe.
	void			Prime();
		/// pull a buffer out of the queue
	void			PullBuffer(UInt32 &ioFrames, AudioBufferList *outBufferList);
					
	bool			ReachedEndOfStream() const { return mEndOfStream; }

protected:
	bool			mEndOfStream;
	bool			mIsPrimed;
};



///
///  ZKMORPushBufferQueue
///
///  An abstract subclass for things in the file zone that write buffers to files.
/// 
class ZKMORPushBufferQueue : public ZKMORBufferQueue {
public:
//  CTOR
	ZKMORPushBufferQueue(int nBuffers, UInt32 bufferSizeFrames) :
		 ZKMORBufferQueue(nBuffers, bufferSizeFrames) { }
	~ZKMORPushBufferQueue() { }
	

//  Actions
		/// push a buffer into the queue
	void			PushBuffer(UInt32 inNumberFrames, const AudioBufferList *inBufferList);
		/// write what's in the queue
	void			Flush();
};


#endif // __ZKMORZone_h__
