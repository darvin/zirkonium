/*
 *  ZKMORHALPlugInImplSycamore.h
 *  CERN
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __ZKMORHALPlugInImplSycamore_H__
#define __ZKMORHALPlugInImplSycamore_H__

#include "ZKMORHALPlugIn.h"

#ifdef __SYNCRETISM__
#import <Syncretism/Syncretism.h>
#else
#import <Sycamore/Sycamore.h>
#endif

@class ZKMORConduitShim;
/// 
///  ZKMORHALPlugInImplSycamore
///
///  Extends the ZKMORHALPlugInImpl to use the Sycamore Device Output to communicate with the output device.
///
class ZKMORHALPlugInImplSycamore : public ZKMORHALPlugInImpl {

public:	

	//  CTOR / DTOR
	ZKMORHALPlugInImplSycamore(AudioHardwarePlugInRef plugIn);
	virtual ~ZKMORHALPlugInImplSycamore();
	
protected:
	//  Actions
	virtual void	InitializeDeviceOutput();
	virtual void	StartWrappedDevice();
	virtual void	StopWrappedDevice();
	virtual void	ReadInputFromWrappedDevice(const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames);
	virtual void	SetNumberOfChannels(unsigned numberOfInputs, unsigned numberOfOutputs);
	//  Subclass Overrides
	virtual void	PatchOutputGraph();

	//  Queries
	virtual bool	IsDeviceOutputInitialized() { return mDeviceOutput != NULL; }

protected:
		// the graph this device runs
	ZKMORDeviceOutput*	mDeviceOutput;
	ZKMORGraph*			mGraph;
	ZKMORMixerMatrix*	mMixerMatrix;
	ZKMORConduitShim*	mConduitShim;
	
		// getting input from the device
	ZKMORDeviceInput*	mDeviceInput;
	ZKMORRenderFunction mInputRenderFunction;
};

///
///  ZKMORConduitShim
/// 
///  A way to insert data into a conduit graph.
///
///  The RenderFunction just calls 
///
@interface ZKMORConduitShim : ZKMORConduit {
@public
	ZKMORHALPlugInImplSycamore*	mPlugInImpl;
}

- (id)initWithImpl:(ZKMORHALPlugInImplSycamore *)plugInImpl;

@end


#endif
