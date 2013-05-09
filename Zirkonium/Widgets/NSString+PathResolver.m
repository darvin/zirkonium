//
//  NSString+PathResolver.m
//  Zirkonium
//
//  Created by Jens on 21.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSString+PathResolver.h"

@implementation NSString (PathResolver)

// Assumes that self and endPath are absolute file paths. 
// Example: @"/a/b/c/d" relativePathTo: @"/a/e/f/g/h" => @"../../e/f/g/h". 
/*
-(NSString*)relativePathTo: (NSString*)endPath 
{ 
	NSAssert( ! [self isEqual: endPath], @"illegal link to self"); 
	
	NSArray* startComponents = [self pathComponents]; 
	NSArray* endComponents = [endPath pathComponents]; 
	
	NSMutableArray* resultComponents = nil; 
	int prefixCount = 0; 
	if( ! [self isEqual: endPath] ){ 
		int iLen = MIN([startComponents count], [endComponents count]); 
		for(prefixCount = 0; prefixCount < iLen && [[startComponents objectAtIndex: prefixCount] isEqual: [endComponents objectAtIndex: prefixCount]]; ++prefixCount){} 
	} 
	if(0 == prefixCount){ 
		resultComponents = [NSMutableArray arrayWithArray: endComponents]; 
	}else{ 
		resultComponents = [NSMutableArray arrayWithArray: [endComponents subarrayWithRange: NSMakeRange(prefixCount, [endComponents count] - prefixCount)]]; 
		int lifterCount = [startComponents count] - prefixCount; 
		if(1 == lifterCount){ 
			[resultComponents insertObject: @"." atIndex: 0]; 
		}else{ 
			--lifterCount;
			int i; 
			for(i = 0; i < lifterCount; ++i){ 
				[resultComponents insertObject: @".." atIndex: 0]; 
			} 
		} 
	} 
	return [NSString pathWithComponents: resultComponents]; 
} 
*/

- (NSString *)absolutePathFromBaseDirPath:(NSString *)baseDirPath
{
    if ([self hasPrefix:@"~"]) {
        return [self stringByExpandingTildeInPath];
    }
    
    NSString *theBasePath = [baseDirPath stringByExpandingTildeInPath];

    if (![self hasPrefix:@"."]) {
        return [theBasePath stringByAppendingPathComponent:self];
    }
    
    NSMutableArray *pathComponents1 = [NSMutableArray arrayWithArray:[self pathComponents]];
    NSMutableArray *pathComponents2 = [NSMutableArray arrayWithArray:[theBasePath pathComponents]];

    while ([pathComponents1 count] > 0) {        
        NSString *topComponent1 = [pathComponents1 objectAtIndex:0];
        [pathComponents1 removeObjectAtIndex:0];

        if ([topComponent1 isEqualToString:@".."]) {
            if ([pathComponents2 count] == 1) {
                // Error
                return nil;
            }
            [pathComponents2 removeLastObject];
        } else if ([topComponent1 isEqualToString:@"."]) {
            // Do nothing
        } else {
            [pathComponents2 addObject:topComponent1];
        }
    }
    
    return [NSString pathWithComponents:pathComponents2];
}

- (NSString *)relativePathFromBaseDirPath:(NSString *)baseDirPath
{
    NSString *thePath = [self stringByExpandingTildeInPath];
    NSString *theBasePath = [baseDirPath stringByExpandingTildeInPath];
    
    NSMutableArray *pathComponents1 = [NSMutableArray arrayWithArray:[thePath pathComponents]];
    NSMutableArray *pathComponents2 = [NSMutableArray arrayWithArray:[theBasePath pathComponents]];

    // Remove same path components
    while ([pathComponents1 count] > 0 && [pathComponents2 count] > 0) {
        NSString *topComponent1 = [pathComponents1 objectAtIndex:0];
        NSString *topComponent2 = [pathComponents2 objectAtIndex:0];
        if (![topComponent1 isEqualToString:topComponent2]) {
            break;
        }
        [pathComponents1 removeObjectAtIndex:0];
        [pathComponents2 removeObjectAtIndex:0];
    }
    
    // Create result path
	int i; 
    for ( i = 0; i < [pathComponents2 count]; i++) {
        [pathComponents1 insertObject:@".." atIndex:0];
    }
    if ([pathComponents1 count] == 0) {
        return @".";
    }
    return [NSString pathWithComponents:pathComponents1];
}


@end
