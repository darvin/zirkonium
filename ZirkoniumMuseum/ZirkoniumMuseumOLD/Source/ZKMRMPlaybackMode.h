//
//  ZKMRMPlaybackMode.h
//  ZirkoniumMuseum
//
//  Created by C. Ramakrishnan on 03.09.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRMPlaybackMode : NSObject {

}

- (void)activate;

@end

@interface ZKMRMPlaybackModeUser : ZKMRMPlaybackMode {

}

@end

@interface ZKMRMPlaybackModeAutomatic : ZKMRMPlaybackMode {

}

@end
