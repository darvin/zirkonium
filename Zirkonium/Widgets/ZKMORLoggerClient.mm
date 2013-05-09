//
//  ZKMORLoggerClient.mm
//  Zirkonium
//
//  Created by Chandrasekhar Ramakrishnan on 29.05.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORLoggerClient.h"
#include <Syncretism/ZKMORLoggerCPP.h>
#include <Syncretism/CAGuard.h>

class ZKMORLoggerClientCPP {
public:
//  CTOR
		/// The LoggerClientCPP is created by the ZKMORLoggerClient, which is a singleton
	ZKMORLoggerClientCPP();
	~ZKMORLoggerClientCPP();
	
//  Accessors
	NSAttributedString*	LogText() { return mLogText; }
	void				SetLogText(NSMutableAttributedString *logText)
	{
		[mLogText release];
		mLogText = logText;
		[mLogText retain];		
	}
	
//  Queries
	bool	HasTokens() { return mHasTokens; }
	
//  Actions	
	void	StartLogging();
	void	StopLogging();
	
		/// Print all current tokens
	void	Flush();

//  Internal	
	static void	LogPrinterNotifyFunction(void* refCon, ZKMORLogger* logger);
	
protected:
	void AppendTokenToLog(ZKMORReadLogToken* token, char* headerBuffer);
	
private:
	bool			mHasTokens;
	CFTimeZoneRef	mTimeZone;
	CAGuard			mMutex;
	
	NSMutableAttributedString*		mLogText;
	NSDictionary*					mLogTextAttributes;
	NSDictionary*					mLogTextErrorAttributes;
};


void	ZKMORLoggerClientCPP::StartLogging()
{
	ZKMORLogger* logger = GlobalLogger();
	logger->SetNotifier(this, LogPrinterNotifyFunction);
}

void	ZKMORLoggerClientCPP::StopLogging()
{
	ZKMORLogger* logger = GlobalLogger();
	logger->SetNotifier(NULL, NULL);
}

void	ZKMORLoggerClientCPP::Flush()
{
	ZKMORLogger* logger = GlobalLogger();
	ZKMORReadLogToken* token;
	char headerBuffer[255];

		// take the lock
	CAGuard::Locker lock(mMutex);
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[mLogText beginEditing];
	logger->BeginReading();
	while (token = logger->GetReadLogToken()) {
		AppendTokenToLog(token, headerBuffer);
		logger->ReturnReadLogToken(token);
	}
	logger->EndReading();
	[mLogText endEditing];
	[pool release];

	mHasTokens = false;
		// CAGuard::Locker's destructor automatically releases the mutex
}

void	ZKMORLoggerClientCPP::LogPrinterNotifyFunction(void* refCon, ZKMORLogger* logger)
{
	reinterpret_cast<ZKMORLoggerClientCPP*>(refCon)->mHasTokens = true;
}

void	ZKMORLoggerClientCPP::AppendTokenToLog(ZKMORReadLogToken* token, char* headerBuffer)
{
	if (token->level & kZKMORLogLevel_Continue)
		headerBuffer[0] = '\0';
	else
		token->SNPrintLogHeader(headerBuffer, 255, mTimeZone);
	NSDictionary* attrs = (token->level > kZKMORLogLevel_Warning) ? mLogTextAttributes : mLogTextErrorAttributes;
	NSString* tokenString = [[NSString alloc] initWithFormat: @"%s%@\n", headerBuffer, token->logString];
	NSAttributedString* tokenAttrString = [[NSAttributedString alloc] initWithString: tokenString attributes: attrs];
	[mLogText appendAttributedString: tokenAttrString];
	[tokenAttrString release];
	[tokenString release];
}

ZKMORLoggerClientCPP::ZKMORLoggerClientCPP() : mHasTokens(false), mMutex("Logger Client Guard")
{
	mTimeZone = CFTimeZoneCopyDefault();
	mLogText = [[NSMutableAttributedString alloc] initWithString: @""];
	NSFont* logTextFont = [NSFont fontWithName: @"Monaco" size: 10.f];

	mLogTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: [NSColor blackColor], NSForegroundColorAttributeName, logTextFont, NSFontAttributeName, nil] retain];
	mLogTextErrorAttributes = [[NSDictionary dictionaryWithObjectsAndKeys: [NSColor redColor], NSForegroundColorAttributeName, logTextFont, NSFontAttributeName, nil] retain];	
}

ZKMORLoggerClientCPP::~ZKMORLoggerClientCPP()
{
	CFRelease(mTimeZone);
	[mLogText release];
	[mLogTextAttributes release];
	[mLogTextErrorAttributes release];
}
	
static ZKMORLoggerClient* sSharedLoggerClient = NULL;

@implementation ZKMORLoggerClient

#pragma mark _____ NSObject overrides
- (void)dealloc
{
	mClient->StopLogging();
	delete mClient;
	[super dealloc];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	mClient = new ZKMORLoggerClientCPP;
	mClient->StartLogging();
	return self;
}

#pragma mark _____ Singleton
+ (ZKMORLoggerClient *)sharedLoggerClient 
{ 
	if (!sSharedLoggerClient) sSharedLoggerClient = [[ZKMORLoggerClient alloc] init];
	return sSharedLoggerClient; 
}

#pragma mark _____ Accessors
- (NSAttributedString *)logText { return mClient->LogText(); }
- (NSTextView *)textView { return _textView; }
- (void)setTextView:(NSTextView *)textView 
{ 
	_textView = textView;
	mClient->SetLogText([_textView textStorage]);
}

#pragma mark _____ Actions
- (void)tick:(id)timer
{
	if (mClient->HasTokens()) mClient->Flush();
}

@end
