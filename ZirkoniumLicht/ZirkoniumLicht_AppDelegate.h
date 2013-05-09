//
//  ZirkoniumLicht_AppDelegate.h
//  ZirkoniumLicht
//
//  Created by Chandrasekhar Ramakrishnan on 19.07.07.
//  Copyright C. Ramakrishnan/ZKM 2007 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Syncretism/Syncretism.h>


@class ZKMRLZirkoniumLightSystem, ZKMRLLightView;
@interface ZirkoniumLicht_AppDelegate : NSObject 
{
    IBOutlet NSWindow *window;
    
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	
	ZKMRLZirkoniumLightSystem*	_system;
	
	// To Move to Preferences Controller...
	IBOutlet ZKMRLLightView*	lightView;
	ZKMNRPannerSource*			_testPannerSource;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (void)tick:(id)sender;

- (IBAction)saveAction: sender;
- (IBAction)openPreferences:(id)sender;

@end
