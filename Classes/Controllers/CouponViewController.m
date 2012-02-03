//
//  CouponViewController.m
//  TikTok
//
//  Created by Moiz Merchant on 4/19/11.
//  Copyright 2011 TikTok. All rights reserved.
//

//------------------------------------------------------------------------------
// imports
//------------------------------------------------------------------------------

#import "Coupon.h"
#import "CouponViewController.h"
#import "CouponTableViewCell.h"
#import "CouponDetailViewController.h"
#import "Database.h"
#import "GradientView.h"
#import "IconManager.h"
#import "Merchant.h"
#import "Settings.h"
#import "TikTokApi.h"
#import "UIDefaults.h"

//------------------------------------------------------------------------------
// enums
//------------------------------------------------------------------------------

enum CouponTag {
    kTagIcon           =  1,
    kTagTitle          =  2,
    kTagTextTime       =  3,
    kTagTextTimer      =  4,
    kTagColorTimer     =  5,
    kTagIconActivity   =  6,
    kTagRedeemedSash   =  7,
    kTagCompanyName    =  8,
    kTagBackground     =  9,
};

//------------------------------------------------------------------------------
// interface definition 
//------------------------------------------------------------------------------

@interface CouponViewController ()
    - (void) setupRefreshHeader;
    - (void) setupFilterButtons;
    - (void) updateExpiration:(NSTimer*)timer;
    - (void) configureCell:(UIView*)cell atIndexPath:(NSIndexPath*)indexPath;
    - (void) configureExpiredCell:(UIView*)cell;
    - (void) configureActiveCell:(UIView*)cell withCoupon:(Coupon*)coupon;
    - (void) updateActiveCell:(UIView*)cell withCoupon:(Coupon*)coupon;
    - (void) setIcon:(UIImage*)image forCell:(UIView*)cell;
    - (void) setupIconForCell:(UIView*)cell atIndexPath:(NSIndexPath*)indexPath withCoupon:(Coupon*)coupon;
    - (void) requestImageForCoupon:(Coupon*)coupon atIndexPath:(NSIndexPath*)indexPath;
    - (void) loadImagesForOnscreenRows;
    - (void) reloadTableViewDataSource;
    - (void) syncManagedObjects:(NSNotification*)notification;
    - (void) doneLoadingTableViewData;
    - (void) updateFilterByReedmeedOnly:(bool)redeemedOnly activeOnly:(bool)activeOnly;
    - (void) filterDealsRedeemd;
    - (void) filterDealsActive;
@end 

//------------------------------------------------------------------------------
// interface implementation
//------------------------------------------------------------------------------

@implementation CouponViewController

//------------------------------------------------------------------------------

@synthesize cellView                 = mCellView;
@synthesize tableView                = mTableView;
@synthesize fetchedCouponsController = mFetchedCouponsController;

//------------------------------------------------------------------------------
#pragma mark - View lifecycle
//------------------------------------------------------------------------------

/**
 * Only runs after view is loaded.
 */
- (void) viewDidLoad
{
    [super viewDidLoad];

    // set title
    self.title = @"Deals";

    // patch font in cell
    UILabel *timer = (UILabel*)[self.cellView viewWithTag:kTagTextTimer];
    timer.font     = [UIFont fontWithName:@"NeutraDisp-BoldAlt" size:19];

    // tag testflight checkpoint
    [TestFlight passCheckpoint:@"Deals"];

    // add navitems
    [self setupFilterButtons];

    // setup the refresh header
    [self setupRefreshHeader];

    mReloading = false;
}

//------------------------------------------------------------------------------

- (void) setupRefreshHeader
{
    // make sure reload header is not already loaded 
    if (!mRefreshHeaderView) {
        CGRect frame;
        frame.origin.x    = 0.0;
        frame.origin.y    = -self.tableView.bounds.size.height;
        frame.size.width  = self.view.frame.size.width;
        frame.size.height = self.tableView.bounds.size.height;

        // setup a new header view 
        EGORefreshTableHeaderView *headerView = 
            [[EGORefreshTableHeaderView alloc] initWithFrame:frame
                                              arrowImageName:@"Tik.png"
                                                   textColor:[UIColor brownColor]];  
        headerView.delegate = self;

        // add a background image
        CGRect backgroundFrame  = CGRectMake(0.0f, 0.0f, 
                                             frame.size.width, frame.size.height); 
        UIImageView *background = [[UIImageView alloc] initWithFrame:backgroundFrame]; 
        background.image        = [UIImage imageNamed:@"CouponDetailBackgroundTexture.png"];
        [headerView insertSubview:background atIndex:0];

        // add to table
        [self.tableView addSubview:headerView];

        // save pointer
        mRefreshHeaderView = [headerView retain];

        // cleanup
        [headerView release];
        [background release];
    }
    
    //  update the last update date
    [mRefreshHeaderView refreshLastUpdatedDate];
}

//------------------------------------------------------------------------------

- (void) setupFilterButtons
{
    // add redeemed filter
    UIBarButtonItem *redeemedButton = 
        [[UIBarButtonItem alloc] initWithTitle:@"Redeemed"
                                         style:UIBarButtonItemStyleBordered 
                                        target:self 
                                        action:@selector(filterDealsRedeemd)];
    redeemedButton.tintColor = [UIDefaults getTokColor];

    // add active filter
    UIBarButtonItem *activeButton = 
        [[UIBarButtonItem alloc] initWithTitle:@"Active"
                                         style:UIBarButtonItemStyleBordered 
                                         target:self 
                                         action:@selector(filterDealsActive)];
    activeButton.tintColor = [UIDefaults getTokColor];

    // setup the toolbar
    UIToolbar *miniToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 147, 44)];
    [miniToolbar setItems:$array(redeemedButton, activeButton) animated:YES];
    miniToolbar.barStyle = -1;

    // add as right navigation item
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:miniToolbar];
    self.navigationItem.rightBarButtonItem = rightItem;

    // cleanup
    [redeemedButton release];
    [activeButton release];
    [miniToolbar release];
    [rightItem release];
}

//------------------------------------------------------------------------------

- (void) viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];

    // deselect selected rows
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

//------------------------------------------------------------------------------

/*
- (void) viewDidAppear:(BOOL)animated 
{
    [super viewDidAppear:animated];
}
*/

//------------------------------------------------------------------------------

/*
- (void) viewWillDisappear:(BOOL)animated 
{
    [super viewWillDisappear:animated];
}
*/

//------------------------------------------------------------------------------

/*
- (void) viewDidDisappear:(BOOL)animated 
{
    [super viewDidDisappear:animated];
}
*/

//------------------------------------------------------------------------------

/**
 * Override to allow orientations other than the default portrait orientation.
 * /
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

//------------------------------------------------------------------------------
#pragma mark - Table view data source
//------------------------------------------------------------------------------

/**
 * Customize the number of sections in the table view.
 */
- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView 
{
    // currently all the coupons are grouped together in one section
    return 1;
}

//------------------------------------------------------------------------------

/**
 * Customize the number of rows in the table view.
 */ 
- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section 
{
    id <NSFetchedResultsSectionInfo> sectionInfo = 
        [[self.fetchedCouponsController sections] objectAtIndex:section];
    NSInteger objectCount = [sectionInfo numberOfObjects];
    return objectCount;
}

//------------------------------------------------------------------------------

/**
 * Customize the height of the cell at the given index.
 */ 
- (CGFloat) tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
    // use the height from the cell view prototype
    return self.cellView.contentView.frame.size.height;
}

//------------------------------------------------------------------------------

/**
 * Customize the appearance of table view cells.
 */
- (UITableViewCell*) tableView:(UITableView*)tableView 
         cellForRowAtIndexPath:(NSIndexPath*)indexPath 
{
    static NSString *sCellId = @"coupon_cell";
    
    // only create as many coupons as are in view at the same time
    CouponTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:sCellId];
    if (cell == nil) {
        NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:self.cellView];
        cell = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
        cell.selectionStyle  = UITableViewCellSelectionStyleBlue;
    }

    // configure the cell 
    [self configureCell:cell atIndexPath:indexPath];

    return cell;
}

//------------------------------------------------------------------------------

/**
 * Override to support conditional editing of the table view.
 */
- (BOOL) tableView:(UITableView*)tableView canEditRowAtIndexPath:(NSIndexPath*)indexPath 
{
    // table rows are not editable
    return NO;
}

//------------------------------------------------------------------------------

/**
 * Override to support editing the table view.
 * /
- (void) tableView:(UITableView*)tableView 
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
     forRowAtIndexPath:(NSIndexPath*)indexPath 
{
    
    // delete the row from the data source.
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                         withRowAnimation:UITableViewRowAnimationFade];

    // create a new instance of the appropriate class, insert it into the array, 
    //  and add a new row to the table view.
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
    }   
}
*/

//------------------------------------------------------------------------------

/**
 * Override to support rearranging the table view.
 */
- (void) tableView:(UITableView*)tableView 
    moveRowAtIndexPath:(NSIndexPath*)fromIndexPath 
           toIndexPath:(NSIndexPath*)toIndexPath 
{
    // items cannot be moved
}

//------------------------------------------------------------------------------

/**
 * Override to support conditional rearranging of the table view.
 */
- (BOOL) tableView:(UITableView*)tableView canMoveRowAtIndexPath:(NSIndexPath*)indexPath 
{
    // items cannot be re-ordered
    return NO;
}

//------------------------------------------------------------------------------
#pragma mark - Cell Configuration
//------------------------------------------------------------------------------

/**
 * Initializes cell with coupon information.
 */
- (void) configureCell:(CouponTableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
    // grab coupon at the given index path
    Coupon* coupon = [self.fetchedCouponsController objectAtIndexPath:indexPath];

    // set coupon on cell
    cell.coupon = coupon;

    // invaliate the timer
    [cell.timer invalidate];

    // update the company name
    UILabel *company = (UILabel*)[cell viewWithTag:kTagCompanyName];
    [company setText:[coupon.merchant.name uppercaseString]];

    // update the coupon headline
    UILabel *headline = (UILabel*)[cell viewWithTag:kTagTitle];
    [headline setText:[coupon.title capitalizedString]];

    // setup icon
    [self setupIconForCell:cell atIndexPath:indexPath withCoupon:coupon];

    // configure redeemed sash
    UIImageView* sash = (UIImageView*)[cell viewWithTag:kTagRedeemedSash];
    sash.hidden       = !coupon.wasRedeemed;

    // update the cell to reflect the state of the coupon
    if ([coupon isExpired]) {
        [self configureExpiredCell:cell];
    } else {
        [self configureActiveCell:cell withCoupon:coupon];

        // create update loop for timers
        cell.timer = [NSTimer timerWithTimeInterval:1.0
                                             target:self
                                          selector:@selector(updateExpiration:)
                                          userInfo:cell
                                           repeats:YES];

        // add timer to the main loop
        [[NSRunLoop mainRunLoop] addTimer:cell.timer forMode:NSRunLoopCommonModes];
    }
}

//------------------------------------------------------------------------------

- (void) updateExpiration:(NSTimer*)timer
{
    // grab coupon at the given index path
    CouponTableViewCell* cell = (CouponTableViewCell*)timer.userInfo;
    Coupon *coupon            = cell.coupon;
    if (coupon == nil) return;

    /* only update the view if its visibile
    UIView *view = [cell viewWithTag:kTagTextTime];
    CGRect rect  = [view convertRect:view.frame toView:self.view.superview];
    bool visible = CGRectIntersectsRect(self.view.superview.frame, rect);
    if (!visible) return;
    */

    // update the cell to reflect the state of the coupon
    if ([coupon isExpired]) {
        [timer invalidate];
        [UIView animateWithDuration:0.25 animations:^{
            [self configureExpiredCell:cell];
        }];
    } else {
        [self updateActiveCell:cell withCoupon:coupon];
    }
}

//------------------------------------------------------------------------------

- (void) configureExpiredCell:(UIView*)cell
{
    const static CGFloat expiredAlpha = 0.4;
    static NSString *offerText        = @"Offer is no longer available.";
    static NSString *timerText        = @"TIMES UP!";

    // expire text
    UILabel *textTime  = (UILabel*)[cell viewWithTag:kTagTextTime];
    textTime.text      = offerText;
    textTime.textColor = [UIColor redColor];

    // expire timer
    UILabel *textTimer  = (UILabel*)[cell viewWithTag:kTagTextTimer];
    textTimer.text      = timerText;

    // color timer
    GradientView *color = (GradientView*)[cell viewWithTag:kTagColorTimer];
    color.color         = [UIDefaults getTokColor];

    // update the cell opacity
    for (UIView *view in cell.subviews) {
        if (view.tag != kTagBackground) {
            view.alpha = expiredAlpha;
        }
    }
}

//------------------------------------------------------------------------------

- (void) configureActiveCell:(UIView*)cell withCoupon:(Coupon*)coupon 
{
    // fix the opacity
    for (UIView *view in cell.subviews) {
        if (view.tag != kTagBackground) {
            view.alpha = 1.0;
        }
    }

    // expire time
    UILabel *expire  = (UILabel*)[cell viewWithTag:kTagTextTime];
    expire.text      = $string(@"Offer expires at %@", [coupon getExpirationTime]);
    expire.textColor = [(UILabel*)[self.cellView viewWithTag:kTagTextTime] textColor];

    // configure the timers
    [self updateActiveCell:cell withCoupon:coupon];
}

//------------------------------------------------------------------------------

- (void) updateActiveCell:(UIView*)cell withCoupon:(Coupon*)coupon 
{
    // color timer
    GradientView *color = (GradientView*)[cell viewWithTag:kTagColorTimer];
    color.color         = [coupon getColor];

    // text timer
    UILabel *label = (UILabel*)[cell viewWithTag:kTagTextTimer];
    label.text     = [coupon getExpirationTimer];
}

//------------------------------------------------------------------------------

- (void) setupIconForCell:(UIView*)cell 
              atIndexPath:(NSIndexPath*)indexPath 
               withCoupon:(Coupon*)coupon
{
    IconManager *iconManager = [IconManager getInstance];
    __block UIImage *image   = [iconManager getImage:coupon.iconData];

    // set merchant icon
    [self setIcon:image forCell:cell];

    // load image from server if table is not moving
    if (!image && !self.tableView.dragging && !self.tableView.decelerating) {
        [self requestImageForCoupon:coupon atIndexPath:indexPath];
    }
}

//------------------------------------------------------------------------------

- (void) setIcon:(UIImage*)image forCell:(UIView*)cell
{
    UIImageView *icon                  
        = (UIImageView*)[cell viewWithTag:kTagIcon];
    UIActivityIndicatorView *spinner 
        = (UIActivityIndicatorView*)[cell viewWithTag:kTagIconActivity];

    // update icon 
    icon.image  = image;
    icon.hidden = image == nil;
    icon.alpha  = image == nil ? 0.0f : 1.0f;

    // update spinner
    if (image) {
        [spinner stopAnimating];
    } else {
        [spinner startAnimating];
    }
}

//------------------------------------------------------------------------------
#pragma mark - TableView Delegate
//------------------------------------------------------------------------------

- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath 
{
    // [moiz] this should be cached in some way, causes animation hitch eveytime
    //  it loads...
    CouponDetailViewController *detailViewController = [[CouponDetailViewController alloc] 
        initWithNibName:@"CouponDetailViewController" bundle:nil];

    // grab coupon at the given index path
    Coupon* coupon = [self.fetchedCouponsController objectAtIndexPath:indexPath];
        
    // set coupon to view
    [detailViewController setCoupon:coupon];

    // pass the selected object to the new view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
    [detailViewController release];
}

//------------------------------------------------------------------------------

/**
 * Customize the appearance of the table header.
- (UIView*) tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section
{
}
*/

//------------------------------------------------------------------------------

/**
 * Customize the height of the header.
 */
- (CGFloat) tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section
{
    // no headers should be visible
    return 0.0;
}

//------------------------------------------------------------------------------

- (void) requestImageForCoupon:(Coupon*)coupon atIndexPath:(NSIndexPath*)indexPath
{
    // submit the request to retrive the image and update the cell
    IconManager *iconManager = [IconManager getInstance];
    [iconManager requestImage:coupon.iconData 
        withCompletionHandler:^(UIImage* image, NSError *error) {
            if (image) {
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                [UIView animateWithDuration:0.2 animations:^{
                    [self setIcon:image forCell:cell];
                }];
            } else if (error) {
                NSLog(@"CouponViewController: Failed to load image: %@", error);
            }
        }];
}

//------------------------------------------------------------------------------

- (void) loadImagesForOnscreenRows
{
    NSArray *visibleIndices  = [self.tableView indexPathsForVisibleRows];
    IconManager *iconManager = [IconManager getInstance];

    [visibleIndices enumerateObjectsUsingBlock:
        ^(NSIndexPath *indexPath, NSUInteger index, BOOL *stop) {
            Coupon *coupon = [self.fetchedCouponsController objectAtIndexPath:indexPath];
            UIImage *image = [iconManager getImage:coupon.iconData];
            if (image == nil) {
                [self requestImageForCoupon:coupon atIndexPath:indexPath];
            }
        }];
}

//------------------------------------------------------------------------------
#pragma mark - Fetched Results Controller
//------------------------------------------------------------------------------

- (NSFetchedResultsController*) fetchedCouponsController
{
    // check if controller already created
    if (mFetchedCouponsController) {
        return mFetchedCouponsController;
    }

    NSManagedObjectContext *context = [[Database getInstance] context];

    // create an entity description object
    NSEntityDescription *description = [NSEntityDescription 
        entityForName:@"Coupon" inManagedObjectContext:context];
                                                   
    // create a sort descriptor
    NSSortDescriptor *sortByEndDate = [[NSSortDescriptor alloc] 
        initWithKey:@"endTime" ascending:NO];

    // create a fetch request
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity          = description;
    request.fetchBatchSize  = 10;
    request.sortDescriptors = $array(sortByEndDate);

    // create a results controller from the request
    NSFetchedResultsController *fetchedCouponsController = 
        [[NSFetchedResultsController alloc] initWithFetchRequest:request 
                                            managedObjectContext:context 
                                              sectionNameKeyPath:nil
                                                       cacheName:@"coupon_table"];

    // save the controller
    self.fetchedCouponsController          = fetchedCouponsController;
    self.fetchedCouponsController.delegate = self;

    // preform the fetch
    NSError *error = nil;
    if (![self.fetchedCouponsController performFetch:&error]) {
        NSLog(@"Fetching of coupons failed: %@, %@", error, [error userInfo]);
        abort();
    }

    // cleanup
    [request release];
    [sortByEndDate release];
    [fetchedCouponsController release];

    return mFetchedCouponsController;
}

//------------------------------------------------------------------------------
#pragma mark - Fetched Results Controller Delegates
//------------------------------------------------------------------------------

- (void) controllerWillChangeContent:(NSFetchedResultsController*)controller
{
    [self.tableView beginUpdates];
}

//------------------------------------------------------------------------------

- (void) controller:(NSFetchedResultsController*)controller 
   didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo 
            atIndex:(NSUInteger)sectionIndex 
      forChangeType:(NSFetchedResultsChangeType)type
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] 
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] 
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

//------------------------------------------------------------------------------

- (void) controller:(NSFetchedResultsController*)controller 
    didChangeObject:(id)object 
        atIndexPath:(NSIndexPath*)indexPath 
      forChangeType:(NSFetchedResultsChangeType)type 
       newIndexPath:(NSIndexPath*)newIndexPath 
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                                  withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] 
                                  withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

//------------------------------------------------------------------------------

- (void) controllerDidChangeContent:(NSFetchedResultsController*)controller 
{
    [self.tableView endUpdates];
}

//-----------------------------------------------------------------------------
#pragma mark - ScrollView Delegates
//-----------------------------------------------------------------------------

- (void) scrollViewDidScroll:(UIScrollView*)scrollView 
{
    [mRefreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

//-----------------------------------------------------------------------------

- (void) scrollViewDidEndDragging:(UIScrollView*)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) [self loadImagesForOnscreenRows];
    [mRefreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

//-----------------------------------------------------------------------------

- (void) scrollViewDidEndDecelerating:(UIScrollView*)scrollView
{
    [self loadImagesForOnscreenRows];
}

//------------------------------------------------------------------------------
#pragma mark - EGORefreshTableHeader Delegate 
//------------------------------------------------------------------------------

- (void) egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
    [self reloadTableViewDataSource];
}

//------------------------------------------------------------------------------

- (BOOL) egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view 
{
    return mReloading; 
}

//------------------------------------------------------------------------------

- (NSDate*) egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view 
{
    return [NSDate date];
}

//------------------------------------------------------------------------------
#pragma mark - Data Source Loading / Reloading Methods
//------------------------------------------------------------------------------

- (void) reloadTableViewDataSource 
{
    // don't try to reload twice
    if (mReloading) return;

    mReloading = YES;

    // setup api object
    NSDate *lastUpdate     = [NSDate date];
    __block TikTokApi *api = [[[TikTokApi alloc] init] autorelease];
    api.completionHandler  = ^(ASIHTTPRequest *request) {

        // remove self from notification center
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter removeObserver:self];

        // end transaction
        [self doneLoadingTableViewData];

        // update last synced time
        [[Settings getInstance] setLastUpdate:lastUpdate];
    };

    // remove notification and close header
    api.errorHandler = ^(ASIHTTPRequest *request) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter removeObserver:self];
        [self doneLoadingTableViewData];
    };

    // add a notification to allow syncing the contexts..
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(syncManagedObjects:)
                               name:NSManagedObjectContextDidSaveNotification
                             object:api.context];

    // sync coupons
    Settings *settings = [Settings getInstance];
    [api syncActiveCoupons:settings.lastUpdate];
}

//------------------------------------------------------------------------------

- (void) syncManagedObjects:(NSNotification*)notification
{
    Database *database = [Database getInstance];
    [database.context mergeChangesFromContextDidSaveNotification:notification];
}

//------------------------------------------------------------------------------

- (void) doneLoadingTableViewData 
{
    mReloading = NO;
    [mRefreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}

//------------------------------------------------------------------------------
#pragma mark - table sorting / filtering
//------------------------------------------------------------------------------

- (void) updateFilterByReedmeedOnly:(bool)redeemedOnly activeOnly:(bool)activeOnly
{
    NSPredicate *predicate = nil;
    if (redeemedOnly && activeOnly) {
        predicate = [NSPredicate predicateWithFormat:
            @"wasRedeemed == %@ && endTime > %@", $numb(YES), [NSDate date]];
    } else if (redeemedOnly) {
        predicate = [NSPredicate predicateWithFormat:
            @"wasRedeemed == %@", $numb(YES)];
    } else if (activeOnly) {
        predicate = [NSPredicate predicateWithFormat:
            @"endTime > %@", [NSDate date]];
    } 

    // clear the cache
    [NSFetchedResultsController deleteCacheWithName:@"coupon_table"];

    // update the fetch request
    NSFetchRequest *request = self.fetchedCouponsController.fetchRequest; 
    request.predicate       = predicate;

    // update the request in the fetch controller
    NSError *error = nil;
    if (![self.fetchedCouponsController performFetch:&error]) {
        NSLog(@"CouponViewController: Fetching of coupons failed: %@, %@", 
            error, [error userInfo]);
    }

    // reload the new data
    [self.tableView reloadData];
}

//------------------------------------------------------------------------------

- (void) filterDealsRedeemd
{
    UIToolbar *toolbar = (UIToolbar*)self.navigationItem.rightBarButtonItem.customView;

    // grab the filter buttons
    UIBarButtonItem *redeemedButton = (UIBarButtonItem*)[toolbar.items objectAtIndex:0];
    UIBarButtonItem *activeButton   = (UIBarButtonItem*)[toolbar.items objectAtIndex:1];

    // calculate the new states
    bool redeemedOnly = ![redeemedButton.tintColor isEqual:[UIDefaults getTikColor]];
    bool activeOnly   = [activeButton.tintColor isEqual:[UIDefaults getTikColor]];

    // update the color
    redeemedButton.tintColor = redeemedOnly ? 
        [UIDefaults getTikColor] : [UIDefaults getTokColor];;

    [self updateFilterByReedmeedOnly:redeemedOnly activeOnly:activeOnly];
}

//------------------------------------------------------------------------------

- (void) filterDealsActive
{
    UIToolbar *toolbar = (UIToolbar*)self.navigationItem.rightBarButtonItem.customView;

    // grab the filter buttons
    UIBarButtonItem *redeemedButton = (UIBarButtonItem*)[toolbar.items objectAtIndex:0];
    UIBarButtonItem *activeButton   = (UIBarButtonItem*)[toolbar.items objectAtIndex:1];

    // calculate the new states
    bool redeemedOnly = [redeemedButton.tintColor isEqual:[UIDefaults getTikColor]];
    bool activeOnly   = ![activeButton.tintColor isEqual:[UIDefaults getTikColor]];

    // update the color
    activeButton.tintColor = activeOnly ? 
        [UIDefaults getTikColor] : [UIDefaults getTokColor];;

    [self updateFilterByReedmeedOnly:redeemedOnly activeOnly:activeOnly];
}

//------------------------------------------------------------------------------
#pragma mark - Memory Management
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
 * Relinquish ownership of anything that can be recreated in viewDidLoad 
 * or on demand.
 */
- (void) viewDidUnload 
{
    // for example: self.myOutlet = nil;
}

//------------------------------------------------------------------------------

- (void) dealloc 
{
    mFetchedCouponsController.delegate = nil;
    [mFetchedCouponsController release];
    [mRefreshHeaderView release];
    [mTableView release];
    [mCellView release];
    [super dealloc];
}

//------------------------------------------------------------------------------

@end

