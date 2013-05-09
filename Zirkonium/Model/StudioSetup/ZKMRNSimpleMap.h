//
//  ZKMRNSimpleMap.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 10.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNChannelMap.h"

///
///  ZKMRNSimpleMap
///
///  A simplified channel map that only alows for reordering inputs and outputs.
/// 
@interface ZKMRNSimpleMap : ZKMRNChannelMap {

}

//  Accessors
	/// returns -1 if there is no output for the input
- (int)outputForInput:(unsigned)inputNum;
- (void)setOutput:(unsigned)outputNum forInput:(unsigned)inputNum;

@end
