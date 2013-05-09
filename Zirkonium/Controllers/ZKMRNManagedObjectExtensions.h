//
//  ZKMRNManagedObjectExtensions.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 16.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
///  NSManagedObject (ZKMRNManagedObjectExtensions)
///
///  Methods for simplifying working with managed objects
///
@interface NSManagedObject (ZKMRNManagedObjectExtensions)
+ (NSArray *)copyKeys; 
- (NSDictionary *)dictionaryRepresentation;
- (void)setFromDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;
@end
