//
//  ZKMRLLightSetupDocument.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 20.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZKMRLLightSetupDocument : NSPersistentDocument {

}

- (NSString *)lanBoxAddress;
- (void)setLanBoxAddress:(NSString *)lanBoxAddress;
- (IBAction)setDefaultLanBoxAddress:(id)sender;

@end
