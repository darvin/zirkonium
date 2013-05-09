//
//  NSString+PathResolver.h
//  Zirkonium
//
//  Created by Jens on 21.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (PathResolver) 

- (NSString *)absolutePathFromBaseDirPath:(NSString *)baseDirPath;
- (NSString *)relativePathFromBaseDirPath:(NSString *)baseDirPath;

@end
