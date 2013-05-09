//
//  ZKMRNInputSource.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import "ZKMRNAudioSource.h"


@interface ZKMRNInputSource : ZKMRNAudioSource {
	NSError*				_lastError;
}

@end
