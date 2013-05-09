//
//  AppDelegate.h
//  ZirkoniumMuseum
//
//  Created by Jens on 20.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRMMuseumSystem.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet ZKMRMMuseumSystem* system; 
}

-(IBAction)actionToggleFullscreen:(id)sender; 

@end
