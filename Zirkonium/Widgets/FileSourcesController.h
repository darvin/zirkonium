//
//  FileSourcesController.h
//  Zirkonium
//
//  Created by Jens on 21.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FileSourcesControllerDelegate; 

@interface FileSourcesController : NSArrayController {
	id<FileSourcesControllerDelegate> delegate; 
}
@property (nonatomic, assign) 	id<FileSourcesControllerDelegate> delegate; 
@end

@protocol FileSourcesControllerDelegate

-(BOOL)canAddFileSource; 

@end
