//
//  CheckinViewController.m
//  TikTok
//
//  Created by Moiz Merchant on 5/28/11.
//  Copyright 2011 TikTok. All rights reserved.
//

//------------------------------------------------------------------------------
// imports 
//------------------------------------------------------------------------------

#import "TikTokAppDelegate.h"
#import "CheckinViewController.h"
#import "CouponViewController.h"
#import "TikTokApi.h"

#import "Coupon.h"

//------------------------------------------------------------------------------
// interface implementation
//------------------------------------------------------------------------------

@implementation CheckinViewController

//------------------------------------------------------------------------------

@synthesize checkinButton      = m_checkin_button;
@synthesize checkoutButton     = m_checkout_button;
@synthesize locationController = m_location_controller;
@synthesize checkinLocation    = m_checkin_location;

//------------------------------------------------------------------------------
#pragma mark - View lifecycle
//------------------------------------------------------------------------------

- (void) viewDidLoad
{
    [super viewDidLoad];

    // setup the location controller
    self.locationController = [[[LocationController alloc] init] autorelease];

    // setup the checkin/checkout buttons
    self.checkinButton.hidden  = NO;
    self.checkoutButton.hidden = NO;

    [self.locationController.locationManager startUpdatingLocation];

    // request location authorization 
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        //[self.locationController.locationManager startUpdatingLocation];
        //[self.locationController.locationManager startMonitoringSignificantLocationChanges];
    }
}

//------------------------------------------------------------------------------

- (void) viewDidUnload 
{
    [super viewDidUnload];
}

//------------------------------------------------------------------------------
#pragma mark - Memory management
//------------------------------------------------------------------------------

- (void) didReceiveMemoryWarning 
{
    // releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

//------------------------------------------------------------------------------

- (void) dealloc
{
    if (m_checkin_location) { [m_checkin_location release]; }
    [m_location_controller release];
    [super dealloc];
}

//------------------------------------------------------------------------------
#pragma mark - Checkin
//------------------------------------------------------------------------------

- (IBAction) checkIn:(id)sender
{
    // [moiz] what should we do in this situation?
    // make sure that we are not already checked in
    if ([self isCheckedIn]) {
        return;
    }

    // get the current location of the user
    /*
    CLLocation *currentLocation  = self.locationController.locationManager.location;
    NSLog(@"CheckinViewController: currentLocation: %@", [currentLocation description]);
    if (currentLocation == nil) {
        NSLog(@"CheckinViewController: failed to get current location.");
        return;
    }
    */

    // load the coupons into the database
    TikTokApi *api = [[TikTokApi new] autorelease];
    api.managedContext = [((TikTokAppDelegate*)[[UIApplication sharedApplication] delegate]) managedObjectContext];
    [api getActiveCoupons];

    // use the api to contact the server and attempt to checkin
    //TikTokApi *api = [[TikTokApi new] autorelease];
    //api.managedContext     = [((TikTokAppDelegate*)[[UIApplication sharedApplication] delegate]) managedObjectContext];
    //self.checkinLocation   = [api checkInWithCurrentLocation:currentLocation];

    // start tracking the current location if checked in
    //if ([self isCheckedIn]) {

        // load up the coupon table view
        CouponViewController *couponViewController = [[[CouponViewController alloc] 
            initWithNibName:@"CouponViewController" bundle:nil] 
                autorelease];

        /*
        // start tracking location updates
        //[self.locationController.locationManager startUpdatingLocation];

        // create a region
        CLLocationCoordinate2D coordinate = currentLocation.coordinate;
        CLLocationDistance radius         = 2000.0f;      
        CLRegion *region = [[[CLRegion alloc] 
            initCircularRegionWithCenter:coordinate 
                                  radius:radius 
                              identifier:@"centera"] autorelease];

        // add the region to the location manager
        CLLocationAccuracy accuracy = 1000.0f;
        [self.locationController.locationManager startMonitoringForRegion:region desiredAccuracy:accuracy];

        NSLog(@"CheckinController: monitored regions: %@", 
            self.locationController.locationManager.monitoredRegions);
        */

        // pass the selected object to the new view controller.
        [self.navigationController pushViewController:couponViewController animated:YES];

        // swap out the buttons
        self.checkinButton.hidden  = YES;
        self.checkoutButton.hidden = NO;
    //} 
}

//------------------------------------------------------------------------------

- (IBAction) checkOut:(id)sender
{
    // can't checkout if not checked in
    if (![self isCheckedIn]) {
        return;
    }

    // use the api to contact the server to checkout
    TikTokApi *api = [[TikTokApi new] autorelease];
    [api checkOut];
            
    // stop recieving location updates
    [self.locationController.locationManager stopUpdatingLocation];

    // release the current location 
    [m_checkin_location release];
    m_checkin_location = nil;

    // swap out the buttons
    self.checkinButton.hidden  = NO;
    self.checkoutButton.hidden = YES;
}

//------------------------------------------------------------------------------

- (bool) isCheckedIn
{
    bool checkedIn = self.checkinLocation != nil;
    return checkedIn;
}

//------------------------------------------------------------------------------
#pragma mark - LocationControllerDelegate
//------------------------------------------------------------------------------

- (void) locationUpdate:(CLLocation*)location
{
    NSLog(@"Location Update: %@", [location description]);

    // check out the user if they have left the valid area
    if ([self isCheckedIn]) {

        // construct location of the checkin area
        CLLocation *checkinLocation = [[CLLocation alloc]
            initWithLatitude:self.checkinLocation.longitude.doubleValue 
                   longitude:self.checkinLocation.latitude.doubleValue];
        [checkinLocation autorelease];

        // calculate distance between locations
        CLLocationDistance distance = 
            [location distanceFromLocation:checkinLocation]; 

        // check if the user is outside the valid radius
        if ([NSNumber numberWithDouble:distance] > self.checkinLocation.radius) {
            [self checkOut:nil];
        }
    }
}

//------------------------------------------------------------------------------

- (void) locationError:(NSError*)error
{
    NSLog(@"Location Error: %@", [error description]);
}

//------------------------------------------------------------------------------

@end