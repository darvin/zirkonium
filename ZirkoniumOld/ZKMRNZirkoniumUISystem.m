//
//  ZKMRNZirkoniumUISystem.m
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 01.03.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNZirkoniumUISystem.h"
#import "ZKMRNPreferencesController.h"
#import "ZKMRNStudioSetupDocument.h"
#import "ZKMRNPreferencesController.h"
#import "ZKMRNPieceDocument.h"
#import "ZKMRNOutputPatch.h"
#import "ZKMRNOutputPatchChannel.h"
#import "ZKMRNDirectOutPatch.h"
#import "ZKMRNFileV1Importer.h"



extern ZKMRNZirkoniumSystem* gSharedZirkoniumSystem;


@implementation ZKMRNZirkoniumUISystem

- (void)synchronizeInputPatch
{
	[super synchronizeInputPatch];
	if (_playingPiece) [_playingPiece synchronizePatchToGraph];
}

#pragma mark _____ ZKMRNZirkoniumSystemInternal
- (void)synchronizeOutputPatch
{
	[super synchronizeOutputPatch];
	[_deviceManager synchronizeOutputPatch];
}

@end
