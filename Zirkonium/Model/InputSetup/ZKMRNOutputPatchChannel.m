//
//  ZKMRNOutputPatchChannel.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 02.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNOutputPatchChannel.h"

#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNPieceDocument.h"

NSString* ZKMRNOutputPatchChangedNotification = @"ZKMRNOutputPatchChangedNotification";

@implementation ZKMRNOutputPatchChannel

- (NSString *)entityName { return @"OutputPatchChannel"; }

#pragma mark _____ Accessors
- (void)setSourceChannel:(NSNumber *)sourceChannel
{
	NSError* error; 
	if([super checkSourceChannel:&sourceChannel error:&error])
	{
		[self willChangeValueForKey: @"sourceChannel"];
		[self setPrimitiveValue: sourceChannel forKey: @"sourceChannel"];
		[self didChangeValueForKey: @"sourceChannel"];
		[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
	}
	else {
		int button = [self handleAlert:error];
		switch(button) {
			case NSAlertFirstButtonReturn:
				// handle Cancel ...
				break;
			case NSAlertSecondButtonReturn:
				// handle Swap ...
				
				[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
				break;
			case NSAlertThirdButtonReturn:
				// handle Nullify ...
				
				[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
				break;
		}

	}
}

@end
