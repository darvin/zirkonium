//
//  ZKMRNChannelGroup.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 04.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRNChannelGroup : NSManagedObject {

}

//  Accessors
- (void)setName:(NSString *)name;
- (NSString *)displayString;

- (NSArray *)pannerSources;

@end
