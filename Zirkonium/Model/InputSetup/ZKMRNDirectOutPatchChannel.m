//
//  ZKMRNDirectOutPatchChannel.m
//  Zirkonium
//
//  Created by Jens on 01.07.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNDirectOutPatchChannel.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNPieceDocument.h"

@implementation ZKMRNDirectOutPatchChannel

- (NSString *)entityName { return @"DirectOutPatchChannel"; }

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


-(void)setIsActive:(BOOL)isActive
{
	
	[self willChangeValueForKey: @"isActive"];
	[self setPrimitiveValue: [NSNumber numberWithBool:isActive] forKey: @"isActive"];
	[self didChangeValueForKey: @"isActive"];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"ZKMRNOutputPatchChangedNotification" object: self];
}


-(BOOL)isActive
{
	ZKMRNPieceDocument *document = [[ZKMRNZirkoniumSystem sharedZirkoniumSystem] currentPieceDocument];
	if (!document) return NO;
	
	NSSet* graphDirectOuts = [document graphDirectOuts];
	
	if(graphDirectOuts)
	{
		NSEnumerator* enumerator = [graphDirectOuts objectEnumerator];
		id aDirectOut; 
		while(aDirectOut = [enumerator nextObject])
		{
			if([[self valueForKey:@"patchChannel"] intValue] == [[aDirectOut valueForKey:@"directOutNumber"] intValue])
				return true;
		}
	}
	
	
	 return false; 
}

@end
