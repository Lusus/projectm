// main drawing and interface code for Mac OS iTunes
// Mischa Spiegelmock, 2012

// based on the iTunes SDK example code

#import "iprojectM.hpp"

#import <AppKit/AppKit.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <string.h>

//-------------------------------------------------------------------------------------------------
//	constants, etc.
//-------------------------------------------------------------------------------------------------

#define kTVisualPluginName              CFSTR("projectM")

extern "C" OSStatus iTunesPluginMainMachO( OSType inMessage, PluginMessageInfo *inMessageInfoPtr, void *refCon ) __attribute__((visibility("default")));

#if USE_SUBVIEW
@interface VisualView : NSOpenGLView
{
	VisualPluginData *	_visualPluginData;
}

@property (nonatomic, assign) VisualPluginData * visualPluginData;

- (void)drawRect:(NSRect)dirtyRect;
- (BOOL)acceptsFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (void)keyDown:(NSEvent *)theEvent;

@end

#endif	// USE_SUBVIEW

void DrawVisual( VisualPluginData * visualPluginData )
{
	CGPoint where;

    VISUAL_PLATFORM_VIEW drawView = visualPluginData->subview;
    	
	if ( drawView == NULL )
		return;
    
    [[drawView openGLContext] makeCurrentContext];

    if (visualPluginData->pm == NULL) {
        initProjectM(visualPluginData);
        
        // correctly size it
        ResizeVisual(visualPluginData);
    }
    
	glClearColor( 0.0, 0.5, 0.0, 0.0 );
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // render
    visualPluginData->pm->renderFrame();
    
    glFlush();
    
	// should we draw the info/artwork in the bottom-left corner?
	time_t		theTime = time( NULL );

	if ( theTime < visualPluginData->drawInfoTimeOut )
	{
		where = CGPointMake( 10, 10 );

		// if we have a song title, draw it (prefer the stream title over the regular name if we have it)
		NSString *				theString = NULL;

		if ( visualPluginData->streamInfo.streamTitle[0] != 0 )
			theString = [NSString stringWithCharacters:&visualPluginData->streamInfo.streamTitle[1] length:visualPluginData->streamInfo.streamTitle[0]];
		else if ( visualPluginData->trackInfo.name[0] != 0 )
			theString = [NSString stringWithCharacters:&visualPluginData->trackInfo.name[1] length:visualPluginData->trackInfo.name[0]];
		
		if ( theString != NULL )
		{
			NSDictionary *		attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor], NSForegroundColorAttributeName, NULL];
			
			[theString drawAtPoint:where withAttributes:attrs];
		}

		// draw the artwork
		if ( visualPluginData->currentArtwork != NULL )
		{
			where.y += 20;

			[visualPluginData->currentArtwork drawAtPoint:where fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.75];
		}
	}
}

//-------------------------------------------------------------------------------------------------
//	UpdateArtwork
//-------------------------------------------------------------------------------------------------
//
void UpdateArtwork( VisualPluginData * visualPluginData, CFDataRef coverArt, UInt32 coverArtSize, UInt32 coverArtFormat )
{
	// release current image
	[visualPluginData->currentArtwork release];
	visualPluginData->currentArtwork = NULL;
	
	// create 100x100 NSImage* out of incoming CFDataRef if non-null (null indicates there is no artwork for the current track)
	if ( coverArt != NULL )
	{
		visualPluginData->currentArtwork = [[NSImage alloc] initWithData:(NSData *)coverArt];
		
		[visualPluginData->currentArtwork setSize:CGSizeMake( 100, 100 )];
	}
	
	UpdateInfoTimeOut( visualPluginData );
}

//-------------------------------------------------------------------------------------------------
//	InvalidateVisual
//-------------------------------------------------------------------------------------------------
//
void InvalidateVisual( VisualPluginData * visualPluginData )
{
	(void) visualPluginData;

#if USE_SUBVIEW
	// when using a custom subview, we invalidate it so we get our own draw calls
	[visualPluginData->subview setNeedsDisplay:YES];
#endif
}

//-------------------------------------------------------------------------------------------------
//	CreateVisualContext
//-------------------------------------------------------------------------------------------------
//
OSStatus ActivateVisual( VisualPluginData * visualPluginData, VISUAL_PLATFORM_VIEW destView, OptionBits options )
{
	OSStatus			status = noErr;

	visualPluginData->destView			= destView;
	visualPluginData->destRect			= [destView bounds];
	visualPluginData->destOptions		= options;

	UpdateInfoTimeOut( visualPluginData );

#if USE_SUBVIEW

	// NSView-based subview
	visualPluginData->subview = [[VisualView alloc] initWithFrame:visualPluginData->destRect];
	if ( visualPluginData->subview != NULL )
	{
		[visualPluginData->subview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

		[visualPluginData->subview setVisualPluginData:visualPluginData];

		[destView addSubview:visualPluginData->subview];
	}
	else
	{
		status = memFullErr;
	}

#endif
    
	return status;
}

//-------------------------------------------------------------------------------------------------
//	MoveVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus MoveVisual( VisualPluginData * visualPluginData, OptionBits newOptions )
{
	visualPluginData->destRect	  = [visualPluginData->destView bounds];
	visualPluginData->destOptions = newOptions;

	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	DeactivateVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus DeactivateVisual( VisualPluginData * visualPluginData )
{
#if USE_SUBVIEW
	[visualPluginData->subview removeFromSuperview];
	[visualPluginData->subview autorelease];
	visualPluginData->subview = NULL;
	[visualPluginData->currentArtwork release];
	visualPluginData->currentArtwork = NULL;
#endif

	visualPluginData->destView			= NULL;
	visualPluginData->destRect			= CGRectNull;
	visualPluginData->drawInfoTimeOut	= 0;
    
    if (visualPluginData->pm != NULL) {
        delete(visualPluginData->pm);
        visualPluginData->pm = NULL;
    }
	
	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	ResizeVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus ResizeVisual( VisualPluginData * visualPluginData )
{
	visualPluginData->destRect = [visualPluginData->destView bounds];

    if (visualPluginData->pm != NULL) {
        visualPluginData->pm->projectM_resetGL(visualPluginData->destRect.size.width, visualPluginData->destRect.size.height);
    }

	return noErr;
}

//-------------------------------------------------------------------------------------------------
//	ConfigureVisual
//-------------------------------------------------------------------------------------------------
//
OSStatus ConfigureVisual( VisualPluginData * visualPluginData )
{
	(void) visualPluginData;

	// load nib
	// show modal dialog
	// update settings
	// invalidate

	return noErr;
}

#pragma mark -

#if USE_SUBVIEW

@implementation VisualView

@synthesize visualPluginData = _visualPluginData;

//-------------------------------------------------------------------------------------------------
//	isOpaque
//-------------------------------------------------------------------------------------------------
//
- (BOOL)isOpaque
{
	// your custom views should always be opaque or iTunes will waste CPU time drawing behind you
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	drawRect
//-------------------------------------------------------------------------------------------------
//
-(void)drawRect:(NSRect)dirtyRect
{
	if ( _visualPluginData != NULL )
	{
		DrawVisual( _visualPluginData );
	}
}

//-------------------------------------------------------------------------------------------------
//	acceptsFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)acceptsFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	becomeFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)becomeFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	resignFirstResponder
//-------------------------------------------------------------------------------------------------
//
- (BOOL)resignFirstResponder
{
	return YES;
}

//-------------------------------------------------------------------------------------------------
//	keyDown
//-------------------------------------------------------------------------------------------------
//
-(void)keyDown:(NSEvent *)theEvent
{
	// Handle key events here.
	// Do not eat the space bar, ESC key, TAB key, or the arrow keys: iTunes reserves those keys.

	// if the 'i' key is pressed, reset the info timeout so that we draw it again
	if ( [[theEvent charactersIgnoringModifiers] isEqualTo:@"i"] )
	{
		UpdateInfoTimeOut( _visualPluginData );
		return;
	}

	// Pass all unhandled events up to super so that iTunes can handle them.
	[super keyDown:theEvent];
}

@end

#endif	// USE_SUBVIEW

#pragma mark -

//-------------------------------------------------------------------------------------------------
//	GetVisualName
//-------------------------------------------------------------------------------------------------
//
void GetVisualName( ITUniStr255 name )
{
	CFIndex length = CFStringGetLength( kTVisualPluginName );

	name[0] = (UniChar)length;
	CFStringGetCharacters( kTVisualPluginName, CFRangeMake( 0, length ), &name[1] );
}

//-------------------------------------------------------------------------------------------------
//	GetVisualOptions
//-------------------------------------------------------------------------------------------------
//
OptionBits GetVisualOptions( void )
{
	OptionBits		options = (kVisualSupportsMuxedGraphics | kVisualWantsIdleMessages);
	
#if USE_SUBVIEW
	options |= kVisualUsesSubview;
#endif

	return options;
}

//-------------------------------------------------------------------------------------------------
//	iTunesPluginMainMachO
//-------------------------------------------------------------------------------------------------
//
OSStatus iTunesPluginMainMachO( OSType message, PluginMessageInfo * messageInfo, void * refCon )
{
	OSStatus		status;
	
	(void) refCon;
	
	switch ( message )
	{
		case kPluginInitMessage:
			status = RegisterVisualPlugin( messageInfo );
			break;
			
		case kPluginCleanupMessage:
			status = noErr;
			break;
			
		default:
			status = unimpErr;
			break;
	}
	
	return status;
}