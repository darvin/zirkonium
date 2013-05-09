//
//  ZKMRNManagedObjectExtensions.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 16.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNManagedObjectExtensions.h"


@implementation NSManagedObject (ZKMRNManagedObjectExtensions)
+ (NSArray *)copyKeys { return [NSArray array]; }
- (NSDictionary *)dictionaryRepresentation { return [self dictionaryWithValuesForKeys: [[self class] copyKeys]]; }
- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation { [self setValuesForKeysWithDictionary: dictionaryRepresentation]; }
@end