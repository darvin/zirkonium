//
//  ZKMORLoggerClient.h
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 29.05.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import <Syncretism/Syncretism.h>


ZKMDECLCPPT(ZKMORLoggerClientCPP);

@interface ZKMORLoggerClient : NSObject {
	ZKMCPPT(ZKMORLoggerClientCPP)	mClient;
	NSTextView*						_textView;
}

//  Singleton
+ (ZKMORLoggerClient *)sharedLoggerClient;

//  Accessors
- (NSAttributedString *)logText;

	/// the text view associated with the log -- necessary so the logger client can properly update the text view
- (NSTextView *)textView;
	/// set the text view associated with the log -- necessary so the logger client can properly update the text view
- (void)setTextView:(NSTextView *)textVeiw;

// Actions
/// tick retrieves any new tokens and logs them into the attributed string
- (void)tick:(id)timer;

@end
