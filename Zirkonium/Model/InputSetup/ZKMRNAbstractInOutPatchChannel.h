//
//  ZKMRNAbstractInOutPatchChannel.h
//  Zirkonium
//
//  Created by Jens on 02.07.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZKMRNAbstractInOutPatch; 
@interface ZKMRNAbstractInOutPatchChannel : NSManagedObject {
	NSNumber* _interfaceIndex;
}

//-(void)setPatch:(ZKMRNAbstractInOutPatch*)patch;
//-(ZKMRNAbstractInOutPatch*)patch;

-(BOOL)checkSourceChannel:(id *)ioValue error:(NSError **)outError;
-(int)handleAlert:(NSError*)error;


@end
