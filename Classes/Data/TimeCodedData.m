//
//  TimeCodedData.m
//  DataPrism
//
//  Created by Adam Fouse on 3/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "TimeCodedData.h"
#import "DataSource.h"
#import "NSStringUUID.h"

@implementation TimeCodedData

@synthesize uuid;
@synthesize name;
@synthesize variableName;
@synthesize source;
@synthesize color;

- (id) init
{
	self = [super init];
	if (self != nil) {
		range = QTMakeTimeRange(QTMakeTime(0,600), QTMakeTime(0,600));
		[self setColor:[NSColor blueColor]];
		uuid = [[NSString stringWithUUID] retain];
	}
	return self;
}


- (void) dealloc
{
	[uuid release];
	[name release];
	[variableName release];
	[super dealloc];
}

- (QTTimeRange)range
{
	return range;
}

- (QTTime)startTime
{
	return [self range].time;
}

- (QTTime)endTime
{
	return QTTimeRangeEnd([self range]);
}

- (NSTimeInterval)startSeconds
{
    NSTimeInterval seconds;
    QTGetTimeInterval([self startTime], &seconds);
    return seconds;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:uuid forKey:@"AnnotationDataSetUUID"];
	[coder encodeObject:name forKey:@"AnnotationDataSetName"];
	[coder encodeObject:variableName forKey:@"AnnotationDataSetVariableName"];
	[coder encodeQTTimeRange:range forKey:@"AnnotationDataSetRange"];
	[coder encodeObject:color forKey:@"AnnotationDataSetColor"];
}

- (id)initWithCoder:(NSCoder *)coder {
    if(self = [super init])
	{
		uuid = [[coder decodeObjectForKey:@"AnnotationDataSetUUID"] retain];
		if(!uuid)
		{
			uuid = [[NSString stringWithUUID] retain];
		}
		
		self.name = [coder decodeObjectForKey:@"AnnotationDataSetName"];
		self.variableName = [coder decodeObjectForKey:@"AnnotationDataSetVariableName"];
		range = [coder decodeQTTimeRangeForKey:@"AnnotationDataSetRange"];
		[self setColor:[coder decodeObjectForKey:@"AnnotationDataSetColor"]];
		if(!color)
		{
			[self setColor:[NSColor blueColor]];
		}
		
	}
    return self;
}

- (NSString*)displayName
{
    return self.name;
}


@end
