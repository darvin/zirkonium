//
//  ZKMRNChannelMapView.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 08.11.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ZKMRNOpenGLView.h"


///
///	 ZKMRNChannelMapView
///
///  View for displaying and editing channel maps.
///
@class ZKMRNChannelMap, ZKMRNOpenGLCube;
@interface ZKMRNChannelMapView : ZKMRNOpenGLView {
	ZKMRNChannelMap*	_channelMap;
	ZKMRNOpenGLCube*	_cube;
	
	ZKMRNCameraState	_camera;
}

//  Accessors
- (ZKMRNChannelMap *)channelMap;
- (void)setChannelMap:(ZKMRNChannelMap *)channelMap;

@end
