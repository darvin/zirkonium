#pragma once

/*
 *  ZirkalloyKernel.h
 *  Zirkonium
 *
 *  Created by cmartel on 13/05/09.
 *  Copyright 2009 ZKM Institute. All rights reserved.
 *
 */

#include "ZirkalloyVersion.h"
#include "ZKMRNZirk2Protocol.h"

#include "AUEffectBase.h"

class ZirkalloyKernel : public AUKernelBase
{
public:
    ZirkalloyKernel(AUEffectBase *inAudioUnit );
    virtual ~ZirkalloyKernel();
    
    virtual void 		Process(	const Float32 	*inSourceP,
                                Float32		 	*inDestP,
                                UInt32 			inFramesToProcess,
                                UInt32			inNumChannels,
                                bool &			ioSilence);
    
    virtual void		Reset();
};