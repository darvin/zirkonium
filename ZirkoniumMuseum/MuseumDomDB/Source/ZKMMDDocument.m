//
//  ZKMMDDocument.m
//  MuseumDomDB
//
//  Created by C. Ramakrishnan on 10.07.09.
//  Copyright Illposed Software 2009 . All rights reserved.
//

#import "ZKMMDDocument.h"
#import "ZKMMDPiece.h"

NSString* PathRelativeToRoot(NSString* path, NSString* root);

@implementation ZKMMDDocument

- (id)init 
{
    self = [super init];
	if (!self) return self;

/*	
	Might need this to do some validation, but not right now...
	[[NSNotificationCenter defaultCenter]
		addObserver: self 
		selector: @selector(managedObjectContextChanged:) 
		name: NSManagedObjectContextObjectsDidChangeNotification 
		object: [self managedObjectContext]];
*/
	
    return self;
}

- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
	if (!(self = [super initWithType: typeName error: outError])) return nil;
	
	// we are creating a new empty document -- generate a piece object
	NSManagedObjectContext* moc = [self managedObjectContext];
	[[moc undoManager] disableUndoRegistration];
	[NSEntityDescription
		insertNewObjectForEntityForName: @"ZKMMDPiece"
		inManagedObjectContext: [self managedObjectContext]];
	[moc processPendingChanges];
	[[moc undoManager] enableUndoRegistration];
	
	return self;
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error
{
	NSMutableDictionary* options = nil;
	if (storeOptions) {
		options = [storeOptions mutableCopy];
	} else {
		options = [[NSMutableDictionary alloc] init];
	}

	[options setObject: [NSNumber numberWithBool:YES] forKey: NSMigratePersistentStoresAutomaticallyOption];

	BOOL result = [super configurePersistentStoreCoordinatorForURL: url ofType: fileType modelConfiguration: configuration storeOptions: options error: error];
	[options release];

	return result;
}

- (NSString *)windowNibName 
{
    return @"ZKMMDDocument";
}

- (NSArray *)pieces
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"ZKMMDPiece" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	[request setSortDescriptors: [self piecesSortDescriptors]];
	
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	if (error) {
		[self presentError: error];
		return nil;
	}
	return array;
}

- (NSArray *)piecesSortDescriptors
{
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"title" ascending: YES];
	return [NSArray arrayWithObject: sortDescriptor];
}


- (void)managedObjectContextChanged:(NSNotification *)notification
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* elementEntity = [NSEntityDescription entityForName: @"ZKMMDPiece" inManagedObjectContext: moc];


	NSDictionary* userInfo = [notification userInfo];
		// check the inserted objects -- [userInfo objectForKey: NSInsertedObjectsKey];
	NSArray* insertedObjects = [userInfo objectForKey: NSInsertedObjectsKey];
	for (NSManagedObject* thing in insertedObjects) {
		if (![[thing entity] isKindOfEntity: elementEntity]) continue;
	}
			
		// check the deleted objects -- [userInfo objectForKey: NSDeletedObjectsKey];
	NSArray* deletedObjects = [userInfo objectForKey: NSDeletedObjectsKey];
	for (NSManagedObject* thing in deletedObjects) {
		if (![[thing entity] isKindOfEntity: elementEntity]) continue;
	}
}

- (IBAction)selectFile:(id)sender
{
	NSArray* fileTypes = [NSArray arrayWithObject: @"zrkpxml"];
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	
	NSString* rootPath;
	if ([self fileURL]) {
		rootPath = [[[self fileURL] path] stringByDeletingLastPathComponent];
	} else {
		rootPath = [[NSFileManager defaultManager] currentDirectoryPath];
	}

	[oPanel setAllowsMultipleSelection: NO];
	[oPanel 
		beginSheetForDirectory: rootPath
		file: nil 
		types: fileTypes 
		modalForWindow: [self windowForSheet] 
		modalDelegate: self 
		didEndSelector: @selector(openPanelDidEnd:result:contextInfo:) 
		contextInfo: nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)oPanel result:(int)result contextInfo:(void *)contextInfo
{
	if (result != NSOKButton) return;
	
	NSArray* filenames = [oPanel filenames];
	if ([filenames count] < 1) return;
	
	NSString* filename = [filenames objectAtIndex: 0];
	if (![[filename pathExtension] isEqualToString: @"zrkpxml"]) return;
	
	// Used to make paths relative
	NSString* rootPath;
	if ([self fileURL]) {
		rootPath = [[[self fileURL] path] stringByDeletingLastPathComponent];
	} else {
		rootPath = [[NSFileManager defaultManager] currentDirectoryPath];
	}
	
	// get the selected piece, or create one if necessary
	ZKMMDPiece* piece;	
	NSArray* selectedPieces = [piecesController selectedObjects];
	int selectedCount = [selectedPieces count];
	if (selectedCount > 0) {
		piece = [selectedPieces objectAtIndex: 0];
	} else {
			// create a new piece
		piece = [NSEntityDescription
			insertNewObjectForEntityForName: @"ZKMMDPiece"
			inManagedObjectContext: [self managedObjectContext]];
		piece.title = [[filename lastPathComponent] stringByDeletingPathExtension];
	}
	
	// make path relative
	piece.path = PathRelativeToRoot(filename, rootPath);
}

#pragma mark NSWindow Delegate 
- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib: windowController];

    // user interface preparation code
	[[self windowForSheet] registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[self windowForSheet] unregisterDraggedTypes];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	// only accept files
	if (![[pboard types] containsObject: NSFilenamesPboardType]) return NSDragOperationNone;
	
	// make sure there is at least one Zirkonium file
	NSArray* files = [pboard propertyListForType: NSFilenamesPboardType];
	for (NSString* fileName in files ) {
		if ([[fileName pathExtension] isEqualToString: @"zrkpxml"])
			return NSDragOperationCopy;
	}
	
	return NSDragOperationNone;		
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	if (![[pboard types] containsObject: NSFilenamesPboardType]) return NO;
	
	NSArray* files = [pboard propertyListForType: NSFilenamesPboardType];
	
	// Used to make paths relative
	NSString* rootPath;
	if ([self fileURL]) {
		rootPath = [[[self fileURL] path] stringByDeletingLastPathComponent];
	} else {
		rootPath = [[NSFileManager defaultManager] currentDirectoryPath];
	}
	
	// first modify the selected pieces
	NSArray* selectedPieces = [piecesController selectedObjects];
	int selectedCount = [selectedPieces count];
	int currentSelected = 0;
	for (NSString* fileName in files ) {
		if (![[fileName pathExtension] isEqualToString: @"zrkpxml"]) continue;
		
		ZKMMDPiece* piece;
		if (currentSelected < selectedCount) {
			// modify the selected piece
			piece = [selectedPieces objectAtIndex: currentSelected];
			++currentSelected;
		} else {
			// create a new piece
			piece = [NSEntityDescription
				insertNewObjectForEntityForName: @"ZKMMDPiece"
				inManagedObjectContext: [self managedObjectContext]];
			piece.title = [[fileName lastPathComponent] stringByDeletingPathExtension];
		}

		// make path relative
		piece.path = PathRelativeToRoot(fileName, rootPath);
	}
	
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{

}

@end

NSString* PathRelativeToRoot(NSString* path, NSString* rootPath)
{
	NSArray* pathComponents = [path pathComponents];
	NSArray* rootComponents = [rootPath pathComponents];
	int depth, count = (int) MIN([pathComponents count], [rootComponents count]);
	
	// see how long they are equal
	for (depth = 0; depth < count; ++depth) {
		if (![[pathComponents objectAtIndex: depth] isEqualToString: [rootComponents objectAtIndex: depth]])
			break;
	}
	
	// if they aren't close, just return the full path
	if (depth < ((int) [rootComponents count]) - 2) {
		return path;
	}	

	// construct the relative path
	int i;
	NSMutableArray* relativeComponents = [[NSMutableArray alloc] init];
	for (i = 0; i < [rootComponents count] - depth; ++i)
		[relativeComponents addObject: @".."];
	for (i = depth; i < [pathComponents count]; ++i)
		[relativeComponents addObject: [pathComponents objectAtIndex: i]];
	
	NSString* relativePath = [NSString pathWithComponents: relativeComponents];

	[relativeComponents release];
	
	// check that the file actually exists
	NSURL* relativeURL = [NSURL URLWithString: relativePath relativeToURL: [NSURL fileURLWithPath: rootPath]];
	if (![[NSFileManager defaultManager] fileExistsAtPath: [relativeURL path]]) {
		NSLog(@"Path incorrectly constructed\n%@\n%@", relativePath, relativeURL);
		return path;
	}
	
	return relativePath;
}
