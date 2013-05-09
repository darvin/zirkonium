//
//  ZKMRLLightSetupDocument.m
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 20.07.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRLLightSetupDocument.h"
#import "ZKMRLZirkoniumLightSystem.h"


@implementation ZKMRLLightSetupDocument

- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"ZKMRLLightSetupDocument";
}

- (NSString *)lanBoxAddress
{
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	NSString* lanBoxAddress = [userDefaults stringForKey: @"LanBoxAddress"];
	if (nil == lanBoxAddress) lanBoxAddress = [[ZKMRLZirkoniumLightSystem sharedZirkoniumLightSystem] defaultLanBoxAddress];
	return lanBoxAddress;
}

- (void)setLanBoxAddress:(NSString *)lanBoxAddress
{
	[[NSUserDefaults standardUserDefaults] setObject: lanBoxAddress forKey: @"LanBoxAddress"];
	[[ZKMRLZirkoniumLightSystem sharedZirkoniumLightSystem] setLanBoxAddress: lanBoxAddress];
}

- (IBAction)setDefaultLanBoxAddress:(id)sender
{
	[self setLanBoxAddress: [[ZKMRLZirkoniumLightSystem sharedZirkoniumLightSystem] defaultLanBoxAddress]];
}

@end
