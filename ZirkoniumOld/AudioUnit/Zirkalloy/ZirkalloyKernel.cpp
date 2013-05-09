/*
 *  ZirkalloyKernel.cpp
 *  Zirkonium
 *
 *  Created by cmartel on 13/05/09.
 *  Copyright 2009 ZKM Institute. All rights reserved.
 *
 */

#include "ZirkalloyKernel.h"

ZirkalloyKernel::ZirkalloyKernel(AUEffectBase *inAudioUnit )
: AUKernelBase(inAudioUnit)
{
}


ZirkalloyKernel::~ZirkalloyKernel( )
{
}

void		ZirkalloyKernel::Reset()
{
}

/**
 * @brief Zirkalloy Kernel processing
 *
 * As this audio unit is not really a DSP effect, the kernel only applies a
 * pass-through.
 *
 * @todo Investigate making Zirkalloy an aupn component.
 */
void ZirkalloyKernel::Process(	const Float32 	*inSourceP,
                           Float32          *inDestP,
                           UInt32 			inFramesToProcess,
                           UInt32			inNumChannels,
                           bool &			ioSilence)
{
    if (inSourceP == inDestP) return;
    memcpy(inDestP, inSourceP, inFramesToProcess * inNumChannels * sizeof(Float32));
}
