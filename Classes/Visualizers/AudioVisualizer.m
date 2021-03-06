//
//  AudioVisualizer.m
//  Annotation
//
//  Created by Adam Fouse on 12/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AudioVisualizer.h"
#import "VideoProperties.h"
#import "AppController.h"
#import "AnnotationDocument.h"
#import "AudioExtractor.h"

@implementation AudioVisualizer

-(id)initWithTimelineView:(TimelineView*)timelineView
{
	self = [super initWithTimelineView:timelineView];
	if(self)
	{
        graph = NULL;
		subset = nil;
		graphLayer = nil;
		resampleTimer = nil;
		stopTimer = YES;
		subsetTargetSize = 1000;
	}
	return self;
}

- (void)dealloc
{
	if(loadTimer)
	{
		[self retain];
		[loadTimer invalidate];
		loadTimer = nil;
	}
	[videoProperties removeObserver:self forKeyPath:@"offset"];
	[markers removeAllObjects];
	[graphLayer removeFromSuperlayer];
	[graphLayer release];
	
	[subset release];
	subset = nil;
	
	[audioExtractor cancelExtraction:self];
	[audioExtractor release];
	audioExtractor = nil;
	
	CGPathRelease(graph);
    graph = NULL;
	[super dealloc];
}

-(void)reset
{
	NSLog(@"Audio visualizer reset");
	
	if(loadTimer)
	{
		[self retain];
		[loadTimer invalidate];
		loadTimer = nil;
	}
	[videoProperties removeObserver:self forKeyPath:@"offset"];
	[graphLayer removeFromSuperlayer];
	[graphLayer release];
	graphLayer = nil;
	
	if(audioExtractor)
	{
		[audioExtractor setDelegate:nil];
		[audioExtractor cancelExtraction:self];
		[audioExtractor release];
		audioExtractor = nil;
	}
	
	[subset release];
	subset = nil;
	
	CGPathRelease(graph);
	graph = NULL;
	[super reset];
}

-(void)setup
{
	if(!graphLayer)
	{
		[self createGraph];
		[videoProperties addObserver:self forKeyPath:@"offset" options:0 context:NULL];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ((object == videoProperties) && [keyPath isEqual:@"offset"])
	{
		[self createGraph];
    }
	else
	{
		[super observeValueForKeyPath:keyPath
							 ofObject:object
							   change:change
							  context:context];
	}
}

-(TimelineMarker *)addKeyframe:(SegmentBoundary*)keyframe
{
	[self setup];
	return nil;
}

-(void)loadData
{
	NSLog(@"audio load data");
	resampleTimer = nil;
	[subset release];
	subset = nil;
	
	QTTimeRange movieRange = QTMakeTimeRange(QTZeroTime, [[self movie] duration]);
	if([[self videoProperties] audioSubset] && QTEqualTimeRanges([timeline range], movieRange))
	{
		subset = [[videoProperties audioSubset] mutableCopy];
		subsetRange = QTMakeTimeRange(QTZeroTime, [[self movie] duration]);
		fullsubset = subset;
	}
	else
	{
		QTMovie* movie = [self movie];
		
//			if(audioExtractor)
//			{
//				[audioExtractor cancelExtraction:self];
//				[audioExtractor release];
//			}
		
		if(!audioExtractor)
		{
			audioExtractor = [[AudioExtractor alloc] initWithQTMovie:movie];
			[audioExtractor setDelegate:self];
		}
		else
		{
			[audioExtractor cancelExtraction:self];
		}

		
		subsetRange = QTIntersectionTimeRange([timeline range], movieRange );
		[audioExtractor exportAudioSubset:subsetTargetSize forRange:subsetRange];
		
		[subset release];
		subset = [[NSMutableArray alloc] initWithCapacity:subsetTargetSize];
		//subset = [[audioExtractor subsetArray] retain];
		//subsetRange = [timeline range];
		
		if(stopTimer || !loadTimer)
		{
			[videoProperties setAudioSubset:subset];
			[[AppController currentDoc] saveVideoProperties:videoProperties];
		}
		
//			subset = [[[self movie] getAudioSubset:1000 withCallback:self] retain];
//			[videoProperties setAudioSubset:subset];
//			[[AppController currentDoc] saveVideoProperties:videoProperties];
		
		//[audioExtractor release];
	}

	[self createGraph];
}

//- (void)setData:(NSArray*)array
//{
//	[array retain];
//	[subset release];
//	subset = array;
//	
//	[self createGraph];
//	
//}

-(void)createGraph
{
	if(!subset)
	{
		[self loadData];
	} 
	
	QTTimeRange dataRange = subsetRange;
	NSArray *data = subset;
	
	if(audioExtractor)
	{
		NSArray *extractorArray = [audioExtractor subsetArray];
		if([extractorArray count] > [subset count])
		{
			NSIndexSet *newData = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([subset count], [extractorArray count] - [subset count])];
			[subset addObjectsFromArray:[extractorArray objectsAtIndexes:newData]];
		}
	}
	
	if((fullsubset && [timeline inLiveResize] &&
	   !QTEqualTimeRanges(QTUnionTimeRange([timeline range],subsetRange),subsetRange))
	   || (([subset count] == 0) && fullsubset))
	{
		dataRange = QTMakeTimeRange(QTZeroTime, [[self movie] duration]);
		data = fullsubset;
	}
	
    if([data count] == 0)
    {
        //NSLog(@"Zero points");
        if(graph)
        {
            CGPathRelease(graph);
            graph = NULL;
        }
        return;
    }
    
	QTTimeRange timelineRange = [timeline range];
	graphRange = timelineRange;
	//QTTime audioDuration = [[self movie] duration];
	QTTime audioDuration = dataRange.duration;
	
	CGFloat subsetSize = [data count];
	if(!stopTimer && loadTimer && (data != fullsubset))
	{
		subsetSize = subsetTargetSize;
	}
	
	//NSLog(@"subset size: %f",subsetSize);
	
	CGFloat pointTimeInterval = ((CGFloat)audioDuration.timeValue/(CGFloat)audioDuration.timeScale)/subsetSize;
	CGFloat rangeStartTimeInterval = (CGFloat)timelineRange.time.timeValue/(CGFloat)timelineRange.time.timeScale;
	CGFloat rangeDurationTimeInterval = (CGFloat)timelineRange.duration.timeValue/(CGFloat)timelineRange.duration.timeScale;
	//CGFloat offsetTimeInterval = 0;
	NSTimeInterval offsetTimeInterval;
	QTGetTimeInterval(dataRange.time, &offsetTimeInterval);
	if(videoProperties && ([videoProperties offset].timeValue != 0))
	{
		offsetTimeInterval -= (CGFloat)[videoProperties offset].timeValue/(CGFloat)[videoProperties offset].timeScale;
	}
	
	CGFloat movieTimeToPixel = [timeline bounds].size.width/rangeDurationTimeInterval;

	//float pointToPixel = [timeline bounds].size.width/(float)[subset count];
	
	// The following code is adapted from 
	// http://www.supermegaultragroovy.com/blog/2009/10/06/drawing-waveforms/
	
	
	
	CGMutablePathRef halfPath = CGPathCreateMutable();
	CGPathMoveToPoint(halfPath, NULL, 0, 0);
	
	CGFloat startx = (offsetTimeInterval - rangeStartTimeInterval) * movieTimeToPixel;
	
	CGPathAddLineToPoint(halfPath, NULL, startx, 0);
	
	float i = 1;
	for(NSNumber* value in data)
	{
		NSTimeInterval pointTime = offsetTimeInterval + (i*pointTimeInterval);
		
		CGFloat x = (pointTime - rangeStartTimeInterval) * movieTimeToPixel;
		
		CGPathAddLineToPoint(halfPath, NULL, x, [value floatValue]);
		i++;
	}
	
	NSTimeInterval pointTime = offsetTimeInterval + (i*pointTimeInterval);	
	CGFloat x = (pointTime - rangeStartTimeInterval) * movieTimeToPixel;
	CGPathAddLineToPoint(halfPath, NULL, x, 0);
	
	// Build the destination path
	CGMutablePathRef newGraph = CGPathCreateMutable();
	
	// Transform to fit the waveform ([0,1] range) into the vertical space
	// ([halfHeight,height] range)
	double halfHeight = floor( NSHeight( timeline.bounds ) / 2.0 );
	CGAffineTransform xf = CGAffineTransformIdentity;
	xf = CGAffineTransformTranslate( xf, 0.0, halfHeight );
	xf = CGAffineTransformScale( xf, 1.0, halfHeight );
	
	// Add the transformed path to the destination path
	CGPathAddPath( newGraph, &xf, halfPath );
	CGPathAddLineToPoint(newGraph, NULL, [timeline bounds].size.width, halfHeight);
	CGPathCloseSubpath(newGraph);
	
	// Transform to fit the waveform ([0,1] range) into the vertical space
	// ([0,halfHeight] range), flipping the Y axis
	xf = CGAffineTransformIdentity;
	xf = CGAffineTransformTranslate( xf, 0.0, halfHeight );
	xf = CGAffineTransformScale( xf, 1.0, -halfHeight );
	
	// Add the transformed path to the destination path
	CGPathAddPath( newGraph, &xf, halfPath );
	CGPathAddLineToPoint(newGraph, NULL, [timeline bounds].size.width, halfHeight);
	CGPathCloseSubpath(newGraph);
	
	
	CGPathRelease( halfPath ); // clean up!
    
    CGMutablePathRef tempGraph = graph;
    graph = newGraph;
    CGPathRelease(tempGraph);
	
	// Now, path contains the full waveform path.
	
    if(![timeline label] || [[timeline label] length] == 0)
    {
        NSString *title = [videoProperties title];
		
		if(!title)
		{
			title = @"Audio";
		}
        else
        {
            title = [@"Audio: " stringByAppendingString:title];
        }
		
        [timeline setLabel:title];
    }
    
//	if(!labelLayer)
//	{
//		labelLayer = [[CALayer layer] retain];
//		[labelLayer setAnchorPoint:CGPointMake(1.0,0.0)];
//		[labelLayer setFrame:NSRectToCGRect([timeline bounds])];
//		[labelLayer setAutoresizingMask:kCALayerMinXMargin];
//		[labelLayer setDelegate:self];
//		[[timeline visualizationLayer] addSublayer:labelLayer];
//		[labelLayer setNeedsDisplay];
//	}
	
	if(!graphLayer)
	{
//		[graphLayer removeFromSuperlayer];
//		[graphLayer release];
		graphLayer = [[CALayer layer] retain];
		[graphLayer setAnchorPoint:CGPointMake(0.0, 0.0)];
		//[graphLayer setFrame:NSRectToCGRect([timeline bounds])];
		[graphLayer setDelegate:self];
		[graphLayer setShadowOpacity:0.5];
		[[timeline visualizationLayer] addSublayer:graphLayer];
	}
	[graphLayer setFrame:NSRectToCGRect([timeline bounds])];
	[graphLayer setNeedsDisplay];

	if(stopTimer)
	{
		if(loadTimer)
		{
			[self retain];
			[loadTimer invalidate];
			loadTimer = nil;
		}
		stopTimer = NO;
	}
}


-(BOOL)updateMarkers
{
	if([timeline inLiveResize] && QTEqualTimeRanges([timeline range], graphRange))
	{
		graphLayer.bounds = NSRectToCGRect([timeline bounds]);
	}
	else
	{
		if(![timeline inLiveResize] && !QTEqualTimeRanges([timeline range], subsetRange))
		{
			//return NO;
			
			if(loadTimer)
			{
				[self retain];
				[loadTimer invalidate];
				loadTimer = nil;
			}
			
			if(audioExtractor)
			{
				[audioExtractor cancelExtraction:self];
			}			
			
			if(resampleTimer)
			{
				[resampleTimer invalidate];
			}
			
			resampleTimer = [NSTimer scheduledTimerWithTimeInterval:1 
														 target:self 
													   selector:@selector(loadData) 
													   userInfo:nil 
														repeats:NO];
//			
//			
//			[subset release];
//			subset = nil;
		}
//		[graphLayer removeFromSuperlayer];
//		[graphLayer release];
//		graphLayer = nil;
		[self createGraph];
	}
	return YES;
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    // Draw graph that has already been created
    if(graph)
    {
		CGContextBeginPath(ctx);
		CGContextAddPath(ctx, graph );
        CGContextClosePath(ctx);
		CGContextSetRGBStrokeColor(ctx, 0.8f, 0.8f, 0.8f, 1.0f);
		CGContextSetRGBFillColor(ctx, 0.8f, 0.8f, 0.8f, 1.0f);
		CGContextSetLineWidth(ctx, 1.0f);
		CGContextDrawPath(ctx, kCGPathFillStroke);
		//	CGContextStrokePath(ctx);
		//	CGContextFillPath(ctx);
    }
    
    // Create graph during drawing
    if(NO)
    {
    
        QTTimeRange dataRange = subsetRange;
        NSArray *data = subset;
        
        if(audioExtractor)
        {
            NSArray *extractorArray = [audioExtractor subsetArray];
            if([extractorArray count] > [subset count])
            {
                NSIndexSet *newData = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([subset count], [extractorArray count] - [subset count])];
                [subset addObjectsFromArray:[extractorArray objectsAtIndexes:newData]];
            }
        }
        
        if((fullsubset && [timeline inLiveResize] &&
            !QTEqualTimeRanges(QTUnionTimeRange([timeline range],subsetRange),subsetRange))
           || (([subset count] == 0) && fullsubset))
        {
            dataRange = QTMakeTimeRange(QTZeroTime, [[self movie] duration]);
            data = fullsubset;
        }
        
        if([data count] == 0)
        {
            NSLog(@"Zero points");
            return;
        }
        
        QTTimeRange timelineRange = [timeline range];
        graphRange = timelineRange;
        //QTTime audioDuration = [[self movie] duration];
        QTTime audioDuration = dataRange.duration;
        
        CGFloat subsetSize = [data count];
        if(!stopTimer && loadTimer && (data != fullsubset))
        {
            subsetSize = subsetTargetSize;
        }
        
        //NSLog(@"subset size: %f",subsetSize);
        
        CGFloat pointTimeInterval = ((CGFloat)audioDuration.timeValue/(CGFloat)audioDuration.timeScale)/subsetSize;
        CGFloat rangeStartTimeInterval = (CGFloat)timelineRange.time.timeValue/(CGFloat)timelineRange.time.timeScale;
        CGFloat rangeDurationTimeInterval = (CGFloat)timelineRange.duration.timeValue/(CGFloat)timelineRange.duration.timeScale;
        //CGFloat offsetTimeInterval = 0;
        NSTimeInterval offsetTimeInterval;
        QTGetTimeInterval(dataRange.time, &offsetTimeInterval);
        if(videoProperties && ([videoProperties offset].timeValue != 0))
        {
            offsetTimeInterval -= (CGFloat)[videoProperties offset].timeValue/(CGFloat)[videoProperties offset].timeScale;
        }
        
        CGFloat movieTimeToPixel = [timeline bounds].size.width/rangeDurationTimeInterval;
        
        //float pointToPixel = [timeline bounds].size.width/(float)[subset count];
        
        // The following code is adapted from
        // http://www.supermegaultragroovy.com/blog/2009/10/06/drawing-waveforms/
        
        
        
        CGMutablePathRef halfPath = CGPathCreateMutable();
        CGPathMoveToPoint(halfPath, NULL, 0, 0);
        
        CGFloat startx = (offsetTimeInterval - rangeStartTimeInterval) * movieTimeToPixel;
        
        CGPathAddLineToPoint(halfPath, NULL, startx, 0);
        
        float i = 1;
        double xMax = 0;
        double xMin = 10000;
        for(NSNumber* value in data)
        {
            NSTimeInterval pointTime = offsetTimeInterval + (i*pointTimeInterval);
            
            CGFloat x = (pointTime - rangeStartTimeInterval) * movieTimeToPixel;
            
            xMax = fmax(x,xMax);
            xMin = fmin(x,xMin);
            
            CGPathAddLineToPoint(halfPath, NULL, x, [value floatValue]);
            i++;
        }
        
        NSLog(@"max %f min %f",xMax,xMin);
        
        NSTimeInterval pointTime = offsetTimeInterval + (i*pointTimeInterval);
        CGFloat x = (pointTime - rangeStartTimeInterval) * movieTimeToPixel;
        CGPathAddLineToPoint(halfPath, NULL, x, 0);
        
        
        CGMutablePathRef newGraph = CGPathCreateMutable();

        
        
        // Transform to fit the waveform ([0,1] range) into the vertical space
        // ([halfHeight,height] range)
        double halfHeight = floor( layer.bounds.size.height / 2.0 );
        CGAffineTransform xf = CGAffineTransformIdentity;
        xf = CGAffineTransformTranslate( xf, 0.0, halfHeight );
        xf = CGAffineTransformScale( xf, 1.0, halfHeight );
        
        // Add the transformed path to the destination path
        CGPathAddPath( newGraph, &xf, halfPath );
        CGPathAddLineToPoint(newGraph, NULL, [layer bounds].size.width, halfHeight);
        CGPathCloseSubpath(newGraph);
        
        // Transform to fit the waveform ([0,1] range) into the vertical space
        // ([0,halfHeight] range), flipping the Y axis
        xf = CGAffineTransformIdentity;
        xf = CGAffineTransformTranslate( xf, 0.0, halfHeight );
        xf = CGAffineTransformScale( xf, 1.0, -halfHeight );
        
        // Add the transformed path to the destination path
        CGPathAddPath( newGraph, &xf, halfPath );
        CGPathAddLineToPoint(newGraph, NULL, [layer bounds].size.width, halfHeight);
        CGPathCloseSubpath(newGraph);
        
        CGContextBeginPath(ctx);
        CGContextAddPath(ctx, newGraph );
        CGContextClosePath(ctx);
        CGContextSetRGBStrokeColor(ctx, 0.8f, 0.8f, 0.8f, 1.0f);
        CGContextSetRGBFillColor(ctx, 0.8f, 0.8f, 0.8f, 1.0f);
        CGContextSetLineWidth(ctx, 1.0f);
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        CGPathRelease( halfPath ); // clean up!
        CGPathRelease( newGraph );
    //    CGMutablePathRef tempGraph = graph;
    //    graph = newGraph;
    //    CGPathRelease(tempGraph);

    }
    
    
    
//	}

}

#pragma mark Data Source Delegate Methods

-(void)dataSourceLoadStart
{
	stopTimer = NO;
	loadTimer = [NSTimer scheduledTimerWithTimeInterval:1 
										target:self 
									  selector:@selector(createGraph) 
									  userInfo:nil 
									   repeats:YES];
	[self release];
}

-(void)dataSourceLoadStatus:(CGFloat)percentage
{
//	if([[NSDate date] timeIntervalSinceDate:lastGraphUpdate] > 1)
//		[self createGraph];
	
}

-(void)dataSourceLoadFinished
{
	stopTimer = YES;
	
	[subset release];
	subset = [[audioExtractor subsetArray] mutableCopy];
	
	[audioExtractor release];
	audioExtractor = nil;
	
	if(![videoProperties audioSubset] && QTEqualTimeRanges(subsetRange, QTMakeTimeRange(QTZeroTime, [[self movie] duration])))
	{
		[videoProperties setAudioSubset:subset];
		[[AppController currentDoc] saveVideoProperties:videoProperties];
		fullsubset = subset;
	}
	
}

-(BOOL)dataSourceCancelLoad
{
	return NO;
}


@end
