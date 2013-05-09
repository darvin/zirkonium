//
//  ZKMRNSpeaker.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 31.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>


@interface ZKMRNSpeaker : NSManagedObject {

}

//  Accessors
- (void)setPositionX:(NSNumber *)pos;
- (void)setPositionY:(NSNumber *)pos;
- (void)setPositionZ:(NSNumber *)pos;
- (ZKMNRSpeakerPosition *)speakerPosition;

@end
