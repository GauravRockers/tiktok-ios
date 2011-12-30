//
//  Coupon.m
//  TikTok
//
//  Created by Moiz Merchant on 4/29/11.
//  Copyright 2011 TikTok. All rights reserved.
//

//------------------------------------------------------------------------------
// imports
//------------------------------------------------------------------------------

#import "Coupon.h"
#import "Merchant.h"
#import "UIDefaults.h"

//------------------------------------------------------------------------------
// interface implementation
//------------------------------------------------------------------------------

@implementation Coupon

//------------------------------------------------------------------------------

@dynamic title;
@dynamic details;
@dynamic imagePath;
@dynamic startTime;
@dynamic endTime;
@dynamic wasRedeemed;
@dynamic merchant;

//------------------------------------------------------------------------------
#pragma mark - Static methods
//------------------------------------------------------------------------------

+ (Coupon*) getCouponByName:(NSString*)name 
                fromContext:(NSManagedObjectContext*)context
{
    // grab the coupon description
    NSEntityDescription *description = [NSEntityDescription
        entityForName:@"Coupon" inManagedObjectContext:context];

    // create a coupon fetch request
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:description];

    // setup the request to lookup the specific coupon by name
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"details == %@", name];
    [request setPredicate:predicate];

    // return the coupon if it already exists in the context
    NSError *error = nil;
    NSArray *array = [context executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"failed to query context for coupon: %@", error);
        return nil;
    }

    // return found merchant, otherwise nil
    Coupon* coupon = [array count] ? (Coupon*)[array objectAtIndex:0] : nil;
    return coupon;
}

//------------------------------------------------------------------------------

+ (Coupon*) getOrCreateCouponWithJsonData:(NSDictionary*)data 
                              fromContext:(NSManagedObjectContext*)context
{
    // check if coupon already exists in the store
    NSString *name = [data objectForKey:@"description"];
    Coupon *coupon = [Coupon getCouponByName:name fromContext:context];
    if (coupon != nil) {
        return coupon;
    }

    // create merchant from json 
    NSDictionary *merchantData = [data objectForKey:@"merchant"];
    Merchant *merchant = 
        [Merchant getOrCreateMerchantWithJsonData:merchantData 
                                      fromContext:context];

    // skip out if we can't retrive a merchant from the context
    if (merchant == nil) {
        NSLog(@"failed to parse merchant.");
        return nil;
    }

    // create a new coupon object
    coupon = (Coupon*)[NSEntityDescription 
        insertNewObjectForEntityForName:@"Coupon" 
                 inManagedObjectContext:context];
    [coupon initWithJsonDictionary:data];
    coupon.merchant = merchant;

    // -- debug --
    NSLog(@"new coupon created: %@", coupon.title);

    // save the object to store
    NSError *error = nil;
    if (![context save:&error]) {
        NSLog(@"coupon save failed: %@", error);
    }

    return coupon;
}

//------------------------------------------------------------------------------
#pragma mark - methods
//------------------------------------------------------------------------------

- (Coupon*) initWithJsonDictionary:(NSDictionary*)data
{ 
    NSNumber *enableTime = [data objectForKey:@"enable_time_in_tvsec"];
    NSNumber *expireTime = [data objectForKey:@"expiry_time_in_tvsec"];

    self.imagePath   = [data objectForKey:@"image_url"];
    self.title       = [data objectForKey:@"description"];
    self.startTime   = [NSDate dateWithTimeIntervalSince1970:enableTime.intValue];
    self.endTime     = [NSDate dateWithTimeIntervalSince1970:expireTime.intValue];

    self.details     = @"its been a while since i've seen you smile, but now your back again, came into my room and saw my girl, you asked her how long its been, she said a year and you shook your head, said im suprised its gone that long, people say how beautiful how sweet how kind, your perfect youve got nothing to hide, but i for one have seen the sun and the bitch youve locked up inside";
    self.wasRedeemed = NO;

    return self;
}

//------------------------------------------------------------------------------

- (BOOL) isExpired 
{
    NSTimeInterval seconds = [self.endTime timeIntervalSinceNow];
    return seconds <= 0.0;
}

//------------------------------------------------------------------------------

- (UIColor*) getColor
{
    // return the default color if expired
    if ([self isExpired]) return [UIDefaults getTokColor];

    // calculte interp value
    NSTimeInterval secondsLeft  = [self.endTime timeIntervalSinceNow];
    NSTimeInterval totalSeconds = [self.endTime timeIntervalSinceDate:self.startTime];
    CGFloat t                   = 1.0 - (secondsLeft / totalSeconds);

    // colors to transition between
    UIColor *tik    = [UIDefaults getTikColor];
    UIColor *yellow = [UIColor yellowColor];
    UIColor *orange = [UIColor orangeColor];
    UIColor *tok    = [UIDefaults getTokColor];

    // struct to make computations cleaner
    struct ColorTable {
        CGFloat t, offset;
        UIColor *start, *end;
    } sColorTable[3] = {
        { 0.33, 0.00, tik,    yellow },
        { 0.66, 0.33, yellow, orange },
        { 1.00, 0.66, orange, tok    },
    };

    // return the interpolated color
    NSUInteger index = 0;
    for (; index < 3; ++index) {
        if (t > sColorTable[index].t) continue;

        UIColor *start = sColorTable[index].start;
        UIColor *end   = sColorTable[index].end;
        CGFloat newT   = (t - sColorTable[index].offset) / 0.33;
        return [start colorByInterpolatingToColor:end
                                       byFraction:newT];
    }

    // in case something went wrong...
    return [UIColor blackColor];
}

//------------------------------------------------------------------------------

- (NSString*) getExpirationTime
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    NSString *expirationTime = [formatter stringForObjectValue:self.endTime];
    [formatter release];

    return expirationTime;
}

//------------------------------------------------------------------------------

- (NSString*) getExpirationTimer
{
    // return the default color if expired
    if ([self isExpired]) return @"00:00:00";
    
    // calculate inter value
    NSTimeInterval secondsLeft  = [self.endTime timeIntervalSinceNow];
    CGFloat minutesLeft         = secondsLeft / 60.0;

    // update the coupon expire timer
    NSString *timer = $string(@"%.2d:%.2d:%.2d", 
        (int)minutesLeft / 60, (int)minutesLeft % 60, (int)secondsLeft % 60);
    return timer;
}

//------------------------------------------------------------------------------

@end
