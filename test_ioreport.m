#import <Foundation/Foundation.h>

enum {
    kIOReportIterOk,
};

typedef struct IOReportSubscriptionRef* IOReportSubscriptionRef;
typedef CFDictionaryRef IOReportSampleRef;

extern IOReportSubscriptionRef IOReportCreateSubscription(void* a, CFMutableDictionaryRef desiredChannels, CFMutableDictionaryRef* subbedChannels, uint64_t channel_id, CFTypeRef b);

extern CFMutableDictionaryRef IOReportCopyChannelsInGroup(NSString*, NSString*, uint64_t, uint64_t, uint64_t);
extern CFMutableDictionaryRef IOReportCopyAllChannels(uint64_t, uint64_t);

extern int IOReportGetChannelCount(CFMutableDictionaryRef);
struct IOReporter_client_subscription;

extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef iorsub, CFMutableDictionaryRef subbedChannels, CFTypeRef a);

typedef int (^ioreportiterateblock)(IOReportSampleRef ch);

extern void IOReportIterate(CFDictionaryRef samples, ioreportiterateblock);
extern int IOReportChannelGetFormat(CFDictionaryRef samples);
extern long IOReportSimpleGetIntegerValue(CFDictionaryRef, int);
extern NSString* IOReportChannelGetDriverName(CFDictionaryRef);
extern NSString* IOReportChannelGetChannelName(CFDictionaryRef);
extern int IOReportStateGetCount(CFDictionaryRef);
extern uint64_t IOReportStateGetResidency(CFDictionaryRef, int);
extern NSString* IOReportStateGetNameForIndex(CFDictionaryRef, int);
extern NSString* IOReportChannelGetUnitLabel(CFDictionaryRef);
extern NSString* IOReportChannelGetGroup(CFDictionaryRef);
extern NSString* IOReportChannelGetSubGroup(CFDictionaryRef);
extern NSString* IOReportSampleCopyDescription(CFDictionaryRef, int, int);
extern uint64_t IOReportArrayGetValueAtIndex(CFDictionaryRef, int);

extern int IOReportHistogramGetBucketCount(CFDictionaryRef);
extern int IOReportHistogramGetBucketMinValue(CFDictionaryRef, int);
extern int IOReportHistogramGetBucketMaxValue(CFDictionaryRef, int);
extern int IOReportHistogramGetBucketSum(CFDictionaryRef, int);
extern int IOReportHistogramGetBucketHits(CFDictionaryRef, int);

typedef uint8_t IOReportFormat;
enum {
    kIOReportInvalidFormat = 0,
    kIOReportFormatSimple = 1,
    kIOReportFormatState = 2,
    kIOReportFormatHistogram = 3,
    kIOReportFormatSimpleArray = 4
};

void CustomLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // Log to console
   //NSLog(@"%@", message);

    // Setup date stuff

    // Paths - We're saving the data based on the day.
    NSString *writePath = @"log.txt";

    // We're going to want to append new data, so get the previous data.
    NSString *fileContents = [NSString stringWithContentsOfFile:writePath encoding:NSUTF8StringEncoding error:nil];

    // Write it to the string
    message = [NSString stringWithFormat:@"%@\n%@", fileContents, message];

    // Write to file stored at: "~/Library/Application\ Support/iPhone\ Simulator/*version*/Applications/*appGUID*/Documents/*date*-logFile.txt"
    [message writeToFile:writePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
   
}


int main(int argc, char* argv[])
{
    CFMutableDictionaryRef channels;
    if (argc >= 2) {
        channels = IOReportCopyChannelsInGroup([NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding], 0x0, 0x0, 0x0, 0x0);
    } else {
        channels = IOReportCopyAllChannels(0x0, 0x0);
    }
    // int channel_count = IOReportGetChannelCount(channels);
    CFMutableDictionaryRef subscribed_channels = NULL;
    IOReportSubscriptionRef sub = IOReportCreateSubscription(NULL, channels, &subscribed_channels, 0, 0);
    if (!sub) {
        printf("cannot find any channel\n");
        exit(-1);
    }

    CFDictionaryRef samples = NULL;
    if ((samples = IOReportCreateSamples(sub, subscribed_channels, NULL))) {
        IOReportIterate(samples, ^(IOReportSampleRef ch) {
            NSString* driver_name = IOReportChannelGetDriverName(ch);
            NSString* group = IOReportChannelGetGroup(ch);
            NSString* subgroup = IOReportChannelGetSubGroup(ch);
            NSString* channel_name = IOReportChannelGetChannelName(ch);
            uint8_t report_format = IOReportChannelGetFormat(ch);
            NSString* label = IOReportChannelGetUnitLabel(ch);
            if ([group isEqual:@"CPU Stats"]){
                switch (report_format) {
                case kIOReportFormatSimple: {
                    uint32_t value = IOReportSimpleGetIntegerValue(ch, 0);
                    CustomLog(@"%@: %@: %@:  %@: %u (%@)", driver_name, group, subgroup, channel_name, value, label);
                } break;
                case kIOReportFormatState: {
                    int state_count = IOReportStateGetCount(ch);
                    // NSLog(@"state count = %x", state_count);
                    for (int idx = 0; idx < state_count; idx++) {
                        NSString* state_name = IOReportStateGetNameForIndex(ch, idx);
                        uint64_t value = IOReportStateGetResidency(ch, idx);
                        CustomLog(@"%@: %@: %@: %@: %@: %lld (%@)", driver_name, group, subgroup, channel_name, state_name, value, label);
                    }
                } break;
                case kIOReportFormatSimpleArray: {
                    // dunno where/how to get the number of elements of the array
                    // it seems this on is only used by CLPC per cluster info, so set it to 2
                    for (int idx = 0; idx < 2; idx++) {
                        uint64_t value = IOReportArrayGetValueAtIndex(ch, idx);
                        CustomLog(@"%@: %@: %@: %@: %llu (%@)", driver_name, group, subgroup, channel_name, value, label);
                    }
                } break;
                case kIOReportFormatHistogram: {
                    int64_t hits, min, max, sum;
                    CustomLog(@"%@: %@: %@: %@: (%@)", driver_name, group, subgroup, channel_name, label);
                    int bucket_count = IOReportHistogramGetBucketCount(ch);
                    CustomLog(@"Bkt | hits  min  max  sum\n");
                    for (int i = 0; i < bucket_count; i++) {
                        hits = IOReportHistogramGetBucketHits(ch, i);
                        min = IOReportHistogramGetBucketMinValue(ch, i);
                        max = IOReportHistogramGetBucketMaxValue(ch, i);
                        sum = IOReportHistogramGetBucketSum(ch, i);

                        CustomLog(@"%3d | %4lld  %3lld  %3lld  %3lld\n", i, hits, min, max, sum);
                    }
                } break;
                default:
                    CustomLog(@"%@: %@:  %@: (%@)", group, subgroup, channel_name, label);
                    CustomLog(@"format = %hhx", report_format);
                }
            }
            return kIOReportIterOk;
        });
    } else {
        printf("Internal failure: Failed to get power state information\n");
    }
    exit(0);
}
