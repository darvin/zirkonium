//
//  ZKMMPQueue.h
//  SycamoreLog
//
//  Created by Chandrasekhar Ramakrishnan on 01.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __TZKMMPQueue_h__
#define __TZKMMPQueue_h__
#include "CAAtomicStack.h"
#include <list>


///
///  TAtomicQueue
///
///  A multiple-writer, single-reader, lock-free queue.
///
///  The implementation is built on top of the Apple TAtomicStack template. The TAtomicQueue
///  uses stores the elements in an Apple-provided TAtomicStack and makes the elements available
///  in the correct order when requested (by calling BeginReading()).
///
///  Since the implementation uses TAtomicStack, the class T must implement set_next() 
///  and get_next().
///
///  An example of using the queue:
///
///		mQueue.Push(item);
///
///  And reading:
///
///		mQueue.BeginReading();
///		T* item;
///		while ((item = mQueue.Pop()) {
///			... // do stuff with item
///		}
///		mQueue.EndReading();
///
template <class T>
class TAtomicQueue {
public:
	typedef TAtomicStack<T>		ItemStack;
	typedef std::list<T*>		ReadList;

//  CTOR
	TAtomicQueue() 
	{
			// push some elements into the list so we aren't dynamically allocating memory
		T* dummyObject = NULL;
		for (int i = 0; i < 64; ++i)
			mReadingItems.push_back(dummyObject);
		mReadingItems.clear();
	}
	~TAtomicQueue() { }
	
//  Writing
	void	Push(T* item)	{ mItems.push_atomic(item); }
	
//  Reading
	void	BeginReading()
	{
		T* item = mItems.pop_all();
		if (!item) {
			mReadingItems.clear();
			return;
		}
		do {
			mReadingItems.push_front(item);
		} while (item = item->get_next());
	}
	
	T*		Pop()
	{ 
		T* item;
		if (mReadingItems.size() > 0) {
			item = mReadingItems.front();
			mReadingItems.pop_front();
		} else
			item = NULL;
		return item;
		
	}
	
	void	EndReading() { mReadingItems.clear(); }
	
protected:
	ItemStack	mItems;
	ReadList	mReadingItems;
};



///
///  TManagedQueue
///
///  A multiple-writer, single-reader, lock-free queue. In the managed queue, the elements in the
///  queue are owned by the queue itself (thus, the need to call GetWriteItem to write into it).
///
///  The implementation is built on top of the Apple TAtomicStack template. The TManagedQueue
///  uses two atomic stacks, one to keep track of the unused "free" elements, and one to keep
///  track of the used elements. The structure is stored as a stack, which is the same as a queue, just
///  in the wrong order, and gets reordered when the data is requested.
///
///  Since the implementation uses TAtomicStack, the class T must implement set_next() 
///  and get_next().
///
///  When a clients wants to write to the stack, it asks for a write element and then returns the
///  element when finished writing, which puts it onto the used stack. The reader tells the queue
///  that it is going to begin reading so the queue can set aside the entire uses stack (to avoid
///  ordering problems with writes interleaved during the read). The reader can then retrieve the
///  elements. As the reader finishes processing an element, it should return that to the queue to
///  be put back on the free stack.
///
///  An example of writing to the queue:
///
///		T* item = mQueue.GetWriteItem();
///		if (item) {
///			... // do stuff with item
///			mQueue.ReturnWrittenItem(item);
///		}
///
///  And reading:
///
///		mQueue.BeginReading();
///		T* item;
///		while ((item = mQueue.GetReadItem()) {
///			... // do stuff with item
///			mQueue.ReturnReadItem(item);
///		}
///		mQueue.EndReading();
///
template <class T>
class TManagedQueue {
public:
	typedef TAtomicStack<T>		ItemStack;
	typedef std::list<T*>		ReadList;

//  CTOR
	TManagedQueue(UInt32 bufferSize) : mBufferSize(bufferSize)  { mItems = new T[mBufferSize]; }
	~TManagedQueue() { delete [] mItems; }

//  Initializing
		/// Used for initializing the items, if necessary. Don't use once initializing is complete.
	T*			AllItemsNA() { return mItems; }
		/// Call this when the queue is ready to be used
	void	FinishInitializing()
	{
		for (UInt32 i = 0; i < mBufferSize; ++i)
			mFreeItems.push_NA(&mItems[i]);
	}
	
//  Accessing
	UInt32		BufferSize() { return mBufferSize; }
	
//  Writing
	T*		GetWriteItem()				{ return mFreeItems.pop_atomic(); }
	void	ReturnWrittenItem(T* item)	{ mUsedItems.push_atomic(item); }
	
//  Reading
	void	BeginReading()
	{
		T* item = mUsedItems.pop_all();
		if (!item) {
			mReadingItems.clear();
			return;
		}
		do {
			mReadingItems.push_front(item);
		} while (item = item->get_next());
	}
	
		/// only valid between BeginReading() / EndReading()
	size_t	Count()		{ return mReadingItems.size(); }
	
	T*		GetReadItem()
	{ 
		T* item;
		if (mReadingItems.size() > 0) {
			item = mReadingItems.front();
			mReadingItems.pop_front();
		} else
			item = NULL;
		return item;
		
	}
	void	ReturnReadItem(T* item)		{ mFreeItems.push_atomic(item); }
	
	void	EndReading() { mReadingItems.clear(); }
	
protected:
	UInt32		mBufferSize;
	T*			mItems;
	ItemStack	mFreeItems;
	ItemStack	mUsedItems;
	ReadList	mReadingItems;
};

#endif // __TZKMMPQueue_h__
