//
//  CouponDetailViewController.m
//  TikTok
//
//  Created by Moiz Merchant on 4/22/11.
//  Copyright 2011 TikTok. All rights reserved.
//

//------------------------------------------------------------------------------
// imports
//------------------------------------------------------------------------------

#import <QuartzCore/QuartzCore.h>
#import "CouponDetailViewController.h"
#import "Coupon.h"
#import "GradientView.h"
#import "IconManager.h"
#import "Merchant.h"
#import "MerchantViewController.h"
#import "Utilities.h"

//------------------------------------------------------------------------------
// enums
//------------------------------------------------------------------------------

enum CouponDetailTag
{
    kTagScrollView     = 14,
    kTagTitleBar       = 11,
    kTagTitle          =  3,
    kTagContentView    =  2,
    kTagIcon           =  5,
    kTagIconActivity   =  6,
    kTagColorTimer     =  7,
    kTagTextTimer      =  8,
    kTagTextTime       =  9,
    kTagMap            = 10,
    kTagCompanyName    = 12,
    kTagCompanyAddress = 13,
    kTagDetails        =  4,
    kTagBarcodeView    =  1,
};

enum ActionButton
{
    kActionButtonSMS   = 0,
    kActionButtonEmail = 1,
};

//------------------------------------------------------------------------------
// interface definition
//------------------------------------------------------------------------------

@interface CouponDetailViewController ()
    - (void) addShadows;
    - (void) setupToolbar;
    - (void) setupCouponDetails;
    - (void) setupIcon;
    - (void) setIcon:(UIImage*)image;
    - (void) setupMap;
    - (void) arrangeSubviewsForRedeemedCouponWithAnimation:(bool)animated;
    - (void) resetSubviews;
    - (void) startTimer;
    - (void) updateTimers;
    - (void) shareSMS;
    - (void) shareEmail;
@end

//------------------------------------------------------------------------------
// interface implementation
//------------------------------------------------------------------------------

@implementation CouponDetailViewController

//------------------------------------------------------------------------------

@synthesize coupon       = mCoupon;
@synthesize timer        = mTimer;
@synthesize barcodeView  = mBarcodeView;
@synthesize redeemButton = mRedeemButton;

//------------------------------------------------------------------------------
#pragma - View Lifecycle
//------------------------------------------------------------------------------

/**
 * The designated initializer.  Override if you create the controller 
 * programmatically and want to perform customization that is not appropriate 
 * for viewDidLoad.
 */
- (id) initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil 
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

//------------------------------------------------------------------------------

/**
 * Implement viewDidLoad to do additional setup after loading the view, 
 * typically from a nib.
 */
- (void) viewDidLoad 
{
    [super viewDidLoad];

    // set title 
    self.title = @"Deal";

    // add barcode view to the view and hide, do this so it shows up seperately
    // in interface designer and is easier to manage
    UIScrollView *scrollView = (UIScrollView*)[self.view viewWithTag:kTagScrollView];
    [scrollView addSubview:self.barcodeView];
    self.barcodeView.hidden = YES;

    // setup toolbar
    [self setupToolbar];

    // add nice little shadow details
    [self addShadows];

    // correct font on timer
    UILabel *timer = (UILabel*)[self.view viewWithTag:kTagTextTimer];
    timer.font     = [UIFont fontWithName:@"NeutraDisp-BoldAlt" size:20];
}

//------------------------------------------------------------------------------

- (void) viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    [self setupCouponDetails];

    // don't add redeem button if coupon is expired or already activated
    if (self.coupon.wasRedeemed) {
        [self arrangeSubviewsForRedeemedCouponWithAnimation:false];
    } else if (![self.coupon isExpired]) {
        [self.navigationController setToolbarHidden:NO animated:YES];
    } else {
        [self resetSubviews];
    }

    // setup an update loop to for the color/text timers
    if (!self.coupon.isExpired) {
        [self startTimer];
    }
}

//------------------------------------------------------------------------------

/*
- (void) viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
}
*/

//------------------------------------------------------------------------------

- (void) viewWillDisappear:(BOOL)animated 
{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];

    // stop timer 
    [self.timer invalidate];
}

//------------------------------------------------------------------------------

/**
 * Override to allow orientations other than the default portrait orientation.
 * /
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

//------------------------------------------------------------------------------
#pragma - Properties
//------------------------------------------------------------------------------

- (void) setCoupon:(Coupon*)coupon
{
    if (mCoupon) [mCoupon release];
    mCoupon = [coupon retain];
    [self setupCouponDetails];

    // fix up scroll view to account for text view content
    UIScrollView *scrollView = (UIScrollView*)[self.view viewWithTag:kTagScrollView];
    UITextView *textView     = (UITextView*)[self.view viewWithTag:kTagDetails];
    CGSize contentSize       = scrollView.contentSize;
    contentSize.height       = textView.frame.origin.y + textView.contentSize.height + 60;
    scrollView.contentSize   = contentSize;
}

//------------------------------------------------------------------------------
#pragma - Setup
//------------------------------------------------------------------------------

- (void) addShadows
{
    // map view
    UIView *titleView             = [self.view viewWithTag:15];
    titleView.layer.shadowColor   = [[UIColor blackColor] CGColor];
    titleView.layer.shadowOffset  = CGSizeMake(2.0f, 2.0f);
    titleView.layer.shadowOpacity = 0.2f;

    // map view
    UIView *mapView             = [[self.view viewWithTag:kTagMap] superview];
    mapView.layer.shadowColor   = [[UIColor blackColor] CGColor];
    mapView.layer.shadowOffset  = CGSizeMake(2.0f, 2.0f);
    mapView.layer.shadowOpacity = 0.2f;
}

//------------------------------------------------------------------------------

- (void) setupToolbar
{
    // create a flexible spacer
    UIBarButtonItem *flexibleSpaceButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace 
                             target:nil 
                             action:nil];

    // create a bar button
    UIBarButtonItem *barButtonItem = 
        [[UIBarButtonItem alloc] initWithCustomView:self.redeemButton];
     
    // set the items in the toolbar
    self.toolbarItems = $array(
        flexibleSpaceButton, 
        barButtonItem,
        flexibleSpaceButton,
        nil);

    // cleanup 
    [flexibleSpaceButton release];
    [barButtonItem release];
}

//------------------------------------------------------------------------------

- (void) setupCouponDetails
{
    // title
    UITextView *title = (UITextView*)[self.view viewWithTag:kTagTitle];
    title.text        = [self.coupon.title capitalizedString];

    // details
    UITextView *details = (UITextView*)[self.view viewWithTag:kTagDetails];
    details.text        = self.coupon.details;

    // icon
    [self setupIcon];

    // map
    [self setupMap];
    
    // merchant name
    UILabel *name = (UILabel*)[self.view viewWithTag:kTagCompanyName];
    name.text     = [self.coupon.merchant.name uppercaseString];

    // merchant address
    UILabel *address = (UILabel*)[self.view viewWithTag:kTagCompanyAddress];
    address.text     = self.coupon.merchant.address;
    
    // color timer
    GradientView *color = (GradientView*)[self.view viewWithTag:kTagColorTimer];
    color.color         = [self.coupon getColor];

    // text timer
    UILabel *label = (UILabel*)[self.view viewWithTag:kTagTextTimer];
    label.text     = [self.coupon getExpirationTimer];
}

//------------------------------------------------------------------------------

- (void) setupIcon
{
    IconManager *iconManager = [IconManager getInstance];
    __block UIImage *image   = [iconManager getImage:self.coupon.iconData];

    // set merchant icon
    [self setIcon:image];

    // load image from server if not available
    if (!image) {
        [iconManager requestImage:self.coupon.iconData 
            withCompletionHandler:^(UIImage* image, NSError *error) {
                if (image != nil) {
                    [self setIcon:image];
                } else if (error) {
                    NSLog(@"MerchantViewController: Failed to load image, %@", error);
                }
            }];
    }
}

//------------------------------------------------------------------------------

- (void) setIcon:(UIImage*)image
{
    UIImageView *icon                  
        = (UIImageView*)[self.view viewWithTag:kTagIcon];
    UIActivityIndicatorView *spinner 
        = (UIActivityIndicatorView*)[self.view viewWithTag:kTagIconActivity];

    // update icon 
    icon.image  = image;
    icon.hidden = image == nil;

    // update spinner
    if (image) {
        [spinner stopAnimating];
    } else {
        [spinner startAnimating];
    }
}

//------------------------------------------------------------------------------

- (void) setupMap
{
    // center map 
    CLLocationCoordinate2D coordinate;
    coordinate.latitude  = [self.coupon.merchant.latitude doubleValue];
    coordinate.longitude = [self.coupon.merchant.longitude doubleValue];
    MKMapView *map       = (MKMapView*)[self.view viewWithTag:kTagMap];
    map.centerCoordinate = coordinate;

    // set zoom
    MKCoordinateRegion viewRegion =
        MKCoordinateRegionMakeWithDistance(coordinate, 100, 100);
    MKCoordinateRegion adjustedRegion = [map regionThatFits:viewRegion];                
    [map setRegion:adjustedRegion animated:NO]; 

    // add pin 
    MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
    pin.coordinate         = coordinate;
    [map addAnnotation:pin];
    [pin release];
}

//------------------------------------------------------------------------------

- (void) startTimer
{
    // setup timer
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(updateTimers)
                                                userInfo:nil
                                                 repeats:YES];
}

//------------------------------------------------------------------------------

- (void) updateTimers
{
    // color timer
    GradientView *color = (GradientView*)[self.view viewWithTag:kTagColorTimer];
    color.color         = [self.coupon getColor];

    // text timer
    UILabel *label = (UILabel*)[self.view viewWithTag:kTagTextTimer];
    label.text     = [self.coupon getExpirationTimer];

    // kill timer if coupon is expired
    if ([self.coupon isExpired]) [self.timer invalidate];
}

//------------------------------------------------------------------------------
#pragma - ActionSheet delegate
//------------------------------------------------------------------------------

- (void) actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case kActionButtonSMS:
            [self shareSMS];
            break;
        case kActionButtonEmail:
            [self shareEmail];
            break;
        default:
            break;
    }
}

//------------------------------------------------------------------------------
#pragma - Mail delegate
//------------------------------------------------------------------------------

- (void) mailComposeController:(MFMailComposeViewController*)controller 
           didFinishWithResult:(MFMailComposeResult)result 
                         error:(NSError*)error 
{
    switch (result) {
        case MFMailComposeResultSaved:
            break;
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
            NSLog(@"CouonDetailViewController: email failed: %@", error);
            break;
        default:
            break;
    }

    // dismiss controller
    [self dismissModalViewControllerAnimated:YES];
}

//------------------------------------------------------------------------------
#pragma - SMS delegate
//------------------------------------------------------------------------------

- (void) messageComposeViewController:(MFMessageComposeViewController*)controller 
                  didFinishWithResult:(MessageComposeResult)result
{
    switch (result) {
        case MessageComposeResultSent:
            break;
        case MessageComposeResultFailed:
            NSLog(@"CouonDetailViewController: sms failed.");
            break;
        default:
            break;
    }

    // dismiss controller
    [self dismissModalViewControllerAnimated:YES];
}

//------------------------------------------------------------------------------
#pragma - Events
//------------------------------------------------------------------------------

- (IBAction) merchantDetails:(id)sender
{
    MerchantViewController *merchantViewController = [[MerchantViewController alloc] 
        initWithNibName:@"MerchantViewController" bundle:nil];

    // set merchant to view
    merchantViewController.merchant = self.coupon.merchant;

    // pass the selected object to the new view controller.
    [self.navigationController pushViewController:merchantViewController animated:YES];
    [merchantViewController release];
}

//------------------------------------------------------------------------------

- (IBAction) redeemCoupon:(id)sender
{
    [self arrangeSubviewsForRedeemedCouponWithAnimation:true];
    self.coupon.wasRedeemed = YES;
}

//------------------------------------------------------------------------------

- (void) resetSubviews
{
    // grab subviews
    UIView *titleView    = [self.view viewWithTag:kTagTitleBar];
    UIView *barcodeView  = [self.view viewWithTag:kTagBarcodeView];
    UIView *contentView  = [self.view viewWithTag:kTagContentView];

    // already in default state if barcode is hidden
    if (barcodeView.hidden) return;

    // hide barcode
    barcodeView.hidden = YES;

    // position contentview back to original position
    CGRect barcodeFrame            = barcodeView.frame;
    CGRect titleViewFrameNew       = titleView.frame;
    CGRect contentViewFrameNew     = contentView.frame;
    contentViewFrameNew.origin.x   = barcodeFrame.origin.x;
    contentViewFrameNew.origin.y   = barcodeFrame.origin.y;
    contentView.frame              = contentViewFrameNew;
    titleViewFrameNew.size.height -= barcodeFrame.size.height;
    titleView.frame                = titleViewFrameNew;
}

//------------------------------------------------------------------------------

- (void) arrangeSubviewsForRedeemedCouponWithAnimation:(bool)animated
{
    // grab subviews
    __block UIView *titleView        = [self.view viewWithTag:kTagTitleBar];
    __block UIView *barcodeView      = [self.view viewWithTag:kTagBarcodeView];
    __block UIView *contentView      = [self.view viewWithTag:kTagContentView];

    // already configured correctly if barcode is visible
    if (!barcodeView.hidden) return;
    
    // make sure barcode view is visible
    barcodeView.hidden = NO;

    // grab the current values of the views
    CGRect contentFrame = contentView.frame;
    CGRect barcodeFrame = self.barcodeView.frame;
    CGSize barcodeSize  = self.barcodeView.frame.size;
    CGRect titleFrame   = titleView.frame;

    // calculate the title bar height
    __block CGRect titleFrameNew = titleFrame;
    titleFrameNew.size.height   += barcodeSize.height;

    // position the barcode view at title bar bottom and null out height
    barcodeFrame.origin.x    = titleFrame.origin.x; 
    barcodeFrame.origin.y    = titleFrame.origin.y + titleFrame.size.height;;
    barcodeFrame.size.height = 0.1;
    barcodeView.frame        = barcodeFrame;

    // calculate the new position for the content view
    __block CGRect contentFrameNew = contentFrame;
    contentFrameNew.origin.y      += barcodeSize.height;
    
        // calcuate the new size for the barcode
    __block CGRect barcodeFrameNew = barcodeFrame;
    barcodeFrameNew.size.height    = barcodeSize.height;

    // fix up scroll view to account for text view content
    UIScrollView *scrollView = (UIScrollView*)[self.view viewWithTag:kTagScrollView];
    CGSize contentSize       = scrollView.contentSize;
    contentSize.height      += barcodeSize.height;
    scrollView.contentSize   = contentSize;

    // animate new views into place
    void (^animationBlock)(void) = ^{
        contentView.frame = contentFrameNew;
        barcodeView.frame = barcodeFrameNew;
        titleView.frame   = titleFrameNew;
    };
    
    // update the subviews
    if (animated) {
        [UIView animateWithDuration:0.4 animations:animationBlock];
        [self.navigationController setToolbarHidden:YES animated:YES];
    } else {
        animationBlock();
        [self.navigationController setToolbarHidden:YES animated:NO];
    }
}

//------------------------------------------------------------------------------

- (IBAction) shareTwitter:(id)sender
{
    NSString *title   = @"Not Implemented";
    NSString *message = @"Sharing on twitter is no yet implemented. Try again next build!";
    [Utilities displaySimpleAlertWithTitle:title
                                andMessage:message];
}

//------------------------------------------------------------------------------

- (IBAction) shareFacebook:(id)sender
{
    NSString *title   = @"Not Implemented";
    NSString *message = @"Sharing on facebook is no yet implemented. Try again next build!";
    [Utilities displaySimpleAlertWithTitle:title
                                andMessage:message];
}

//------------------------------------------------------------------------------

- (IBAction) shareMore:(id)sender
{
    UIActionSheet *actionSheet = 
        [[UIActionSheet alloc] initWithTitle:@"Share Deal"
                                    delegate:self 
                           cancelButtonTitle:@"Cancel" 
                      destructiveButtonTitle:nil
                           otherButtonTitles:@"SMS", @"Email", nil];

    // show from toolbar only if coupon not yet redeemed
    if (self.coupon.wasRedeemed) {
        [actionSheet showInView:self.view];
    } else {
        [actionSheet showFromToolbar:self.navigationController.toolbar];
    }

    // cleanup
    [actionSheet release];
}

//------------------------------------------------------------------------------

- (void) shareEmail
{
    // only send email if supported by the device
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *controller = 
            [[MFMailComposeViewController alloc] init];

        // present the email controller
        NSString *deal = $string(@"%@ at %@", self.coupon.title, self.coupon.merchant.name);
        controller.mailComposeDelegate = self;
        [controller setSubject:@"Checkout this amazing deal on TikTok!"];
        [controller setMessageBody:$string(@"%@", deal) isHTML:NO];
        [self presentModalViewController:controller animated:YES];

        // cleanup
        [controller release];

    // let user know email is not possible on this device
    } else {
        NSString *title   = NSLocalizedString(@"DEVICE_SUPPORT", nil);
        NSString *message = NSLocalizedString(@"EMAIL_NO_SUPPORTED", nil);
        [Utilities displaySimpleAlertWithTitle:title
                                    andMessage:message];
    }
}

//------------------------------------------------------------------------------

- (void) shareSMS
{
    // only send text if supported by the device
    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *controller = 
            [[MFMessageComposeViewController alloc] init];

        // present sms controller
        NSString *deal  = $string(@"%@ at %@", self.coupon.title, self.coupon.merchant.name);
        controller.body = $string(@"Checkout this amazing deal on TikTok: %@!", deal);
        controller.messageComposeDelegate = self;
        [self presentModalViewController:controller animated:YES];

        // cleanup
        [controller release];

    // let user know sms is not possible on this device...   
    } else {
        NSString *title   = NSLocalizedString(@"DEVICE_SUPPORT", nil);
        NSString *message = NSLocalizedString(@"SMS_NO_SUPPORTED", nil);
        [Utilities displaySimpleAlertWithTitle:title
                                    andMessage:message];
    }
}

//------------------------------------------------------------------------------
#pragma - Memory Management
//------------------------------------------------------------------------------

/** 
 * Releases the view if it doesn't have a superview.
 */
- (void) didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning];
}

//------------------------------------------------------------------------------

/**
 * Release any retained subviews of the main view.
 */
- (void) viewDidUnload 
{
    [super viewDidUnload];
}

//------------------------------------------------------------------------------

- (void) dealloc 
{
    [mTimer invalidate];
    [mTimer release];
    [mRedeemButton release];
    [mBarcodeView release];
    [mCoupon release];
    [super dealloc];
}

//------------------------------------------------------------------------------

@end
