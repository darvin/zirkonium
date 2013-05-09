//
//  ZKMRNStudioSetupDocument.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>
//#import "ZKMRNDomeView.h"
#import "ZKMRNSpeakerSetupView.h"

// Tags for widgets that I support copying on
enum {
	kStudioSetupUITag_SpeakerRing	= 101,
	kStudioSetupUITag_Speaker		= 102,
	kStudioSetupUITag_SpeakerSetup	= 103,
	kStudioSetupUITag_InputPatch	= 104,
	kStudioSetupUITag_OutputPatch	= 105
};

// Pboard types
extern NSString* ZKMRNSpeakerRingPboardType;
extern NSString* ZKMRNSpeakerPboardType;
extern NSString* ZKMRNSpeakerSetupPboardType;
extern NSString* ZKMRNInputPatchPboardType;
extern NSString* ZKMRNOutputPatchPboardType;

@class ZKMRNZirkoniumSystem;
@class ZKMRNSpeakerSetupView, ZKMRNChannelMapView, ZKMNRSpeakerPosition, ZKMRNDomeView;
@class ZKMRNTestSourceController;
@class ZKMRNDomeViewCameraAdjustment;
@class ZKMRNSpatializerView;
@interface ZKMRNStudioSetupDocument : NSPersistentDocument <ZKMRNDomeViewDelegate>{
	
	IBOutlet NSTabView*				mainTabView;
	IBOutlet ZKMRNSpeakerSetupView*	domeViewInRoom;
	IBOutlet ZKMRNSpeakerSetupView*	domeViewIdeal;
	IBOutlet ZKMRNChannelMapView*	channelMapView;
	IBOutlet NSArrayController*		speakerSetupController;
	IBOutlet NSArrayController*		speakerRingsController;
	IBOutlet NSArrayController*		speakerPositionsController;
	IBOutlet NSArrayController*		outputPatchChannelsController;
	//IBOutlet NSArrayController*		directOutChannelsController;
	IBOutlet NSArrayController*		outputPatchController;
	IBOutlet NSArrayController*		inputPatchController;

	IBOutlet NSArrayController*		directOutController;
	IBOutlet ZKMRNTestSourceController* testSourceController;
	IBOutlet NSWindow*				studioSetupWindow;
	
	IBOutlet NSTableView*			speakerSetupTableView;
	IBOutlet NSTableView*			speakerRingTableView;
	IBOutlet NSTableView*			speakerPositionTableView; 
	IBOutlet NSTableView*			inputPatchTableView; 
	IBOutlet NSTableView*			outputPatchTableView; 

	
	NSManagedObject* _oscConfiguration; 
	NSManagedObject* _oscReceiver;
	
	BOOL _windowIsActive;
}

//  UI Accessors
- (float)fontSize;
- (NSArray *)speakerRingSortDescriptors;
- (BOOL)windowIsActive; 

//  UI Actions
- (IBAction)xRotation:(id)sender;
- (IBAction)yRotation:(id)sender;
- (IBAction)resetRotation:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;

- (IBAction)actionEnableTesting:(id)sender;

// @David
- (IBAction)xmlExportAllSpeakerSetupsMenuItemClicked:(id)sender;

//  ZKMRNSpeakerSetupViewDelegate
//- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition;

//  Accessors
- (id)roomWithName:(NSString *)name;
- (id)speakerSetupWithName:(NSString *)name;
- (id)inputPatchWithName:(NSString *)name;
- (id)outputPatchWithName:(NSString *)name;
//- (id)directOutPatchWithName:(NSString *)name;

-(ZKMRNDomeViewCameraAdjustment*)cameraAdjustment;
-(ZKMRNSpeakerSetupView*)domeViewInRoom;

- (NSManagedObject *)oscConfiguration;
- (void)setOscConfiguration:(NSManagedObject *)oscConfiguration;

- (NSManagedObject *)oscReceiver;
- (void)setOscReceiver:(NSManagedObject *)oscReceiver;

@end

@interface ZKMRNSpeakerPositionsController : NSArrayController {
	IBOutlet NSTableView*	speakerPositionsTableView; 
}
@end

@interface ZKMRNSpeakerRingsController : NSArrayController {
	IBOutlet NSTableView*	speakerRingsTableView; 
}
@end

@interface ZKMRNSpeakerSetupsController : NSArrayController {
	IBOutlet NSTableView*	speakerSetupsTableView; 
}

@end
