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
#import "ZKMRNManagedObjectExtensions.h"

NSString* ZKMRNSpeakerRingPboardType = @"ZKMRNSpeakerRingPboardType";
NSString* ZKMRNSpeakerPboardType = @"ZKMRNSpeakerPboardType";
NSString* ZKMRNSpeakerSetupPboardType = @"ZKMRNSpeakerSetupPboardType";

@implementation ZKMRNStudioSetupDocument

#pragma mark -
#pragma mark NSDocument Overrides
// Fix for a bug. See: http://lists.apple.com/archives/Cocoa-dev/2007/Nov/msg00158.html
- (IBAction)saveDocument:(id)sender
{
    if ([[self managedObjectContext] hasChanges]) {
		[super saveDocument:sender];
    }
}

#pragma mark _____ NSPersistentDocument Overrides
- (void)awakeFromNib
{
	[domeViewInRoom bind: @"speakerLayout" toObject: speakerSetupController withKeyPath: @"selection.speakerLayout" options: nil];
	[domeViewIdeal setPositionIdeal: YES];
	[domeViewIdeal bind: @"speakerLayout" toObject: speakerSetupController withKeyPath: @"selection.speakerLayout" options: nil];
	[domeViewInRoom setDelegate: self];
	[domeViewInRoom setEditingAllowed: YES];
	[domeViewInRoom bind: @"selectedRings" toObject: speakerRingsController withKeyPath: @"selectionIndexes" options: nil];
	[domeViewIdeal setDelegate: self];
}

- (id)init 
{
    if ((self = [super init]) == nil) return nil;
	

    return self;
}

- (NSString *)windowNibName 
{
    return @"ZKMRNStudioSetupDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

- (void)windowWillClose:(NSNotification *)notification
{
	[domeViewInRoom unbind: @"speakerLayout"];
}

#pragma mark _____ UI Accessors
- (float)fontSize { return 11.f; }
- (NSArray *)speakerRingSortDescriptors;
{
	NSSortDescriptor* ringNumberDescriptor = [[NSSortDescriptor alloc] initWithKey: @"ringNumber" ascending: YES];
	NSArray* descriptors = [NSArray arrayWithObject: ringNumberDescriptor];
	[ringNumberDescriptor release];
	return descriptors;
}

#pragma mark _____ UI Actions
- (IBAction)xRotation:(id)sender { [domeViewInRoom setXRotation: [sender floatValue]], [domeViewIdeal setXRotation: [sender floatValue]]; }
- (IBAction)yRotation:(id)sender { [domeViewInRoom setYRotation: [sender floatValue]], [domeViewIdeal setYRotation: [sender floatValue]]; }
- (IBAction)resetRotation:(id)sender { [domeViewInRoom resetRotation], [domeViewIdeal resetRotation]; }

- (IBAction)copy:(id)sender
{
	NSArray* windowControllers = [self windowControllers];
	if (!windowControllers || [windowControllers count] < 1) return;
	id responder = [[[windowControllers objectAtIndex: 0] window] firstResponder];
	if (!responder || ![responder isKindOfClass: [NSView class]]) return;
	
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	int tag = [responder tag];
	switch (tag) {
		NSManagedObject* mo;
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
		}	break;
		default:
			break;
	}
}

- (IBAction)paste:(id)sender
{
	NSArray* windowControllers = [self windowControllers];
	if (!windowControllers || [windowControllers count] < 1) return;
	id responder = [[[windowControllers objectAtIndex: 0] window] firstResponder];
	if (!responder || ![responder isKindOfClass: [NSView class]]) return;
	
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	NSManagedObjectContext* moc = [self managedObjectContext];	
	int tag = [responder tag];
	switch (tag) {
		NSManagedObject* mo;
		NSDictionary* dictRepresentation;
		case kStudioSetupUITag_SpeakerRing:
		{
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerRingPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNSpeakerRingPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"SpeakerRing" inManagedObjectContext: moc];
			NSManagedObject* speakerSetup = [[speakerSetupController selectedObjects] lastObject];
			if (speakerSetup) {
				[mo setValue: speakerSetup forKey: @"speakerSetup"];
				[mo setFromDictionaryRepresentation: dictRepresentation];
			}
		}	break;
		case kStudioSetupUITag_Speaker:
		{
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNSpeakerPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"Speaker" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
			NSManagedObject* speakerRing = [[speakerRingsController selectedObjects] lastObject];
			if (speakerRing) {
				[mo setValue: speakerRing forKey: @"speakerRing"];
				[mo setFromDictionaryRepresentation: dictRepresentation];
			}
		}	break;
		case kStudioSetupUITag_SpeakerSetup:
		{
			if (![pboard availableTypeFromArray: [NSArray arrayWithObject: ZKMRNSpeakerSetupPboardType]]) break;
			dictRepresentation = [pboard propertyListForType: ZKMRNSpeakerSetupPboardType];
			mo = [NSEntityDescription insertNewObjectForEntityForName: @"SpeakerSetup" inManagedObjectContext: moc];
			[mo setFromDictionaryRepresentation: dictRepresentation];
			[speakerSetupController addObject: mo];		
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

@end

@implementation ZKMRNSpeakerPositionsController

- (void)add:(id)sender
{
	[super add: sender];
	id object = [[self selectedObjects] lastObject];
	if (object) [[object valueForKey: @"speakerRing"] speakerRingChanged];
}

- (void)addObject:(id)object
{
	[super addObject: object];
	[[object valueForKey: @"speakerRing"] speakerRingChanged];
}

- (void)remove:(id)sender
{
	id object = [[self selectedObjects] lastObject];
	[super remove: sender];
	if (object) [[object valueForKey: @"speakerRing"] speakerRingChanged];
}

- (void)removeObject:(id)object
{
	[super removeObject: object];
	[[object valueForKey: @"speakerRing"] speakerRingChanged];
}

@end
