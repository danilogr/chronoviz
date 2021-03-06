//
//  TimeCodedData.h
//  DataPrism
//
//  Created by Adam Fouse on 3/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>
@class DataSource;

@interface TimeCodedData : NSObject <NSCoding> {

	NSString *uuid;
	NSString *name;
	NSString *variableName;
	DataSource *source;
	NSColor *color;
	
	QTTimeRange range;
}

@property(readonly) NSString* uuid;
@property(copy) NSString* name;
@property(copy) NSString* variableName;
@property(retain) NSColor* color;
@property(assign) DataSource* source;

- (QTTimeRange)range;
- (QTTime)startTime;
- (QTTime)endTime;

- (NSTimeInterval)startSeconds;

- (NSString*)displayName;

@end
