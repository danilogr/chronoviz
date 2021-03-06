//
//  OverviewTimelineView.h
//  DataPrism
//
//  Created by Adam Fouse on 3/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TimelineView.h"

@interface OverviewTimelineView : TimelineView <NSAnimationDelegate> {

	QTTimeRange selection;
	
	IBOutlet TimelineView *detailTimeline;
	
	CALayer* selectionLayer;
	NSTrackingArea *selectionTrackingArea;
	
	CGColorRef selectionColor;
	
	NSCursor *selectionCursor;
	BOOL overSelection;
	BOOL resizeSelectionLeft;
	BOOL resizeSelectionRight;
	
	BOOL makingSelection;
	
	BOOL dragging;
	
	QTTime clickTime;
	QTTime offset;
	
	CGFloat resizeMargin;
	
	CGFloat minSelectionWidth;
	CGFloat selectionStartX;
	CGFloat selectionEndX;
	
}

-(QTTimeRange)selection;
-(void)setSelection:(QTTimeRange)theSelection;
-(void)setSelection:(QTTimeRange)theSelection animate:(BOOL)animateChange;

-(void)updateSelectionCursor:(NSEvent*)theEvent;

@end
