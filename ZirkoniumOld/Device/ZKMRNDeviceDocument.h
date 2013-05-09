//
//  ZKMRNDeviceDocument.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 26.10.06.
//  Copyright C. Ramakrishnan/ZKM 2006 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>

///
///  ZKMRNDeviceDocument
///
///  The class that managed the configuration of the device. I don't have any audio state myself -- that's all
///  global and held by the DeviceManager (thus, I don't have a graph or any conduits).
///
@class ZKMRNZirkoniumSystem, ZKMRNSpatializerView, ZKMRNDeviceManager, ZKMRNGraph;
@interface ZKMRNDeviceDocument : NSPersistentDocument {
	IBOutlet NSWindow*				mainWindow;
	IBOutlet NSTabView*				mainTabView;
	IBOutlet ZKMRNSpatializerView*	spatializerView;
	IBOutlet NSArrayController*		graphChannelsController;  

	NSMutableArray*			_pannerSources;
	ZKMRNZirkoniumSystem*	_system;
	ZKMRNDeviceManager*		_deviceManager;
	Float64					_currentTime;
	BOOL					_isGraphOutOfSynch;
	BOOL					_isEditingPiecePatch;
}

//  UI Actions

//  Accessors
- (ZKMORMixerMatrix *)deviceMixer;
- (NSArray *)pannerSources;
- (ZKMRNGraph *)piecePatch;

- (BOOL)isSpatializerViewShowingInitial;
- (void)setSpatializerViewShowingInitial:(BOOL)isSpatializerViewShowingInitial;
- (ZKMRNDeviceManager *)deviceManager;

//  Convenience Accessors
- (unsigned)numberOfChannels;
- (unsigned)numberOfDirectOuts;

//  Actions
- (void)panChannel:(unsigned)channel az:(ZKMNRSphericalCoordinate)center span:(ZKMNRSphericalCoordinateSpan)span gain:(float)gain;
- (void)panChannel:(unsigned)channel speakerAz:(ZKMNRSphericalCoordinate)center gain:(float)gain;
- (void)panChannel:(unsigned)channel speakerXy:(ZKMNRRectangularCoordinate)center gain:(float)gain;
- (void)panChannel:(unsigned)channel xy:(ZKMNRRectangularCoordinate)center span:(ZKMNRRectangularCoordinateSpan)span gain:(float)gain;
	/// the number of graph channels + direct outs = a constant. This method maintains this relationship
- (void)equalizeNumberOfGraphChannels;

//  UI Accessors
- (float)fontSize;

- (BOOL)isInputOn;
- (void)setInputOn:(BOOL)isInputOn;

- (NSArray *)graphChannelSortDescriptors;
- (void)setGraphChannelSortDescriptors:(NSArray *)graphChannelSortDescriptors;

- (NSArray *)directOutSortDescriptors;
- (void)setDirectOutSortDescriptors:(NSArray *)directOutSortDescriptors;

- (ZKMRNZirkoniumSystem *)zirkoniumSystem;

//  Queries
- (BOOL)isPlaying;

//  Display Update
- (void)tick:(id)timer;

@end

@interface ZKMRNDeviceDocument (ZKMRNPieceDocumentInternal)
- (NSArray *)inputSources;
- (NSArray *)orderedGraphChannels;
	// used by the system when the input patch changes
- (void)synchronizePatchToGraph;
@end

