//
//  VideoFrameLoader.m
//  Annotation
//
//  Created by Adam Fouse on 7/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "VideoFrameLoader.h"
#import "TimelineMarker.h"
#import "TimelineView.h"
#import "SegmentVisualizer.h"
#import "CGImageWrapper.h"
#import "AppController.h"
#import "ImageSequenceView.h"
#import "VideoProperties.h"
#import <QTKit/QTKit.h>

// =================================
// = Interface for hidden methods
// =================================
@interface VideoFrameLoader (hidden)

- (void)loadMarkerCIImage:(id)data;
- (void)loadImages:(NSTimer*)theTimer;

@end

// =====================================
// = Implementation of hidden methods
// =====================================
@implementation VideoFrameLoader (hidden)

// This is the method that does the actual work of the task.
- (void)loadImages:(NSTimer*)theTimer
{
	if([array count] > 0)
	{
		[self loadMarkerCIImage:[array objectAtIndex:0]];
		[array removeObjectAtIndex:0];
	}
	else
	{
		[timer invalidate];
		timer = nil;
	}
}

- (void)loadMarkerCIImage:(id)data
{
	TimelineMarker *marker = (TimelineMarker*)data;
	if([marker visualizer]) // && ([[marker timeline] movie] == [[AppController currentApp] movie]))
	{
		BOOL exact = NO;
		
		QTMovie *playbackMovie = [[marker visualizer] movie];
		NSURL *url = [[playbackMovie movieAttributes] objectForKey:QTMovieURLAttribute];
		
		QTTime time = [[marker boundary] time];
		NSTimeInterval timeInterval;
		QTGetTimeInterval(time, &timeInterval);
		
		NSString *identifier;
		if(exact)
		{
			identifier = [NSString stringWithFormat:@"%p-%f-cg",[[marker visualizer] movie],timeInterval];
		}
		else
		{
			float interval = [[movieIntervals objectForKey:url] floatValue];
			int bin = floor(timeInterval/interval);
			identifier = [NSString stringWithFormat:@"%p-%i-cg",[[marker visualizer] movie],bin];	
		}
		
		CGImageWrapper *imageWrap = [imagecache objectForKey:identifier];
		if(!imageWrap)
		{
			CGImageRef theImage;
			if([[[marker visualizer] videoProperties] localVideo] && [[[AppController currentApp] mainView] isKindOfClass:[ImageSequenceView class]])
			{
				ImageSequenceView* images = (ImageSequenceView*)[[AppController currentApp] mainView];
				theImage = [images cgImageAtTime:time];
			}
			else
			{
				QTMovie *frameVideo = video;
				NSDictionary *frameDict = CIImageDict;
				if(!frameVideo)
				{
					
					frameVideo = [frameMovies objectForKey:url];
					frameDict = [frameSettings objectForKey:url];
					
					if(!frameVideo)
					{
						NSError *error = nil;
						frameVideo = [QTMovie movieWithURL:url error:&error];
						[frameMovies setObject:frameVideo forKey:url];
						
						NSTimeInterval duration;
						QTGetTimeInterval([frameVideo duration], &duration);
						float interval = duration/targetFrameCount;
						
						[movieIntervals setObject:[NSNumber numberWithFloat:interval] forKey:url];
						
						NSSize contentSize = [[frameVideo attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
						float ratio = contentSize.width/contentSize.height;
						contentSize.width = (targetHeight *  ratio);
						contentSize.height = targetHeight;
						
						frameDict = [NSDictionary
									 dictionaryWithObjectsAndKeys:
									 QTMovieFrameImageTypeCGImageRef,QTMovieFrameImageType,
									 [NSValue valueWithSize:contentSize],QTMovieFrameImageSize,
									 nil];
						[frameSettings setObject:frameDict forKey:url];
						
					}
				}
				
				QTTime offset = ([[marker visualizer] videoProperties]) ? [[[marker visualizer] videoProperties] offset] : QTMakeTimeWithTimeInterval(0);
				//NSLog(@"Offset: %i",(int)offset.timeValue);
				theImage = (CGImageRef)[frameVideo frameImageAtTime:QTTimeIncrement([[marker boundary] time],offset)
																			   withAttributes:frameDict error:NULL];
			}
			imageWrap = [[CGImageWrapper alloc] initWithImage:theImage];
			[imagecache setObject:imageWrap forKey:identifier];
			[imageWrap release];
		}
		//[[marker layer] setNeedsDisplay];
		//[[marker layer] setContents:[imageWrap image]];
		[marker setImage:[imageWrap image]];
		[marker setDate:[NSDate date]];
		[[marker layer] setNeedsDisplay];
	}
	else
	{
		//NSLog(@"Bad frame load");
	}
}


@end


@implementation VideoFrameLoader

- (id) init
{
	self = [super init];
	if (self != nil) {
		timer = nil;
		video = nil;
		array = [[NSMutableArray alloc] init];
		//queue = [[NSOperationQueue alloc] init];
		//[queue setMaxConcurrentOperationCount:1];
		imagecache = [[NSMutableDictionary alloc] init];
		frameMovies = [[NSMutableDictionary alloc] init];
		movieIntervals = [[NSMutableDictionary alloc] init];
		frameSettings = [[NSMutableDictionary alloc] init];
		targetFrameCount = 200;
		targetHeight = 200;
		
		CIImageDict = [[NSDictionary
								   dictionaryWithObjectsAndKeys:
								   QTMovieFrameImageTypeCGImageRef,QTMovieFrameImageType,
								   nil] retain];
		

	}
	return self;
}

- (void) dealloc
{
	[video release];
	[queue release];
	[CIImageDict release];
	
	[imagecache release];
	[frameMovies release];
	[movieIntervals release];
	[frameSettings release];
	
	[super dealloc];
}

- (void)loadCIImage:(TimelineMarker*)marker immediately:(BOOL)now
{
//   NSInvocationOperation* theOp = [[NSInvocationOperation alloc] initWithTarget:self
//																		selector:@selector(loadMarkerCIImage:) object:marker];
//	[queue addOperation:theOp];
//	[theOp release];
	
	if(now)
	{
		[self loadMarkerCIImage:marker];
	}
	else
	{	
		[array addObject:marker];
		if(!timer)
		{
			[NSTimer scheduledTimerWithTimeInterval:0.001
													 target:self
												   selector:@selector(loadImages:)
												   userInfo:nil
													repeats:NO];
		}
	}
}

- (void)setVideo:(QTMovie*)theVideo
{
	[theVideo retain];
	[video release];
	video = theVideo;
}

- (void)loadAllFramesForMovie:(QTMovie*)movie
{
	QTMovie *playbackMovie = movie;
	NSURL *url = [[playbackMovie movieAttributes] objectForKey:QTMovieURLAttribute];
	
	QTMovie *frameVideo = [frameMovies objectForKey:url];
	NSDictionary *frameDict = [frameSettings objectForKey:url];

	NSTimeInterval duration;
	QTGetTimeInterval([movie duration], &duration);
	
	if(!frameVideo)
	{
		NSError *error = nil;
		frameVideo = [QTMovie movieWithURL:url error:&error];
		[frameMovies setObject:frameVideo forKey:url];

		float interval = duration/targetFrameCount;
		
		[movieIntervals setObject:[NSNumber numberWithFloat:interval] forKey:url];
		
		NSSize contentSize = [[frameVideo attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
		float ratio = contentSize.width/contentSize.height;
		contentSize.width = (targetHeight *  ratio);
		contentSize.height = targetHeight;
		
		frameDict = [NSDictionary
					 dictionaryWithObjectsAndKeys:
					 QTMovieFrameImageTypeCGImageRef,QTMovieFrameImageType,
					 [NSValue valueWithSize:contentSize],QTMovieFrameImageSize,
					 nil];
		[frameSettings setObject:frameDict forKey:url];
		
	}
	
	NSMutableDictionary *betterFrameDict = [NSMutableDictionary dictionaryWithDictionary:frameDict];
	
	SInt32 major = 0;
	SInt32 minor = 0;   
	Gestalt(gestaltSystemVersionMajor, &major);
	Gestalt(gestaltSystemVersionMinor, &minor);
	BOOL tensix = NO;
	if ((major == 10 && minor >= 6) || major >= 11) {
		tensix = YES;
		[betterFrameDict setObject:[NSNumber numberWithBool:YES] forKey:@"QTMovieFrameImageSessionMode"];
	}
	
	float interval = [[movieIntervals objectForKey:url] floatValue];
	
	NSTimeInterval time;
	for(time = 0; time < duration; time += interval)
	{
		int bin = floor(time/interval);
		if((bin % 10) == 0)
		{
			NSLog(@"Loading frame %i",bin);
		}
		NSString *identifier = [NSString stringWithFormat:@"%p-%i-cg",movie,bin];
		CGImageWrapper *imageWrap = [imagecache objectForKey:identifier];
		if(!imageWrap)
		{
			CGImageRef theImage = (CGImageRef)[frameVideo frameImageAtTime:QTMakeTimeWithTimeInterval(time)
													 withAttributes:betterFrameDict error:NULL];

			imageWrap = [[CGImageWrapper alloc] initWithImage:theImage];
			[imagecache setObject:imageWrap forKey:identifier];
			[imageWrap release];
		}	
	}
	
	if(tensix)
	{
		[betterFrameDict setObject:[NSNumber numberWithBool:NO] forKey:@"QTMovieFrameImageSessionMode"];
		[frameVideo frameImageAtTime:QTMakeTimeWithTimeInterval(time) withAttributes:betterFrameDict error:NULL];
		//CGImageRelease(theImage);
	}
	

}


@end
