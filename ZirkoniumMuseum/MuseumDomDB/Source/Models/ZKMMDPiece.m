// 
//  ZKMMDPiece.m
//  MuseumDomDB
//
//  Created by C. Ramakrishnan on 10.07.09.
//  Copyright 2009 Illposed Software. All rights reserved.
//

#import "ZKMMDPiece.h"


@implementation ZKMMDPiece 
@synthesize delegate; 

@dynamic textEN;
@dynamic composer;
@dynamic textDE;
@dynamic index;
@dynamic title;
@dynamic path;
@dynamic masterGain;
@dynamic lightPresetName; 

- (NSArray *)children { return nil; }

- (void)setTitle:(NSString *)title
{
	NSString* oldTitle = [self primitiveValueForKey: @"title"];
	
	[self willChangeValueForKey: @"title"];
	[self setPrimitiveValue: title forKey: @"title"];
	[self didChangeValueForKey: @"title"];
	
	if ([oldTitle isEqualToString: self.index]) {
		// default the index to the same value as the title
		self.index = title;
	}
}

- (NSString *)composerTitleString
{
	return [NSString stringWithFormat: @"%@\n\t%@", self.composer, self.title];
}

- (NSAttributedString *)textENAttributed 
{
	NSAttributedString* textENAttributed = [self primitiveValueForKey: @"textENAttributed"];
	if (textENAttributed) return textENAttributed;	
	
	NSString* textEN = [self textEN];
	if (!textEN) return nil;
	textENAttributed = [[NSAttributedString alloc] initWithString: textEN];
	
	[self willChangeValueForKey: @"textENAttributed"];
	[self setPrimitiveValue: textENAttributed forKey: @"textENAttributed"];
	[self didChangeValueForKey: @"textENAttributed"];
	
	[textENAttributed release];
	
	return textENAttributed;
}

- (void)setTextENAttributed:(NSAttributedString *)textENAttributed 
{
	[self willChangeValueForKey: @"textENAttributed"];
	[self setPrimitiveValue: textENAttributed forKey: @"textENAttributed"];
	[self didChangeValueForKey: @"textENAttributed"];
	
	self.textEN = [textENAttributed string];
}

- (NSAttributedString *)textDEAttributed
{
	NSAttributedString* textDEAttributed = [self primitiveValueForKey: @"textDEAttributed"];
	if (textDEAttributed) return textDEAttributed;	
	
	NSString* textDE = [self textDE];
	if (!textDE) return nil;	
	textDEAttributed = [[NSAttributedString alloc] initWithString: textDE];
	
	[self willChangeValueForKey: @"textDEAttributed"];
	[self setPrimitiveValue: textDEAttributed forKey: @"textDEAttributed"];
	[self didChangeValueForKey: @"textDEAttributed"];
	
	[textDEAttributed release];	
	
	return textDEAttributed;
}


- (void)setTextDEAttributed:(NSAttributedString *)textDEAttributed
{
	[self willChangeValueForKey: @"textDEAttributed"];
	[self setPrimitiveValue: textDEAttributed forKey: @"textDEAttributed"];
	[self didChangeValueForKey: @"textDEAttributed"];
	
	self.textDE = [textDEAttributed string];
}

- (NSString *)duration
{
	//if([self.delegate respondsToSelector:@selector(durationString:)]) {
	return [self.delegate durationString];
	//}
}

- (NSString *)ellapsed
{
	//if([self.delegate respondsToSelector:@selector(durationString:)]) {
	return [self.delegate ellapsedString];
	//}
}


-(void)willTurnIntoFault
{
	//NSLog(@"Piece Will Turn Into Fault");
	[super willTurnIntoFault];
	self.delegate = nil; 
}

@end
