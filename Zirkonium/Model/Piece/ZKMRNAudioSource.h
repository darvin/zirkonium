//
//  ZKMRNAudioSource.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZKMORConduit;
@interface ZKMRNAudioSource : NSManagedObject {

}
//  Accessors -- Subclasses must override
- (ZKMORConduit *)conduit;

//  Actions
- (void)setCurrentTime:(Float64)seconds;

//  Queries
- (BOOL)isConduitValid;

@end
