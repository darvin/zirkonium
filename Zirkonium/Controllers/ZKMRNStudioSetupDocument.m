//
//  ZKMRNStudioSetupDocument.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNStudioSetupDocument.h"
#import "ZKMRNDomeView.h"
#import "ZKMRNChannelMapView.h"
#import "ZKMRNSpeakerRing.h"
#import "ZKMRNSpeakerSetup.h"
#import "ZKMRNManagedObjectExtensions.h"
#import "ZKMRNZirkoniumSystem.h"
#import "ZKMRNTestSourceController.h"
#import "ZKMRNOutputPatchChannel.h"

NSString* ZKMRNSpeakerRingPboardType	= @"ZKMRNSpeakerRingPboardType";
NSString* ZKMRNSpeakerPboardType		= @"ZKMRNSpeakerPboardType";
NSString* ZKMRNSpeakerSetupPboardType	= @"ZKMRNSpeakerSetupPboardType";
NSString* ZKMRNInputPatchPboardType		= @"ZKMRNInputPatchPboardType";
NSString* ZKMRNOutputPatchPboardType	= @"ZKMRNOutputPatchPboardType";

@implementation ZKMRNStudioSetupDocument

// @David
- (IBAction)xmlExportAllSpeakerSetupsMenuItemClicked:(id)sender
{
	NSXMLDocument * xmlDoc = [[NSXMLDocument alloc] init];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	
	// set root element 
	NSXMLElement * rootElement = [NSXMLNode elementWithName:@"SpeakerSetupCollection"];
	[xmlDoc setRootElement:rootElement];
	
	ZKMNRRectangularCoordinate coord;
	id setup, ring, speaker;
	
	// get setups from controller
	NSSet * setups = [speakerSetupController arrangedObjects];
	for (setup in setups)
	{
		NSXMLElement * setupElement = [NSXMLNode elementWithName:@"SpeakerSetup"];
		[setupElement addAttribute:[NSXMLNode attributeWithName:@"Name" stringValue:[setup valueForKey:@"name"]]];
		[rootElement addChild:setupElement];
		
		NSSet * rings = [setup valueForKeyPath:@"speakerRings"];
		for (ring in rings)
		{
			NSXMLElement * ringElement = [NSXMLNode elementWithName:@"Ring"];
			[ringElement addAttribute:[NSXMLNode attributeWithName:@"Number" stringValue:[ring displayString]]];
			[setupElement addChild:ringElement];
			
			NSSet * speakers = [ring valueForKeyPath:@"speakers"];
			for (speaker in speakers)
			{
				NSXMLElement * speakerElement = [NSXMLNode elementWithName:@"Speaker"];
				
				//[speakerElement addAttribute:[NSXMLNode attributeWithName:@"LayoutIndex" stringValue:[layoutIndexNumber stringValue]]];
				coord = [[speaker speakerPosition] coordRectangular];
				
				[speakerElement addAttribute:[NSXMLNode attributeWithName:@"PositionX" stringValue:[NSString stringWithFormat:@"%f", coord.x]]];
				[speakerElement addAttribute:[NSXMLNode attributeWithName:@"PositionY" stringValue:[NSString stringWithFormat:@"%f", coord.y]]];
				[speakerElement addAttribute:[NSXMLNode attributeWithName:@"PositionZ" stringValue:[NSString stringWithFormat:@"%f", coord.z]]];
				
//				int layoutIndex = [[speaker speakerPosition] layoutIndex];
//				int outputChannel;
//				NSSet * outputs = [outputPatchChannelsController arrangedObjects];
//				for (id output in outputs)
//				{
//					if ([[output valueForKey:@"patchChannel"] intValue] == layoutIndex)
//						outputChannel = [[output valueForKey:@"sourceChannel"] intValue];
//				}
//				[speakerElement addAttribute:[NSXMLNode attributeWithName:@"LayoutIndex" stringValue:[NSString stringWithFormat:@"%d", layoutIndex]]];
//				[speakerElement addAttribute:[NSXMLNode attributeWithName:@"OutputChannel" stringValue:[NSString stringWithFormat:@"%d", outputChannel]]];
//				
				[ringElement addChild:speakerElement];
			}
		}
	}
	
	// open save panel + do saving
	NSSavePanel * savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setExtensionHidden:NO];
	[savePanel setTitle:@"Export Selected Speaker Setup as XML"];
	NSString * extension = @"xml";
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:extension]];
	[savePanel runModal];
	NSURL * fileURL = [savePanel URL];
	NSLog(@"%@", fileURL);
	NSData * xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
	[xmlData writeToURL:fileURL atomically:YES];
	
	[xmlDoc release];
}

#pragma mark -
#pragma mark NSDocument Overrides
// Fix for a bug. See: http://lists.apple.com/archives/Cocoa-dev/2007/Nov/msg00158.html
- (IBAction)saveDocument:(id)sender
{
    if ([[self managedObjectContext] hasChanges]) {
		[super saveDocument:sender];
    }
}

-(NSError *)willPresentError:(NSError *)inError {
 
    // The error is a Core Data validation error if its domain is
    // NSCocoaErrorDomain and it is between the minimum and maximum
    // for Core Data validation error codes.
 
    if (!([[inError domain] isEqualToString:NSCocoaErrorDomain])) {
        return inError;
    }
 
    NSInteger errorCode = [inError code];
    if ((errorCode < NSValidationErrorMinimum) ||
                (errorCode > NSValidationErrorMaximum)) {
        return inError;
    }
 
    // If there are multiple validation errors, inError is an
    // NSValidationMultipleErrorsError. If it's not, return it
 
    if (errorCode != NSValidationMultipleErrorsError) {
        return inError;
    }
 
    // For an NSValidationMultipleErrorsError, the original errors
    // are in an array in the userInfo dictionary for key NSDetailedErrorsKey
    NSArray *detailedErrors = [[inError userInfo] objectForKey:NSDetailedErrorsKey];
 
    // For this example, only present error messages for up to 3 validation errors at a time.
 
    unsigned numErrors = [detailedErrors count];
    NSMutableString *errorString = [NSMutableString stringWithFormat:@"%u validation errors have occurred", numErrors];
 
    if (numErrors > 3) {
        [errorString appendFormat:@".\nThe first 3 are:\n"];
    }
    else {
        [errorString appendFormat:@":\n"];
    }
    NSUInteger i, displayErrors = numErrors > 3 ? 3 : numErrors;
    for (i = 0; i < displayErrors; i++) {
        [errorString appendFormat:@"%@\n",
            [[detailedErrors objectAtIndex:i] localizedDescription]];
    }
 
    // Create a new error with the new userInfo
    NSMutableDictionary *newUserInfo = [NSMutableDictionary
                dictionaryWithDictionary:[inError userInfo]];
    [newUserInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
 
    NSError *newError = [NSError errorWithDomain:[inError domain] code:[inError code] userInfo:newUserInfo];
 
    return newError;
}

#pragma mark _____ NSPersistentDocument Overrides
- (void)awakeFromNib
{	
	[domeViewInRoom bind: @"speakerLayout" toObject: speakerSetupController withKeyPath: @"selection.speakerLayout" options: nil];
	domeViewIdeal.isPositionIdeal = YES;
	[domeViewIdeal bind: @"speakerLayout" toObject: speakerSetupController withKeyPath: @"selection.speakerLayout" options: nil];
	[domeViewInRoom setDelegate: self];
	domeViewInRoom.editingAllowed = YES;
	[domeViewInRoom bind: @"selectedRings" toObject: speakerRingsController withKeyPath: @"selectionIndexes" options: nil];
	[domeViewIdeal setDelegate: self];
	
	[mainTabView selectTabViewItemAtIndex:0];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputPatchChanged:) name:ZKMRNOutputPatchChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:nil];

	[[self managedObjectContext] processPendingChanges]; 
	[[[self managedObjectContext] undoManager] removeAllActions]; 
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
	
	_windowIsActive = YES;
    // user interface preparation code
	[domeViewInRoom		setViewType:kDomeViewSpeakerEditorType];
	[domeViewIdeal		setViewType:kDomeViewSphereMappingType];
	
	[[self managedObjectContext] processPendingChanges]; 
	[[[self managedObjectContext] undoManager] removeAllActions]; 
}

- (id)init 
{
    if ((self = [super init]) == nil) return nil;
	
	_windowIsActive = NO; 
		
    return self;
}

// Added for migration purposes (JB) ...
- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
	if (!(self = [super initWithType: typeName error: outError])) return nil;
			
	// Creating a new document ...	
		
	return self;
}

- (BOOL)configurePersistentStoreCoordinatorForURL: (NSURL *)url ofType: (NSString *) fileType modelConfiguration: (NSString *) configuration storeOptions: (NSDictionary *) storeOptions error: (NSError **)error
{
	NSMutableDictionary *options = nil;
	
	if (storeOptions != nil) {
		options = [storeOptions mutableCopy];
	}
	else {
		options = [[NSMutableDictionary alloc] init];
	}
		
	[options setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
	[options setObject:[NSNumber numberWithBool:YES] forKey:NSIgnorePersistentStoreVersioningOption];
	// Add this line for simple migrations in Snow Leopard
	//[options setObject:[NSNumber numberWithBool:YES] forKey: NSInferMappingModelAutomaticallyOption];
	
	BOOL result = [super configurePersistentStoreCoordinatorForURL:url ofType:fileType modelConfiguration:configuration storeOptions:options error:error];
	
	[options release], options = nil;
	return result;
	
}


// Added for migration purposes (JB) ...
- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{		
	// cd to the import path so file manager operations work correctly ...
	NSString* parentDir = [[absoluteURL path] stringByDeletingLastPathComponent];
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: parentDir];
	
	NSPersistentStoreCoordinator* psc = [[self managedObjectContext] persistentStoreCoordinator];
			
	NSError *error = nil; 
	
	// Source Meta Data ...
	NSDictionary *sourceMetadata = 	[NSPersistentStoreCoordinator metadataForPersistentStoreOfType:typeName URL:absoluteURL error:&error]; 
	if (sourceMetadata == nil) { 
		NSLog(@"Error: Source contains no metadata.");
		return nil; 
	} 
	
	// Destination Model ...
	NSString *configuration = nil ; 
	NSManagedObjectModel *destinationModel = [psc managedObjectModel]; 
//	BOOL pscCompatibile = [destinationModel isConfiguration:configuration compatibleWithStoreMetadata:sourceMetadata];
	
	// Init ...
	if (!(self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError])) return nil;

	/*
	if (!pscCompatibile) {
		NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
		[[managedObjectContext undoManager] disableUndoRegistration];
		[self setOscConfiguration:[NSEntityDescription insertNewObjectForEntityForName:@"OSCConfiguration" inManagedObjectContext:managedObjectContext]];
		[self setOscReceiver:[NSEntityDescription insertNewObjectForEntityForName:@"OSCReceiver" inManagedObjectContext:managedObjectContext]];
		// To avoid undo registration for this insertion, removeAllActions on the undoManager.
		// First call processPendingChanges on the managed object context to force the undo registration
		// for this insertion, then call removeAllActions.
		[[managedObjectContext undoManager] enableUndoRegistration];
		[managedObjectContext processPendingChanges];
		[[managedObjectContext undoManager] removeAllActions];
		[self saveDocument:self];
	}
	*/
	
	[[self managedObjectContext] processPendingChanges];
	[[[self managedObjectContext] undoManager] removeAllActions];

 	/*
	if (kZKMRNPieceVersion != [[metadata valueForKey: kZKMRNPieceVersionKey] unsignedIntValue]) {
		NSLog(@"Opening object with unknown version %@", [metadata valueForKey: kZKMRNPieceVersionKey]);
	}
	*/
	return self;
}


-(void)dealloc
{	
	if(_oscConfiguration)
		[_oscConfiguration release];
	if(_oscReceiver)
		[_oscReceiver release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)windowNibName 
{
    return @"ZKMRNStudioSetupDocument";
}



- (void)windowWillClose:(NSNotification *)notification
{
	if([notification object] == studioSetupWindow)
	{	
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		[domeViewInRoom  unbind: @"speakerLayout"];
		[domeViewIdeal   unbind: @"speakerLayout"];
		_windowIsActive = NO;
	}
}

-(BOOL)windowIsActive{ return _windowIsActive; }
-(ZKMRNDomeViewCameraAdjustment*)cameraAdjustment { return [ZKMRNDomeViewCameraAdjustment sharedManager]; }
-(ZKMRNSpeakerSetupView*)domeViewInRoom { return domeViewInRoom; }
#pragma mark _____ UI Accessors
- (float)fontSize { return 11.f; }
- (NSArray *)speakerRingSortDescriptors;
{
	NSSortDescriptor* ringNumberDescriptor = [[NSSortDescriptor alloc] initWithKey: @"ringNumber" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: ringNumberDescriptor];
	[ringNumberDescriptor release];
	return descriptors;
}

-(void)setSpeakerRingSortDescriptors:(NSArray *)speakerRingSortDescriptors {}

#pragma mark _____ UI Actions
- (IBAction)xRotation:(id)sender { [domeViewInRoom setXRotation: [sender floatValue]], [domeViewIdeal setXRotation: [sender floatValue]]; }
- (IBAction)yRotation:(id)sender { [domeViewInRoom setYRotation: [sender floatValue]], [domeViewIdeal setYRotation: [sender floatValue]]; }
- (IBAction)resetRotation:(id)sender { [domeViewInRoom resetRotation], [domeViewIdeal resetRotation]; }

- (IBAction)copy:(id)sender
{
	NSArray* windowControllers = [self windowControllers];
	if (!windowControllers || [windowControllers count] < 1) return;
	if(![studioSetupWindow isKeyWindow]) return; 
	id responder = [studioSetupWindow/*[windowControllers objectAtIndex: 0] window]*/ firstResponder];
	
	if (!responder || ![responder isKindOfClass: [NSView class]]) return;
	
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	NSManagedObject* mo = nil;

	int tag = [responder tag];
	switch (tag) {
		case kStudioSetupUITag_SpeakerRing:
		{
			mo = [[speakerRingsController selectedObjects] objectAtIndex: 0];
			[pboard declareTypes: [NSArray arrayWithObjects: ZKMRNSpeakerRingPboardType, NSStringPboardType, nil] owner: self];
			[pboard setPropertyList: [mo dictionaryRepresentation] forType: ZKMRNSpeakerRingPboardType];
			[pboard setString: [NSString stringWithFormat: @"Ring %@", [mo dictionaryRepresentation]] forType: NSStringPboardType];
		}	break;
		case kStudioSetupUITag_Speaker:
		{
			mo = [[speakerPositionsController selectedObjects] objectAtIndex: 0];
			[pboard declareTypes: [NSArray arrayWithObjects: ZKMRNSpeakerPboardType, NSStringPboardType, nil] owner: self];
			[pboard setPropertyList: [mo dictionaryRepresentation] forType: ZKMRNSpeakerPboardType];
			[pboard setString: [NSString stringWithFormat: @"Speaker %@", [mo dictionaryRepresentation]] forType: NSStringPboardType];
		}	break;
		case kStudioSetupUITag_SpeakerSetup:
		{
			mo = [[speakerSetupController selectedObjects] objectAtIndex: 0];
			[pboard declareTypes: [NSArray arrayWithObjects: ZKMRNSpeakerSetupPboardType, NSStringPboardType, nil] owner: self];
			[pboard setPropertyList: [mo dictionaryRepresentation] forType: ZKMRNSpeakerSetupPboardType];
			[pboard setString: [NSString stringWithFormat: @"SpeakerSetup %@", [mo dictionaryRepresentation]] forType: NSStringPboardType];
			if ([pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerSetupPboardType]]) { NSLog(@"Type available"); }
		}	break;
		case kStudioSetupUITag_InputPatch:
		{
			mo = [[inputPatchController selectedObjects] objectAtIndex: 0];
			NSDictionary* dict = [mo dictionaryRepresentation]; //dictionaryWithValuesForKeys:[NSArray arrayWithObjects:@"name", @"numberOfChannels", nil]];
			[pboard declareTypes: [NSArray arrayWithObjects: ZKMRNInputPatchPboardType, NSStringPboardType, nil] owner: self];
			if(![pboard setPropertyList: dict forType: ZKMRNInputPatchPboardType]) 
			if(![pboard setString: [NSString stringWithFormat: @"InputPatch %@", dict] forType: NSStringPboardType]) NSLog(@"NO 2");
		}	break;
		case kStudioSetupUITag_OutputPatch:
		{
			mo = [[outputPatchController selectedObjects] objectAtIndex: 0];
			[pboard declareTypes: [NSArray arrayWithObjects: ZKMRNOutputPatchPboardType, NSStringPboardType, nil] owner: self];
			[pboard setPropertyList: [mo dictionaryRepresentation] forType: ZKMRNOutputPatchPboardType];
			[pboard setString: [NSString stringWithFormat: @"OutputPatch %@", [mo dictionaryRepresentation]] forType: NSStringPboardType];
		}	break;
		
		
		default:
			break;
	}
}

- (IBAction)paste:(id)sender
{
	NSArray* windowControllers = [self windowControllers];
	if (!windowControllers || [windowControllers count] < 1) return;
	if(![studioSetupWindow isKeyWindow]) return; 
	
	id responder = [studioSetupWindow firstResponder];
	if (!responder || ![responder isKindOfClass: [NSView class]]) return;
	
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	NSManagedObjectContext* moc = [self managedObjectContext];	
	NSManagedObject* mo = nil;
	NSDictionary* dictRepresentation = nil;
	
	int tag = [responder tag];
	switch (tag) {
		
		case kStudioSetupUITag_SpeakerRing:
		{
			// return if we paste to currently selected speaker setup ...
			NSManagedObject* speakerSetup = [[speakerSetupController selectedObjects] lastObject];
			if ([speakerSetup isEqualTo:[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] speakerSetup]]) { return; }
			
			// paste ...
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerRingPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNSpeakerRingPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"SpeakerRing" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
			
			[speakerRingsController addObject:mo];
			
		}	break;
		case kStudioSetupUITag_Speaker:
		{
			// return if we paste to currently selected speaker setup ...
			NSManagedObject* speakerSetup = [[speakerSetupController selectedObjects] lastObject];
			if ([speakerSetup isEqualTo:[[ZKMRNZirkoniumSystem sharedZirkoniumSystem] speakerSetup]]) { return; }
		
			// paste ...
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNSpeakerPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"Speaker" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
		
			[speakerPositionsController addObject:mo];
			[speakerPositionTableView scrollRectToVisible:[speakerPositionTableView rectOfRow:[speakerPositionTableView selectedRow]]];			
		}	break;
		case kStudioSetupUITag_SpeakerSetup:
		{
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerSetupPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNSpeakerSetupPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"SpeakerSetup" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
			[speakerSetupController addObject: mo];		
			[speakerSetupTableView scrollRectToVisible:[speakerSetupTableView rectOfRow:[speakerSetupTableView selectedRow]]];			
		}	break;
		case kStudioSetupUITag_InputPatch:
		{
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNInputPatchPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNInputPatchPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"InputPatch" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
			[inputPatchController addObject: mo];		
			[inputPatchTableView scrollRectToVisible:[inputPatchTableView rectOfRow:[inputPatchTableView selectedRow]]];			
		}	break;
		case kStudioSetupUITag_OutputPatch:
		{
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNOutputPatchPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNOutputPatchPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"OutputPatch" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
			[outputPatchController addObject: mo];		
			[outputPatchTableView scrollRectToVisible:[outputPatchTableView rectOfRow:[outputPatchTableView selectedRow]]];			
			
		}	break;
		default:
			break;
	}
}

#pragma mark _____ ZKMRNSpeakerSetupViewDelegate
- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition
{
	id speaker = [speakerPosition tag];
	NSArray* rings = [NSArray arrayWithObject: [speaker valueForKey: @"speakerRing"]];
	NSArray* speakers = [NSArray arrayWithObject: speaker];	
	[speakerRingsController setSelectedObjects: rings];
	[speakerPositionsController setSelectedObjects: speakers];
}

#pragma mark _____ Accessors
- (id)roomWithName:(NSString *)name
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"Room" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"name like %@", name];
	[request setPredicate: predicate];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return [array lastObject];
}

- (id)speakerSetupWithName:(NSString *)name
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"SpeakerSetup" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"name like %@", name];
	[request setPredicate: predicate];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return [array lastObject];
}

- (id)inputPatchWithName:(NSString *)name
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"InputPatch" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"name like %@", name];
	[request setPredicate: predicate];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return [array lastObject];
}

- (id)outputPatchWithName:(NSString *)name
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"OutputPatch" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"name like %@", name];
	[request setPredicate: predicate];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return [array lastObject];
}


/*
- (id)directOutPatchWithName:(NSString *)name
{
	NSManagedObjectContext* moc = [self managedObjectContext];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"DirectOutPatch" inManagedObjectContext: moc];
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setEntity: entity];
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"name like %@", name];
	[request setPredicate: predicate];
	NSError* error = nil;
	NSArray* array = [moc executeFetchRequest: request error: &error];
	[request release];		
	if (error) {
		[self presentError: error];
		return nil;
	}
	return [array lastObject];
}
*/

#pragma mark -

- (NSManagedObject *)oscConfiguration
{
	if (_oscConfiguration != nil)
	{
        return _oscConfiguration;
    }
	
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSError *fetchError = nil;
    NSArray *fetchResults;
	
    @try
	{
		[[moc undoManager] disableUndoRegistration];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"OSCConfiguration"
												  inManagedObjectContext:moc];
		
        [fetchRequest setEntity:entity];
        fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
		[[moc undoManager] enableUndoRegistration];
    } @finally
	{
        [fetchRequest release];
    }
	
    if ((fetchResults != nil) && ([fetchResults count] == 1) && (fetchError == nil))
	{
        [self setOscConfiguration:[fetchResults objectAtIndex:0]];
        return _oscConfiguration;
    } else {
		// something went wrong ...
		if(!fetchResults) {
			NSLog(@"No OSC Configuration Found ... Creating new one ...");
			
			// Create new osc configuration and add it to the store ...
			NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
			[[managedObjectContext undoManager] disableUndoRegistration];
			
			[self setOscConfiguration:[NSEntityDescription insertNewObjectForEntityForName:@"OSCConfiguration" inManagedObjectContext:managedObjectContext]];
			
			// To avoid undo registration for this insertion, removeAllActions on the undoManager.
			// First call processPendingChanges on the managed object context to force the undo registration
			// for this insertion, then call removeAllActions.
			[[managedObjectContext undoManager] enableUndoRegistration];
			[managedObjectContext processPendingChanges];
			[[managedObjectContext undoManager] removeAllActions];
			[self saveDocument:self];
			return _oscConfiguration;
		}
		
		else if([fetchResults count] > 1) {
			// too many receivers ...
			// remove all
			
			NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
			[[managedObjectContext undoManager] disableUndoRegistration];

			NSLog(@"Too many OSC Configurations Found ... Deleting all and creating new one ...");
			
			// remove all ...
			for(NSManagedObject* mo in fetchResults)
				[managedObjectContext deleteObject:mo];
			
			// create new ...
			[self setOscConfiguration:[NSEntityDescription insertNewObjectForEntityForName:@"OSCConfiguration" inManagedObjectContext:managedObjectContext]];
			[self setOscReceiver:[NSEntityDescription insertNewObjectForEntityForName:@"OSCReceiver" inManagedObjectContext:managedObjectContext]];
			
			// To avoid undo registration for this insertion, removeAllActions on the undoManager.
			// First call processPendingChanges on the managed object context to force the undo registration
			// for this insertion, then call removeAllActions.

			[[managedObjectContext undoManager] enableUndoRegistration];
			[managedObjectContext processPendingChanges];
			[[managedObjectContext undoManager] removeAllActions];
			[self saveDocument:self];
			return _oscConfiguration;


		}
	}
	
    if (fetchError != nil)
	{
        [self presentError:fetchError];
    }
    else {
        // should present custom error message...
    }
    return nil;

}

- (void)setOscConfiguration:(NSManagedObject *)oscConfiguration
{
	if (_oscConfiguration != oscConfiguration)
	{
		[_oscConfiguration release];
        _oscConfiguration = [oscConfiguration retain];
    }
}

#pragma mark -

- (NSManagedObject *)oscReceiver
{
	if (_oscReceiver != nil)
	{
        return _oscReceiver;
    }
	
    NSManagedObjectContext *moc = [self managedObjectContext];
	
	
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSError *fetchError = nil;
    NSArray *fetchResults;
	
    @try
	{
		[[moc undoManager] disableUndoRegistration];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"OSCReceiver"
												  inManagedObjectContext:moc];
		
        [fetchRequest setEntity:entity];
        fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
		[[moc undoManager] enableUndoRegistration];
		
    } @finally
	{
        [fetchRequest release];
    }
	
    if ((fetchResults != nil) && ([fetchResults count] == 1) && (fetchError == nil))
	{
        [self setOscReceiver:[fetchResults objectAtIndex:0]];
        return _oscReceiver;
    } else {
		// something went wrong ...
		if(!fetchResults) {
			NSLog(@"No OSC Receiver Found ... Creating new one ...");
			
			// Create new osc configuration and add it to the store ...
			NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
			[[managedObjectContext undoManager] disableUndoRegistration];
			
			[self setOscReceiver:[NSEntityDescription insertNewObjectForEntityForName:@"OSCReceiver" inManagedObjectContext:managedObjectContext]];
			
			// To avoid undo registration for this insertion, removeAllActions on the undoManager.
			// First call processPendingChanges on the managed object context to force the undo registration
			// for this insertion, then call removeAllActions.
			[[managedObjectContext undoManager] enableUndoRegistration];
			[managedObjectContext processPendingChanges];
			[[managedObjectContext undoManager] removeAllActions];
			[self saveDocument:self];
			return _oscReceiver;
		}
		
		else if([fetchResults count] > 1) {
			// too many receivers ...
			// remove all
			
			NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
			[[managedObjectContext undoManager] disableUndoRegistration];

			NSLog(@"Too many OSC Receivers Found ... Deleting all and creating new one ...");
			
			// remove all ...
			for(NSManagedObject* mo in fetchResults)
				[managedObjectContext deleteObject:mo];
			
			// create new ...
			[self setOscReceiver:[NSEntityDescription insertNewObjectForEntityForName:@"OSCReceiver" inManagedObjectContext:managedObjectContext]];
			
			// To avoid undo registration for this insertion, removeAllActions on the undoManager.
			// First call processPendingChanges on the managed object context to force the undo registration
			// for this insertion, then call removeAllActions.

			[[managedObjectContext undoManager] enableUndoRegistration];
			[managedObjectContext processPendingChanges];
			[[managedObjectContext undoManager] removeAllActions];
			[self saveDocument:self];
			return _oscReceiver;


		}
	}
	
    if (fetchError != nil)
	{
        [self presentError:fetchError];
    }
    else {
        // should present custom error message...
    }
    return nil;
}

- (void)setOscReceiver:(NSManagedObject *)oscReceiver
{
	if (_oscReceiver != oscReceiver) {
		[_oscReceiver release];
        _oscReceiver = [oscReceiver retain];
    }
}

#pragma mark -

- (IBAction)actionEnableTesting:(id)sender
{
	[testSourceController bindToOutputController:outputPatchChannelsController isTestingPanner:NO]; //bind
	[testSourceController setIsTestingInPresets:(BOOL)[sender state]];												//state
	[testSourceController setIsTestingInPreferences:NO];
	
	[testSourceController setGraphTesting:(BOOL)[sender state]];									//audio
}

#pragma mark _____ Notifications

-(void)outputPatchChanged:(NSNotification*)inNotification
{
	[mainTabView setNeedsDisplay:YES];
}

#pragma mark _____ NSTabViewDelegates
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem { return YES; }

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem { }

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView { }

- (void)tableViewSelectionDidChange:(NSNotification*)notification
{
	NSArray* selectedSpeakerPositions = [speakerPositionsController selectedObjects];
	if(selectedSpeakerPositions && [selectedSpeakerPositions count]>0) {
		[domeViewInRoom setSelectedSpeakerPositions:selectedSpeakerPositions];
	}
}

@end

#pragma mark -

@implementation ZKMRNSpeakerPositionsController

- (void)add:(id)sender
{
	ZKMRNSpeaker* newSpeaker = [self newObject]; 
	if(newSpeaker) {
		[self addObject:newSpeaker];
			
		// automatically position new speaker for convenience ...
		int speakerRing    = [[newSpeaker valueForKeyPath:@"speakerRing.ringNumber"] intValue];
		int speakersOnRing = [[[newSpeaker valueForKeyPath:@"speakerRing.speakers"] allObjects] count]; 
		ZKMNRSphericalCoordinate   coordSpherical   = {0.6f * speakersOnRing, 0.0f, 1.0f - (0.2 * speakerRing) };
		ZKMNRRectangularCoordinate coordRectangular = ZKMNRCircularCoordinateToRectangular(coordSpherical); 
		float x = coordRectangular.x;
		float y = coordRectangular.y;
		float z = 0.2 * speakerRing; 
		[newSpeaker setValue:[NSNumber numberWithFloat:x] forKey:@"positionX"];
		[newSpeaker setValue:[NSNumber numberWithFloat:y] forKey:@"positionY"];	
		[newSpeaker setValue:[NSNumber numberWithFloat:z] forKey:@"positionZ"];
		
		[[newSpeaker valueForKey: @"speakerRing"] speakerRingChanged];

		[newSpeaker autorelease];
	}
}

- (void)addObject:(id)object
{
	if(!object) return; 
	
	[super addObject: object];
	
	[[object valueForKey: @"speakerRing"] speakerRingChanged];
	[[[self managedObjectContext] undoManager] registerUndoWithTarget:self selector:@selector(removeObject:) object:object];
	[[[self managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Add Speaker", @"speaker add")];
		
	[speakerPositionsTableView scrollRectToVisible:[speakerPositionsTableView rectOfRow:[speakerPositionsTableView selectedRow]]];			

}

- (void)remove:(id)sender
{
	id object = [[self selectedObjects] lastObject];
	if(object)
		[self removeObject:object];
}

- (void)removeObject:(id)object
{
	id speakerRing = [object valueForKeyPath:@"speakerRing"];
	
	[super removeObject: object];

	if(speakerRing) [speakerRing speakerRingChanged];
}

@end

#pragma mark -

@implementation ZKMRNSpeakerRingsController

- (void)add:(id)sender
{
	id newObject = [self newObject];
	if(newObject) {
		[self addObject:newObject];
		[newObject  autorelease];
	}

}

- (void)addObject:(id)object
{
	if(!object) return;
	
	int maxRing = 0;
	id aRing;
	NSArray* rings = [self arrangedObjects];
	for(aRing in rings) {
		maxRing = MAX(maxRing, [[aRing valueForKey:@"ringNumber"] intValue]);
	}
	if([rings count]==0) [object setValue:[NSNumber numberWithInt:0] forKey:@"ringNumber"];
	else [object setValue:[NSNumber numberWithInt:maxRing+1] forKey:@"ringNumber"];
	
	[super addObject: object];
	
	//update speakers if any after paste operation
	[object speakerRingChanged];
	[[[self managedObjectContext] undoManager] registerUndoWithTarget:self selector:@selector(removeObject:) object:object];
	[[[self managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Add Speaker Ring", @"speaker ring add")];
	
	[speakerRingsTableView scrollRectToVisible:[speakerRingsTableView rectOfRow:[speakerRingsTableView selectedRow]]];			

	
}

-(BOOL)canRemove
{
	// do not delete first ring unless it is the only ring
	id object = [[self selectedObjects] lastObject];
	int ringNumber = [[object valueForKey:@"ringNumber"] intValue];
	id speakerSetup = [object valueForKey:@"speakerSetup"];
	NSSet*   rings = [speakerSetup valueForKey:@"speakerRings"];
	
	return ([super canRemove] && !(0==ringNumber && [[rings allObjects] count]!=1)); 
}


- (void)remove:(id)sender
{
	id object = [[self selectedObjects] lastObject];
	if(object) {
		[self removeObject: object];
	}
}

- (void)removeObject:(id)object
{	
	
	//reassign ringNumbers
	int ringNumber = [[object valueForKey:@"ringNumber"] intValue];
	id speakerSetup = [object valueForKey:@"speakerSetup"];
	NSSet*   rings = [speakerSetup valueForKey:@"speakerRings"];

	id aRing; 
	for(aRing in [rings allObjects]) {
		int n = [[aRing valueForKey:@"ringNumber"] intValue];
		if(n>ringNumber) [aRing setValue:[NSNumber numberWithInt:n-1] forKey:@"ringNumber"]; 
	}
	[super removeObject:object];
	
	if(speakerSetup) [speakerSetup speakerRingsChanged];
}

@end

#pragma mark -

@implementation ZKMRNSpeakerSetupsController

- (void)add:(id)sender
{
	id newObject = [self newObject];
	if(newObject) {
		[self addObject:newObject];
		[newObject autorelease];
	}

}

- (void)addObject:(id)object
{
	if(!object) return;
	
	[super addObject: object];

	if (object) {
		[[[self managedObjectContext] undoManager] registerUndoWithTarget:self selector:@selector(removeObject:) object:object];
		[[[self managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Add Speaker Setup", @"speaker setup add")];
	}
	
	[speakerSetupsTableView scrollRectToVisible:[speakerSetupsTableView rectOfRow:[speakerSetupsTableView selectedRow]]];			
}

- (void)remove:(id)sender
{
	id object = [[self selectedObjects] lastObject];
	if(object) {
		[self removeObject: object];
	}
}

- (void)removeObject:(id)object
{
	if(object)
		[super removeObject:object];
}

@end

