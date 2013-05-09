//
//  ZKMRNSpeakerSetup.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 27.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>


@interface ZKMRNSpeakerSetup : NSManagedObject {
	ZKMNRSpeakerLayout* _speakerLayout; 
}

-(BOOL)isPreferenceSelected;

//  Accessors
- (ZKMNRSpeakerLayout *)speakerLayout;
- (unsigned)numberOfSpeakers;

//  Notification
- (void)speakerRingsChanged;

@end
