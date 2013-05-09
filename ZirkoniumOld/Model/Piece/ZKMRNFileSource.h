//
//  ZKMRNFileSource.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 23.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
#import "ZKMRNAudioSource.h"


@interface ZKMRNFileSource : ZKMRNAudioSource {
	NSError*				_lastError;
}

//  Accessors
- (NSNumber *)duration;
- (void)setPath:(NSString *)path;

@end

