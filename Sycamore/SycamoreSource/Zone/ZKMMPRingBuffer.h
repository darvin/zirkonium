/*
 *  ZKMMPRingBuffer.h
 *  Sycamore
 *
 *  Created by Chandrasekhar Ramakrishnan on 16.08.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 *
 *  A thread-safe ring buffer requiring no locks.
 *
 */

#ifndef __ZKMMPRingBuffer_h__
#define __ZKMMPRingBuffer_h__

	// for CompareAndSwap
#include <CoreServices/CoreServices.h>

/**
 *  ZKMMPRingBuffer
 *
 *  A single-reader / single-writer, lock-free ring buffer.
 *
 *  The implementation is based on the Apple supplied LockFreeFIFO code in AUValidSamples.cpp.
 *
 *  Any functions that have an NA (non-atomic) suffix are not thread safe and should only be used
 *  when it is known that only one thread is accessing the buffer.
 *  
 *  Usage:
		T *item = fifo->WriteItem(); // get pointer to item in queue.
		if (item)
		{
			// ...put stuff in item...
			fifo->AdvanceWritePtr();
		}

...

		T *item;
		while ((item = fifo->ReadItem()) != NULL)
		{
			// ...get stuff from item...
			fifo->AdvanceReadPtr();
		}
 *
 */
template <class T> 
class TZKMMPRingBuffer
{
public:
	TZKMMPRingBuffer(UInt32 inMaxSize): 
		mReadIndex(0), mWriteIndex(0), mSize(inMaxSize)
	{
		mItems = new T*[inMaxSize];
	}
	
	~TZKMMPRingBuffer()
	{
		delete [] mItems;
	}
	
	T*	WriteItem() const
	{
		if (NextWriteIndex() == mReadIndex) return NULL;
		return mItems[mWriteIndex];
	}
	
	T*	ReadItem() const
	{
		if (mReadIndex == mWriteIndex) return NULL;
		return mItems[mReadIndex];
	}
	
	int	NumberOfValidReadItems() const
	{
		int numValidBufs = mWriteIndex - mReadIndex;
		if (numValidBufs < 0) numValidBufs += mSize;
		return numValidBufs;
	}
	
		// From Apple:
		// [in the single-reader/single-writer case] the CompareAndSwap will always succeed. 
		//  We use CompareAndSwap because it calls the PowerPC sync instruction, plus any 
		//  processor bug workarounds for various CPUs.
	void AdvanceWritePtr() { CompareAndSwap(mWriteIndex, NextWriteIndex(), (UInt32*)&mWriteIndex); }
	void AdvanceReadPtr()  { CompareAndSwap(mReadIndex,  NextReadIndex(), (UInt32*)&mReadIndex); }

//  Non-Atomic operations	
		/// Don't use this in normal access, but it can be helpful for initialization
	T**		AllItemsNA() { return mItems; }
	
		/// Don't use this in normal access, but it can be helpful for initialization
	void	ResetIndicesNA() { mWriteIndex = 0; mReadIndex = 0; }
	
	int		SNPrint(char* destStr, size_t strLen) const
	{
		return snprintf(destStr, strLen, "RingBuffer 0x%x r,w {%u, %u}", this, mReadIndex, mWriteIndex);
	}
	
private:
	UInt32	NextWriteIndex() const
	{
		UInt32 writeIndex = mWriteIndex + 1;
		return (writeIndex == mSize) ? 0 : writeIndex;
	}
	
	UInt32	NextReadIndex() const
	{
		UInt32 readIndex = mReadIndex + 1;
		return (readIndex == mSize) ? 0 : readIndex;
	}
	
	volatile UInt32 mReadIndex, mWriteIndex;
	UInt32	mSize;
	T**		mItems;
	
	TZKMMPRingBuffer()
		: mReadIndex(0), mWriteIndex(0), mSize(0), mItems(NULL) {}
};

#endif __ZKMMPRingBuffer_h__