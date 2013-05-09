//
//  ZKMRNSpeakerRing.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 31.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRNSpeakerRing : NSManagedObject {

}

//  Accessors
- (NSString *)displayString;

//  Queries
- (NSComparisonResult)compare:(ZKMRNSpeakerRing *)otherRing;

//  Notification
- (void)speakerRingChanged;

@end
