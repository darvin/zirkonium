///
///	 ZKMRNSpeakerSetupView
///
///  View that displays the speaker positions in the dome.
///

#import <Cocoa/Cocoa.h>
#import "ZKMRNDomeView.h"
#import "ZKMRNTextures.h"

@interface ZKMRNSpeakerSetupView : ZKMRNDomeView {
	BOOL			editingAllowed;
	BOOL			editMode; 

	NSIndexSet*		_selectedRings;
	// drawing state
	float			_speakerAlpha;
}
@property BOOL editingAllowed; 
@property BOOL editMode; 


/// the selected rings are drawn more prominently than the others
- (NSIndexSet *)selectedRings;
- (void)setSelectedRings:(NSIndexSet *)selectedRings;

@end
