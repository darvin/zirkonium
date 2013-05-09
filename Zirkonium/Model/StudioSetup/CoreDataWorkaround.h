//
//  CoreDataWorkaround.h
//  Zirkonium
//
//  Created by na on 5/3/10.
//  Copyright 2010 zkm. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSMigrationManager (Workaround)

+ (void)addRelationshipMigrationMethodIfMissing;

@end