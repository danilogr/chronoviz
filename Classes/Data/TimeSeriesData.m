//
//  TimeSeriesData.m
//  Annotation
//
//  Created by Adam Fouse on 8/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TimeSeriesData.h"
#import "TimeCodedDataPoint.h"
#import "NSStringParsing.h"
#import "DataSource.h"

int afTimeCodedPointSort( id obj1, id obj2, void *context ) {
	
	TimeCodedDataPoint *point1 = (TimeCodedDataPoint*)obj1;
	TimeCodedDataPoint *point2 = (TimeCodedDataPoint*)obj2;
	
	return QTTimeCompare([point1 time], [point2 time]);
}


@implementation TimeSeriesData


-(id)init
{
	return [self initWithDataPointArray:nil];
}

// Initialize with an array of TimeCodedDataPoints
-(id)initWithDataPointArray:(NSArray*)data
{
	self = [super init];
	if (self != nil) {
		[self setColor:[NSColor greenColor]];
		
        intervalMode = -1;
        
		if((data == nil) || ([data count] == 0))
		{
			source = nil;
			dataPoints = [[NSMutableArray alloc] init];
			range = QTTimeRangeFromString(@"0:0:0:0.0/600~0:0:0:0.0/600");
			maxValue = -DBL_MAX;
			minValue = DBL_MAX;
			mean = 0;
		}
		else if ([[data objectAtIndex:0] isKindOfClass:[TimeCodedDataPoint class]])
		{
			source = nil;
			dataPoints = [[data retain] mutableCopy];
			[dataPoints sortUsingFunction:afTimeCodedPointSort context:NULL];
			TimeCodedDataPoint* start = [data objectAtIndex:0];
			TimeCodedDataPoint* end = [data lastObject];
			range = QTMakeTimeRange([start time], QTMakeTime([end time].timeValue - [start time].timeValue,[start time].timeScale));
            
			maxValue = -DBL_MAX;
			minValue = DBL_MAX;
			mean = 0;
			double numPoints = 0;
			for(TimeCodedDataPoint* point in dataPoints)
			{
				numPoints++;
				maxValue = fmax(maxValue, [point value]);
				minValue = fmin(minValue, [point value]);
				mean = ((mean * (numPoints - 1)) + [point value])/numPoints;
                
			}
        
		}
		else
		{
			[self release];
			return nil;
		}
	}
	return self;
}

// Initialize with an array of values evenly distributed over a range
-(id)initWithDataPoints:(NSArray*)values overRange:(QTTimeRange)timeRange
{
	int numPoints = [values count];
	float interval = (float)(timeRange.duration.timeValue)/(numPoints - 1);
	
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:numPoints];
	int i;
	for(i = 0; i < numPoints; i++)
	{
		TimeCodedDataPoint *dataPoint = [[TimeCodedDataPoint alloc] init];
		[dataPoint setValue:[[values objectAtIndex:i] doubleValue]];
		[dataPoint setTime:QTMakeTime(i*interval,timeRange.duration.timeScale)];
		[array addObject:dataPoint];
		[dataPoint release];
	}
	
	return [self initWithDataPointArray:array];
}

- (void) dealloc
{
	[dataPoints release];
	[super dealloc];
}

-(TimeCodedDataPoint*)addPoint:(TimeCodedDataPoint*)point
{	
	double value = [point value];
	QTTime time = [point time];
	
	if([dataPoints count] == 0)
	{
		[dataPoints addObject:point];
		maxValue = value;
		minValue = value;
		mean = value;
		range = QTMakeTimeRange(time,QTMakeTime(0,600));
	}
	else
	{
		int index = 0;
		for(TimeCodedDataPoint *testPoint in dataPoints)
		{
			if(QTTimeCompare(testPoint.time,time) == NSOrderedDescending)
			{
				break;
			}
			index++;
		}
		[dataPoints insertObject:point atIndex:index];
		
		if(value > maxValue)
		{
			maxValue = value;
		}
		if(value < minValue)
		{
			minValue = value;
		}
		
		mean = ((mean * ([dataPoints count] - 1)) + [point value])/[dataPoints count];
		
		if(!QTTimeInTimeRange(time, range))
		{
			range = QTUnionTimeRange(range, QTMakeTimeRange(time, QTMakeTime(0,600)));
		}
	}
	
	return point;
}

-(TimeCodedDataPoint*)addValue:(double)value atTime:(QTTime)time
{
	TimeCodedDataPoint *point = [[TimeCodedDataPoint alloc] init];
	point.value = value;
	point.time = time;
	
	[self addPoint:point];
	
	[point release];
	
	return point;
}

-(TimeCodedDataPoint*)addValue:(double)value atSeconds:(NSTimeInterval)seconds
{
	return [self addValue:value atTime:QTMakeTimeWithTimeInterval(seconds)];
}

-(void)addPoints:(NSArray*)timeCodedDataPoints
{
    intervalMode = -1;
    
    if((timeCodedDataPoints == nil) || ([timeCodedDataPoints count] == 0))
    {
        return;
    }
    else if ([[timeCodedDataPoints objectAtIndex:0] isKindOfClass:[TimeCodedDataPoint class]])
    {
        dataPoints = [timeCodedDataPoints mutableCopy];
        [dataPoints sortUsingFunction:afTimeCodedPointSort context:NULL];
        TimeCodedDataPoint* start = [dataPoints objectAtIndex:0];
        TimeCodedDataPoint* end = [dataPoints lastObject];
        range = QTMakeTimeRange([start time], QTMakeTime([end time].timeValue - [start time].timeValue,[start time].timeScale));
        
        maxValue = -DBL_MAX;
        minValue = DBL_MAX;
        mean = 0;
        double numPoints = 0;
        for(TimeCodedDataPoint* point in dataPoints)
        {
            numPoints++;
            maxValue = fmax(maxValue, [point value]);
            minValue = fmin(minValue, [point value]);
            mean = ((mean * (numPoints - 1)) + [point value])/numPoints;
            
        }
    }
}

-(void)removeAllPoints
{
    maxValue = -DBL_MAX;
    minValue = DBL_MAX;
    mean = 0;
    
    [dataPoints removeAllObjects];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	//NSString *altColon = @"⁚";
	[super encodeWithCoder:coder];

	// Taken over by TimeCodedData
//	[coder encodeObject:name forKey:@"AnnotationDataSetName"];
//	[coder encodeQTTimeRange:range forKey:@"AnnotationDataSetRange"];
	[coder encodeDouble:minValue forKey:@"AnnotationDataSetMinValue"];
	[coder encodeDouble:maxValue forKey:@"AnnotationDataSetMaxValue"];
	[coder encodeDouble:mean forKey:@"AnnotationDataSetMean"];
    [coder encodeDouble:intervalMode forKey:@"AnnotationDataSetIntervalMode"];
	//[coder encodeObject:dataPoints forKey:@"AnnotationDataArray"];
	[coder encodeObject:[self csvData] forKey:@"AnnotationCSVData"];
}

- (id)initWithCoder:(NSCoder *)coder {
    if(self = [super initWithCoder:coder])
	{
		// Taken over by TimeCodedData
//		self.name = [[coder decodeObjectForKey:@"AnnotationDataSetName"] retain];
//		range = [coder decodeQTTimeRangeForKey:@"AnnotationDataSetRange"];
		minValue = [coder decodeDoubleForKey:@"AnnotationDataSetMinValue"];
		maxValue = [coder decodeDoubleForKey:@"AnnotationDataSetMaxValue"];
        if([coder containsValueForKey:@"AnnotationDataSetIntervalMode"])
        {
            intervalMode = [coder decodeDoubleForKey:@"AnnotationDataSetIntervalMode"];   
        }
        else
        {
            intervalMode = -1;
        }
		//dataPoints = [[NSMutableArray alloc] initWithArray:[coder decodeObjectForKey:@"AnnotationDataArray"]];
		NSString *csvData = [coder decodeObjectForKey:@"AnnotationCSVData"];
		NSArray *dataArray = [csvData csvRows];
		dataPoints = [[self dataPointsFromCSVArray:dataArray] retain];
		
		if([coder containsValueForKey:@"AnnotationDataSetMean"])
		{
			mean = [coder decodeDoubleForKey:@"AnnotationDataSetMean"];
		}
		else
		{
			mean = 0;
			double numPoints = 0;
			for(TimeCodedDataPoint* point in dataPoints)
			{
				numPoints++;
				mean = ((mean * (numPoints - 1)) + [point value])/numPoints;
			}
		}
	}
    return self;
}


- (void)shiftByTime:(QTTime)diff
{	
	for(TimeCodedDataPoint* point in dataPoints)
	{
		[point setTime:QTTimeIncrement([point time],diff)];
	}
	
	range.time = QTTimeIncrement(range.time,diff);
}

- (void)scaleFromRange:(QTTimeRange)oldRange toRange:(QTTimeRange)newRange
{
	QTTime startDiff = QTTimeDecrement(oldRange.time, newRange.time);
	double scaleFactor = (double)newRange.duration.timeValue/(double)oldRange.duration.timeValue;
	
	range.time = QTTimeDecrement(range.time, startDiff);
	range.duration.timeValue = range.duration.timeValue * scaleFactor;
	
	for(TimeCodedDataPoint* point in dataPoints)
	{
		[point setTime:QTMakeTime(([point time].timeValue - startDiff.timeValue)*scaleFactor,startDiff.timeScale)];
	}
}

- (void)scaleToRange:(QTTimeRange)newRange
{
	[self scaleFromRange:range toRange:newRange];
}

- (QTTimeRange)range
{
	return range;
}

- (QTTime)startTime
{
	return [[dataPoints objectAtIndex:0] time];
}

- (QTTime)endTime
{
	return [[dataPoints lastObject] time];
}

- (double)maxValue
{
	return maxValue;
}

- (double)minValue
{
	return minValue;
}

- (double)mean
{
	return mean;
}

- (double)intervalMode
{
    if(intervalMode <= 0)
    {
        NSMutableDictionary* intervalFrequencyDict = [[NSMutableDictionary alloc] init];
        
        NSNumber *interval = nil;
        NSTimeInterval pointTimeDiff;
        QTTime lastTime = [[dataPoints objectAtIndex:0] time];
        
        for(TimeCodedDataPoint* point in dataPoints)
        {
            // Calculate the frequencies of point intervals
            QTGetTimeInterval(QTTimeDecrement([point time], lastTime), &pointTimeDiff);
            interval = [NSNumber numberWithLong:lround(pointTimeDiff * 100)];
            id num = [intervalFrequencyDict objectForKey:interval];
            if(num)
            {
                [intervalFrequencyDict setObject:[NSNumber numberWithInt:[num intValue]+1] forKey:interval];
            }
            else
            {
                [intervalFrequencyDict setObject:[NSNumber numberWithInt:1] forKey:interval];
            }
            lastTime = [point time];
        }
        
        // Find the mode of point intervals
        // This allows us to know recording frame rate while allowing for gaps in data
        int freq = 0;
        intervalMode = 0;
        for(NSNumber *testInterval in [intervalFrequencyDict allKeys])
        {
            NSNumber *frequency = [intervalFrequencyDict objectForKey:testInterval];
            if([frequency intValue] > freq)
            {
                freq = [frequency intValue];
                intervalMode = [testInterval doubleValue]/100.0;
            }
        }
        
        [intervalFrequencyDict release];
    }
    return intervalMode;
}

- (NSArray*)dataPoints
{
	return dataPoints;
}

- (NSArray*)values
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[dataPoints count]];
	for(TimeCodedDataPoint *point in dataPoints)
	{
		NSNumber *num = [[NSNumber alloc] initWithFloat:[point numericValue]];
		[dataPoints addObject:num];
		[num release];
	}
	return array;
}

- (NSArray*)subsetOfSize:(NSUInteger)size forRange:(QTTimeRange)subsetRange
{
	NSMutableArray *subset = [NSMutableArray arrayWithCapacity:size];
    
    NSTimeInterval rangeDuration;
    QTGetTimeInterval(subsetRange.duration, &rangeDuration);
    
    NSTimeInterval startTime;
    QTGetTimeInterval(subsetRange.time,&startTime);
    
    CGFloat pixelToMovieTime = rangeDuration/(CGFloat)size;
    CGFloat pixel = 0;
    NSTimeInterval movieTime = startTime;
	for(TimeCodedDataPoint *point in [self dataPoints])
	{
        NSTimeInterval pointTime;
        QTGetTimeInterval([point time], &pointTime);
		if(pointTime >= movieTime)
		{
			[subset addObject:point];
            pixel = (pointTime - startTime)/pixelToMovieTime;
            pixel += 1;
			movieTime = startTime + pixel*pixelToMovieTime;
			if(pixel > size)
			{
				break;
			}
		}
	}
    
    
    
//	float pixelToMovieTime = (float)subsetRange.duration.timeValue/size;
//	float pixel = 0;
//	long movieTime = subsetRange.time.timeValue + pixel*pixelToMovieTime;
//	for(TimeCodedDataPoint *point in [self dataPoints])
//	{
//		if([point time].timeValue >= movieTime)
//		{
//			[subset addObject:point];
//			pixel += 1;
//			movieTime = subsetRange.time.timeValue + pixel*pixelToMovieTime;
//			if(pixel > size)
//			{
//				break;
//			}
//		}
//	}
	//NSLog(@"Created Subset: %i/%i",[subset count],[[data dataPoints] count]);
	return subset;
}

- (NSString*)csvData
{
	NSMutableString *string = [NSMutableString stringWithCapacity:([dataPoints count]*2*8)];
	
	for(TimeCodedDataPoint* point in dataPoints)
	{
		[string appendFormat:@"%@\n",[point csvString]];
		//[string appendFormat:@"%qi,%.6f\n",point.time.timeValue,point.value];
	}
	
	return [NSString stringWithString:string];
}

- (NSMutableArray*)dataPointsFromCSVArray:(NSArray*)dataArray
{
	NSMutableArray *dataPointArray = [NSMutableArray arrayWithCapacity:[dataArray count]];
	long timeScale = range.time.timeScale;
	BOOL timeIntervals = ([(NSString*)[[dataArray objectAtIndex:0] objectAtIndex:0] rangeOfString:@"."].location != NSNotFound);
	for(NSArray* row in dataArray)
	{
		TimeCodedDataPoint *dataPoint = [[TimeCodedDataPoint alloc] init];
		[dataPoint setValue:[[row objectAtIndex:1] doubleValue]];
		if(timeIntervals)
		{
			[dataPoint setTime:QTMakeTimeWithTimeInterval([[row objectAtIndex:0] floatValue])];
		}
		else
		{
			[dataPoint setTime:QTMakeTime([[row objectAtIndex:0] longLongValue],timeScale)];
		}
		
		[dataPointArray addObject:dataPoint];
		[dataPoint release];
	}
	return dataPointArray;
}

@end
