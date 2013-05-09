//
//  ZKMORThreadBridge.h
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMORThreadBridge_h__
#define __ZKMORThreadBridge_h__

#include "CAStreamBasicDescription.h"
#include "CABufferList.h"
#include <algorithm>
#include "ZKMMPRingBuffer.h"


///
///  ZKMORBufferBridge
///
///  An class for move buffers between threads.
/// 
class ZKMORBufferBridge {
public:
//  CTOR
	ZKMORBufferBridge(int nBuffers, UInt32 bufferSizeFrames);
	~ZKMORBufferBridge();

//  Accessors
	UInt32		GetBufferSizeFrames() const { return mBufferSizeFrames; }
	
		/// Get the number of times the reader thread outstripped the writer
	int			UnderflowCount() const { return mUnderflowCount; }
	void		ResetUnderflowCount() { mUnderflowCount = 0; }
		/// Get the number of times the writer thread outstripped the reader
	int			OverflowCount() const { return mOverflowCount; }
	void		ResetOverflowCount() { mOverflowCount = 0; }	
	
//  Actions
	void PullBuffer(UInt32 &ioFrames, AudioBufferList *outBufferList);
	void PushBuffer(UInt32 inNumberFrames, const AudioBufferList *inBufferList);
	
	
	// -----
	class Buffer {
	public:
		Buffer(ZKMORBufferBridge *owner, const CAStreamBasicDescription &fmt, UInt32 nBytes);
		~Buffer() { delete mMemory; }
		
		ZKMORBufferBridge *	Queue() { return mQueue; }
		CABufferList *		GetBufferList() { return mMemory; }
		UInt32				FrameCount() { return mEndFrame - mStartFrame; }
		void				SetEmpty() { mStartFrame = mEndFrame = 0; }

		bool				CopyInto(AudioBufferList *destBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired);	// return true if buffer emptied

		bool				CopyFrom(const AudioBufferList *srcBufferList, int bytesPerFrame, UInt32 &framesProduced, UInt32 &framesRequired); // return true if buffer filled and not end-of-stream
		
	protected:
		ZKMORBufferBridge *	mQueue;
		CABufferList *		mMemory;
		UInt32				mByteSize;
		
		UInt32				mStartFrame, mEndFrame;		// produce/consume pointers within the buffer
	};

protected:
	typedef TZKMMPRingBuffer<Buffer>	BufferQueue;
	
	Buffer *	CreateBuffer(const CAStreamBasicDescription &fmt, UInt32 nBytes)
						{
							return new Buffer(this, fmt, nBytes);
						}
	void		DisposeBuffer(Buffer *b);
	void				DisposeBuffers(); 
	
			/// Set the format of the buffers in the queue
	void				SetFormat(const CAStreamBasicDescription &fmt);
	CABufferList *		GetBufferList() { return mBufferList; }
	const Buffer *		GetCurrentBuffer() const { return mBufferQueue.ReadItem(); }
	UInt32				GetBytesPerFrame() const { return mBytesPerFrame; }
	
	int					GetNumberOfValidBuffers() const { return mBufferQueue.NumberOfValidReadItems(); }

//  State
	int					mNumberBuffers;
	
	
	BufferQueue			mBufferQueue;
	bool				mBuffersAreValid;
	
	UInt32				mBufferSizeFrames;
	UInt32				mBytesPerFrame;				// function of client format
	CABufferList *		mBufferList;				// maintained in SetFormat
protected:
	int					mUnderflowCount;
	int					mOverflowCount;
};

#endif
