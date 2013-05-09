//
//  ZKMMDDocument.h
//  MuseumDomDB
//
//  Created by C. Ramakrishnan on 10.07.09.
//  Copyright Illposed Software 2009 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ZKMMDDocument : NSPersistentDocument {
	IBOutlet NSTreeController*	piecesController;
}

- (NSArray *)pieces;
- (NSArray *)piecesSortDescriptors;

- (IBAction)selectFile:(id)sender;

@end
