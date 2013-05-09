//
//  ZKMRNStudioSetupDocument.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Tags for widgets that I support copying on
enum {
	kStudioSetupUITag_SpeakerRing = 101,
	kStudioSetupUITag_Speaker = 102,
	kStudioSetupUITag_SpeakerSetup = 103
};

// Pboard types
extern NSString* ZKMRNSpeakerRingPboardType;
extern NSString* ZKMRNSpeakerPboardType;
extern NSString* ZKMRNSpeakerSetupPboardType;

@class ZKMRNSpeakerSetupView, ZKMRNChannelMapView, ZKMNRSpeakerPosition, ZKMRNDomeView;
@interface ZKMRNStudioSetupDocument : NSPersistentDocument {
	IBOutlet ZKMRNSpeakerSetupView*	domeViewInRoom;
	IBOutlet ZKMRNSpeakerSetupView*	domeViewIdeal;
	IBOutlet ZKMRNChannelMapView*	channelMapView;
	IBOutlet NSArrayController*		speakerSetupController;
	IBOutlet NSArrayController*		speakerRingsController;
	IBOutlet NSArrayController*		speakerPositionsController;
}

//  UI Accessors
- (float)fontSize;
- (NSArray *)speakerRingSortDescriptors;

//  UI Actions
- (IBAction)xRotation:(id)sender;
- (IBAction)yRotation:(id)sender;
- (IBAction)resetRotation:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;

//  ZKMRNSpeakerSetupViewDelegate
- (void)view:(ZKMRNDomeView *)domeView selectedSpeakerPosition:(ZKMNRSpeakerPosition *)speakerPosition;

//  Accessors
- (id)roomWithName:(NSString *)name;
- (id)speakerSetupWithName:(NSString *)name;
- (id)inputPatchWithName:(NSString *)name;
- (id)outputPatchWithName:(NSString *)name;
- (id)directOutPatchWithName:(NSString *)name;

@end

@interface ZKMRNSpeakerPositionsController : NSArrayController {

}

@end
