//
//  ZKMNRSpeakerLayoutSimulator.h
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 20.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
///  ZKMNRSimulationMode
/// 
///  For what end configuration should the speakers be simulated.
///
typedef enum {
	kZKMNRSpeakerLayoutSimulationMode_Headphones = 0,
	kZKMNRSpeakerLayoutSimulationMode_5Dot0 = 1
} ZKMNRSimulationMode;


///
///  ZKMNRSpeakerLayoutSimulator
/// 
///  Configures an Apple 3D Mixer to simulate a speaker layout.
///
///  The user needs to patch the 3D mixer into a graph herself/himself.
///  Each bus correspondes to one (mono) virtual loudspeaker. The order of the 
///  loudspeakers is the same as the order of the buses. Keep this in mind when
///  patching the mixer into the graph.
///
@class ZKMNRSpeakerLayout, ZKMORMixer3D;
@interface ZKMNRSpeakerLayoutSimulator : NSObject {
	ZKMNRSpeakerLayout*		_speakerLayout;
	ZKMORMixer3D*			_mixer3D;
	ZKMNRSimulationMode		_simulationMode;
}

//  Accessors
- (ZKMNRSpeakerLayout *)speakerLayout;
	/// setSpeakerLayout: will uninitialize the mixer3D. This should only be called
	/// if the graph has not yet been started or if the graph is in editing mode
- (void)setSpeakerLayout:(ZKMNRSpeakerLayout *)speakerLayout;

- (ZKMNRSimulationMode)simulationMode;
	/// setSimulationMode: will uninitialize the mixer3D. This should only be called
	/// if the graph has not yet been started or if the graph is in editing mode
- (void)setSimulationMode:(ZKMNRSimulationMode)simulationMode;

	/// the mixer controlled by the speaker layout simulator -- you need to
	/// patch this into a graph (see class comment).
- (ZKMORMixer3D *)mixer3D;

@end
