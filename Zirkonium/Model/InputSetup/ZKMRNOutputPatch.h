//
//  ZKMRNOutputPatch.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNAbstractInOutPatch.h"


@interface ZKMRNOutputPatch : ZKMRNAbstractInOutPatch {

}

-(BOOL)isPreferenceSelected;

- (void)setNumberOfDirectOuts:(NSNumber *)numberOfChannels;
//-(unsigned)numberOfDirectOuts;

- (void)increaseDirectOutChannelsTo:(unsigned)numberOfChannels;
- (void)decreaseDirectOutChannelsTo:(unsigned)numberOfChannels;

@end
