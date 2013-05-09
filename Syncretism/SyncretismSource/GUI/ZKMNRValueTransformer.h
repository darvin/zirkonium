//
//  ZKMNRValueTransformer.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 17.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMORCore.h"


/// 
///  ZKMNRIndexTransformer
/// 
///  Converts zero-offset array indices to one-offset indices for normal
///  human consumption. Does the reverse, too.
///
@interface ZKMNRIndexTransformer : NSValueTransformer {

}

@end

ZKMOR_C_BEGIN

/// 
///  SecondsToHHMMSSMS
/// 
///  Converts a value in (float) seconds into (unsigned) hours, minutes, seconds, milliseconds.
///  You need to pass pointers for all values, even if you ignore one of them.
///
void	SecondsToHHMMSSMS(Float64 seconds, unsigned* hours, unsigned* mins, unsigned* secs, unsigned* msecs);

/// 
///  HHMMSSMSToSeconds
/// 
///  Converts a (unsigned) hours, minutes, seconds, milliseconds into (float) seconds.
///
void	HHMMSSMSToSeconds(unsigned hours, unsigned mins, unsigned secs, unsigned msecs, Float64* total);

/// 
///  SecondsToMMSSMS
/// 
///  Converts a value in (float) seconds into (unsigned) minutes, seconds, milliseconds.
///  You need to pass pointers for all values, even if you ignore one of them.
///
void	SecondsToMMSSMS(Float64 seconds, unsigned* mins, unsigned* secs, unsigned* msecs);

/// 
///  MMSSMSToSeconds
/// 
///  Converts a (unsigned) minutes, seconds, milliseconds into (float) seconds.
///
void	MMSSMSToSeconds(unsigned mins, unsigned secs, unsigned msecs, Float64* total);

ZKMOR_C_END