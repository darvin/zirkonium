//
//  SycamoreLogPrinter.h
//  SycamoreLog
//
//  Created by Chandrasekhar Ramakrishnan on 16.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SycamoreLogPrinter : NSObject {
	CFTimeZoneRef tz;
}

- (void)printAvailableTokens;

@end
