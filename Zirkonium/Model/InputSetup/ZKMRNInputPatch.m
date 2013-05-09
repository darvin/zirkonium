//
//  ZKMRNInputConfig.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 04.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNInputPatch.h"
#import "ZKMRNZirkoniumSystem.h"


@implementation ZKMRNInputPatch
#pragma mark _____ ZKMRNAbstractInOutPatchInternal
- (NSString *)patchChannelEntityName { return @"InputPatchChannel"; } 
- (NSArray *)channelDescriptionsArray { return [[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] audioOutputDevice] inputChannelNames]; }
- (NSString *)patchDefaultName { return @"Input Patch"; }

-(BOOL)isPreferenceSelected {
	if([[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] inputPatch] isEqualTo:self]) {
		return YES; 
	}
	return NO; 
}

-(void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation 
{
	[self setValue:[dictionaryRepresentation valueForKey:@"name"] forKey:@"name"];
	[self setNumberOfChannels:[dictionaryRepresentation valueForKey:@"numberOfChannels"]];
	
	NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"sourceChannel" ascending:YES];
	NSArray* descriptorArray = [NSArray arrayWithObject:sortDescriptor];
	NSArray* channels = [[dictionaryRepresentation valueForKey: @"channels"] sortedArrayUsingDescriptors:descriptorArray];	
	NSArray* myChannels = [[[self valueForKey:@"channels"] allObjects] sortedArrayUsingDescriptors:descriptorArray];

	int i = 0;
	id aChannel; 
	for(aChannel in myChannels) {
		[aChannel setPrimitiveValue:[[channels objectAtIndex:i] valueForKey:@"patchChannel"] forKey:@"patchChannel"];
		i++;
	}
}



@end
