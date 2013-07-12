//
//  ZKMRNAbstractInOutPatchChannel.m
//  Zirkonium
//
//  Created by Jens on 02.07.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNAbstractInOutPatchChannel.h"
#import "ZKMRNAbstractInOutPatch.h"


@implementation ZKMRNAbstractInOutPatchChannel

- (void)setSourceChannel:(NSNumber *)sourceChannel
{
	NSError* error; 
	if([self checkSourceChannel:&sourceChannel error:&error])
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

//  Accessors
-(void)setInterfaceIndex:(NSNumber *)interfaceIndex
{
	// Bug fix ... changing the interface index will update the source channel
	// thats why the source channel first needs to be set by custom setter methode ... (JB)
	[self setSourceChannel: interfaceIndex]; 
}

-(NSNumber*)interfaceIndex
{
	return ([self valueForKey:@"sourceChannel"]!=nil) ? [self valueForKey:@"sourceChannel"] : [NSNumber numberWithInt: 99999];
}

#pragma mark -

-(BOOL)checkSourceChannel:(id *)ioValue error:(NSError **)outError
{
	//Note: ioValue after ZKMNRIndexTransformer (ioValue+=1)

	if(*ioValue == nil)	{
		// trap this in setNilValueForKey //set to default NSNumber
        return YES;
	}
	
	unsigned pendingSourceChannel = [*ioValue intValue];
	
	//check the patch for consistency
	BOOL isConsistent = TRUE; 
	unsigned occupierPatchChannel;
	unsigned occupierType;
		
	NSManagedObject* patch; 
	if([[self entityName] isEqualToString:@"OutputPatchChannel"]) {
		patch = [self valueForKey:@"patch"];
	} else if([[self entityName] isEqualToString:@"DirectOutPatchChannel"]) {
		patch = [self valueForKey:@"outputPatch"];
	} else if([[self entityName] isEqualToString:@"BassOutPatchChannel"]) {
		patch = [self valueForKey:@"outputPatch"];
	}
	

	if(patch)
	{
		ZKMRNAbstractInOutPatchChannel* aChannel;
		
		//the Patch Channels
		NSMutableSet* channels = [patch mutableSetValueForKey: @"channels"];
		NSEnumerator* channelEnumerator = [channels objectEnumerator];
		
		//...check
		while((aChannel=[channelEnumerator nextObject])) {
				NSNumber* sourceChannel = [aChannel valueForKey:@"sourceChannel"];
				if(sourceChannel && [sourceChannel intValue] == pendingSourceChannel)
				{
					isConsistent = FALSE; 
					occupierPatchChannel = [[aChannel valueForKey:@"patchChannel"] intValue];
					occupierType = 0;
				}
		}
		
		if(isConsistent)
		{
			//the Direct Out Channels
			NSMutableSet* directOuts = [patch mutableSetValueForKey: @"directOutChannels"];
			NSEnumerator* directOutsEnumerator = [directOuts objectEnumerator];
			//...check
			while((aChannel=[directOutsEnumerator nextObject])) {
				NSNumber* sourceChannel = [aChannel valueForKey:@"sourceChannel"];
				if(sourceChannel && [sourceChannel intValue] == pendingSourceChannel)
				{
					isConsistent = FALSE; 
					occupierPatchChannel = [[aChannel valueForKey:@"patchChannel"] intValue];
					occupierType = 1;
				}
			}
		}
		
	}
	
	if(!isConsistent) {
		if(outError != NULL) {
			NSString *occupierTypeString = (occupierType == 0) ? @"patch" : @"direct out";
			NSString *errorMsg = [NSString stringWithFormat:@"Patch inconsistency error: Source channel %d is already in use by %@ channel %d. Please handle the error by choosing one of the following options.", (pendingSourceChannel+1), occupierTypeString, (occupierPatchChannel+1)];
			NSString *errorStr = NSLocalizedStringFromTable(errorMsg , @"Patch Table", @"validation error: zero channel error"); //key, tableName, comment
			NSDictionary* userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:errorStr, NSLocalizedDescriptionKey, [NSNumber numberWithInt:occupierType], @"OccupierType", [NSNumber numberWithInt:occupierPatchChannel], @"OccupierPatchChannel", nil];
			NSError *error = [[[NSError alloc] initWithDomain:@"Patch Domain" code:678 userInfo:userInfoDict] autorelease];
			*outError = error;
		}
		return NO;
	}
	else {
		return YES; 
	}
}

#pragma mark -

-(int)handleAlert:(NSError*)error
{
	NSAlert *theAlert = [NSAlert alertWithError:error];
	
	[theAlert addButtonWithTitle:@"Cancel"];
	[theAlert addButtonWithTitle:@"Swap"];
	[theAlert addButtonWithTitle:@"Nullify Occupier"];
	
	//Changed to always clear occupier, if you want a warning message uncomment ...
	//int button = [theAlert runModal];
	int button = NSAlertThirdButtonReturn; 
	
	NSManagedObject* patch; 
	ZKMRNAbstractInOutPatchChannel* aChannel;
	int occupierType, occupierPatchChannel;
	NSMutableSet* channels;
	NSEnumerator* channelEnumerator;
	NSNumber* before; 
	switch(button) 
	{
		case NSAlertFirstButtonReturn:
			// handle Cancel ...
		break;
		case NSAlertSecondButtonReturn:
			// handle Swap ...
			occupierType = [[[error userInfo] valueForKey:@"OccupierType"] intValue];
			occupierPatchChannel = [[[error userInfo] valueForKey:@"OccupierPatchChannel"] intValue];
			patch = [self valueForKey:@"patch"];
			if(!patch)
				patch = [self valueForKey:@"outputPatch"];
			if(patch) {
				if(occupierType == 0)	channels = [patch mutableSetValueForKey: @"channels"];//the Patch Channels
				else					channels = [patch mutableSetValueForKey: @"directOutChannels"];
				
				channelEnumerator = [channels objectEnumerator];
				while((aChannel=[channelEnumerator nextObject])) {
					if([[aChannel valueForKey:@"patchChannel"] intValue] == occupierPatchChannel) {
						before = [self valueForKey:@"sourceChannel"];
						
						//set pre occupier
						[self willChangeValueForKey: @"sourceChannel"];
						[self setPrimitiveValue:[aChannel valueForKey:@"sourceChannel"] forKey: @"sourceChannel"];
						[self didChangeValueForKey: @"sourceChannel"];
						
						[aChannel setValue:before forKey:@"sourceChannel"];
					}
				}
			}
		break;
		case NSAlertThirdButtonReturn:
			occupierType = [[[error userInfo] valueForKey:@"OccupierType"] intValue];
			occupierPatchChannel = [[[error userInfo] valueForKey:@"OccupierPatchChannel"] intValue];
			patch = [self valueForKey:@"patch"];
			if(!patch)
				patch = [self valueForKey:@"outputPatch"];
			if(patch) {
				if(occupierType == 0)	channels = [patch mutableSetValueForKey: @"channels"];
				else					channels = [patch mutableSetValueForKey: @"directOutChannels"];
				
				channelEnumerator = [channels objectEnumerator];
				while((aChannel=[channelEnumerator nextObject])) {
					if([[aChannel valueForKey:@"patchChannel"] intValue] == occupierPatchChannel) {
						before = [aChannel valueForKey:@"sourceChannel"];
						
						[aChannel setValue:nil forKey:@"sourceChannel"];
						
						//set post occupier
						[self willChangeValueForKey: @"sourceChannel"];
						[self setPrimitiveValue: before forKey: @"sourceChannel"];
						[self didChangeValueForKey: @"sourceChannel"];
					}
				}
					
			}
		break;
		default:
		break;
	}
	
	return button;
}


// Subclass Responsibility
- (NSString *)entityName { return nil; }



@end
