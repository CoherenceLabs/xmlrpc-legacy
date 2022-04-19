#import "XMLRPCResponse.h"
#import "XMLRPCEventBasedParser.h"

#define FILTER_BUFFER_SIZE  1024

static NSData *dataByRemovingNonXMLControlCharacters(NSData *sourceData)
{
    unsigned char *buffer = (unsigned char *)malloc(FILTER_BUFFER_SIZE * sizeof(unsigned char));
    if (buffer == NULL) {
        return sourceData; // No choice but to bail out, but in practice we shouldn't hit this for such a small buffer allocation.
    }
    NSUInteger sourceDataLength = [sourceData length];
    NSMutableData *result = [[NSMutableData alloc] initWithCapacity:sourceDataLength];
    NSUInteger sourceDataOffset = 0;
    while (sourceDataOffset < sourceDataLength) {
        NSUInteger thisPageSourceLength = MIN(FILTER_BUFFER_SIZE, sourceDataLength - sourceDataOffset);
        [sourceData getBytes:buffer range:NSMakeRange(sourceDataOffset, thisPageSourceLength)];
        unsigned char *source = buffer;
        unsigned char *sourceEnd = buffer + thisPageSourceLength;
        unsigned char *dest = source;
        while (source < sourceEnd) {
            unsigned char c = *source;
            if (c <= 27 && (c != '\t' && c != '\n' && c != '\r')) { // Filter control characters XML disallows. (The sender should probably have escaped these.)
                ++source;
            } else {
                *dest++ = *source++;
            }
        }
        NSUInteger thisPageResultLength = dest - buffer;
        [result appendBytes:buffer length:thisPageResultLength];
        sourceDataOffset += thisPageSourceLength;
    }
    
    free(buffer);
    return [result autorelease];
}

@implementation XMLRPCResponse

- (id)initWithData: (NSData *)data {
    if (!data) {
        return nil;
    }

    // WordPress post/page content may contain spurious control characters that XML parsing chokes on.  Filter them out.
    NSData *filteredData = dataByRemovingNonXMLControlCharacters(data);

    self = [super init];
    if (self) {
        XMLRPCEventBasedParser *parser = [[XMLRPCEventBasedParser alloc] initWithData: filteredData];
        
        if (!parser) {
#if ! __has_feature(objc_arc)
            [self release];
#endif
            return nil;
        }
    
        myBody = [[NSString alloc] initWithData: filteredData encoding: NSUTF8StringEncoding];
        myObject = [parser parse];
#if ! __has_feature(objc_arc)
        [myObject retain];
#endif
        
        isFault = [parser isFault];
        
#if ! __has_feature(objc_arc)
        [parser release];
#endif
    }
    
    return self;
}

#pragma mark -

- (BOOL)isFault {
    return isFault;
}

- (NSNumber *)faultCode {
    if (isFault) {
        return [myObject objectForKey: @"faultCode"];
    }
    
    return nil;
}

- (NSString *)faultString {
    if (isFault) {
        return [myObject objectForKey: @"faultString"];
    }
    
    return nil;
}

#pragma mark -

- (id)object {
    return myObject;
}

#pragma mark -

- (NSString *)body {
    return myBody;
}

#pragma mark -

- (NSString *)description {
	NSMutableString	*result = [NSMutableString stringWithCapacity:128];
    
	[result appendFormat:@"[body=%@", myBody];
    
	if (isFault) {
		[result appendFormat:@", fault[%@]='%@'", [self faultCode], [self faultString]];
	} else {
		[result appendFormat:@", object=%@", myObject];
	}
    
	[result appendString:@"]"];
    
	return result;
}

#pragma mark -

- (void)dealloc {
#if ! __has_feature(objc_arc)
    [myBody release];
    [myObject release];
    
    [super dealloc];
#endif
}

@end
