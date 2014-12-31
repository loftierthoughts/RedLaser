/*******************************************************************************
	RLSampleViewController.m
	
	This is the view controller for the results table.
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/

#import "RLSampleViewController.h"
#import "RedLaserSDK.h"

static void RLSampleViewControllerRequestVideoAuthorization(dispatch_block_t completionHandler) {
    
    RL_RequestVideoAuthorization(^void (RL_VideoAuthorizationStatus status) {
        
        if (status == RL_VideoAuthorizationStatusAuthorized) {
            
            dispatch_async(dispatch_get_main_queue(), ^void (void) {
                
                completionHandler();
                
            });
            
        }
        
    });
    
}

@interface RLSampleViewController ()
- (void) appBecameActive:(NSNotification *) notification;

@end


@implementation RLSampleViewController

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{	
		// Load in any saved scan history we may have
		@try {
    		NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
				NSUserDomainMask, YES) objectAtIndex:0];
			NSString *archivePath = [documentsDir stringByAppendingPathComponent:@"ScanHistoryArchive"];
			scanHistory = [[NSKeyedUnarchiver unarchiveObjectWithFile:archivePath] retain];
		}
		@catch (...) 
		{
    	}
		if (!scanHistory)
			scanHistory = [[NSMutableArray alloc] init];

		// We create the singleScan BarcodePickerController2 here to demonstrate calling
		// prepareToScan before the user actually requests a scan.
		singleScanPickerController = [[SingleScanPickerController alloc] init];
		[singleScanPickerController setDelegate:self];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecameActive:) 
				name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	
	return self;
}

- (void) dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[scanHistory release];
	[singleScanPickerController release];
	[scanHistoryTable release];
	[firstTimeView release];
	[appNameAndVersionLabel release];
	
	[super dealloc];
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	// Put the SDK version in the titlebar
	appNameAndVersionLabel.text = [NSString stringWithFormat:@"RLSample %@", 
			RL_GetRedLaserSDKVersion()];

	// This call initializes the camera and gets it ready to scan, so that when the
	// user presses the scan button, they'll start scanning immediately instead of
	// having to wait. However, we put the camera on a timer, so that it'll turn itself
	// off after 20 seconds if the user doesn't start a scan.
	[singleScanPickerController prepareToScan];
	
	// We have a view with some static text that describes the sample app. Show
	// this view only when there's no scans in the list.
	[firstTimeView setHidden:[scanHistory count] != 0];
	
	// Set up the app info string that goes inside the firstTimeView
	RedLaserStatus sdkStatus = RL_CheckReadyStatus();
	NSString *sdkStatusString = nil;
	switch (sdkStatus)
	{
		case RLState_EvalModeReady: sdkStatusString = @"Eval Mode Ready"; break;
		case RLState_LicensedModeReady: sdkStatusString = @"Licensed Mode Ready"; break;
		case RLState_MissingOSLibraries: sdkStatusString = @"Missing OS Libs"; break;
		case RLState_NoCamera: sdkStatusString = @"No Camera"; break;
		case RLState_BadLicense: sdkStatusString = @"Bad License"; break;
		case RLState_ScanLimitReached: sdkStatusString = @"Scan Limit Reached"; break;
        case RLState_NoVideoAuthorization: sdkStatusString = @"No Video Authorization"; break;
		default: sdkStatusString = @"Unknown"; break;
	}

	NSString *appInfoString = [NSString stringWithFormat:@"Version: %@\nLicense Status: %@",
			RL_GetRedLaserSDKVersion(), sdkStatusString];
	[appInfoLabel setText:appInfoString];
}

- (void) viewDidUnload 
{
	[scanHistoryTable release];
	scanHistoryTable = nil;
	[firstTimeView release];
	firstTimeView = nil;
	[appNameAndVersionLabel release];
	appNameAndVersionLabel = nil;
	
	[super viewDidUnload];
}


// When the app launches or is foregrounded, this will get called via NSNotification
// to warm up the camera.
- (void) appBecameActive:(NSNotification *) notification
{
	[singleScanPickerController prepareToScan];
}

// This is the delegate method of the BarcodePickerController. When a scan is completed, this
// method will be called with a (possibly null) set of BarcodeResult objects.
- (void) barcodePickerController:(BarcodePickerController*)picker returnResults:(NSSet *)results
{	
	[[UIApplication sharedApplication] setStatusBarHidden:NO];
	
	// Restore main screen (and restore title bar for 3.0)
	[self dismissModalViewControllerAnimated:TRUE];
	
	// If there's any results, save them in our scan history
	if (results && [results count])
	{
		NSMutableDictionary *scanSession = [[NSMutableDictionary alloc] init];
		[scanSession setObject:[NSDate date] forKey:@"Session End Time"];
		[scanSession setObject:[results allObjects] forKey:@"Scanned Items"];
		[scanHistory insertObject:scanSession atIndex:0];
		
		// Save our new scans out to the archive file
		NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
				NSUserDomainMask, YES) objectAtIndex:0];
		NSString *archivePath = [documentsDir stringByAppendingPathComponent:@"ScanHistoryArchive"];
		[NSKeyedArchiver archiveRootObject:scanHistory toFile:archivePath];
		
		[scanHistoryTable reloadData];
		[firstTimeView setHidden:TRUE];
	}
}

// This button initiates a scan session to scan a single barcode. The session will exit
// as soon as something is found.
- (IBAction) scanButtonPressed
{
    RLSampleViewControllerRequestVideoAuthorization(^void (void) {
        
        // hide the status bar and show the scanner view
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        [self presentModalViewController:singleScanPickerController animated:FALSE];
        
    });
}

// This button initiates a multi barcode scan session. The session will keep running until
// the user clicks the 'done' button in the overlay. Also, this shows how you can alloc the
// picker controller just before use, although doing so prevents you from using prepareToScan.
- (IBAction) multiScanButtonPressed
{
    RLSampleViewControllerRequestVideoAuthorization(^void (void) {
        
        // Note that the Single Scan controller is created at init time; this allows us to call
        // prepareToScan on it. As you see here, you can also create the picker at the point of
        // presentation. BUT: although this picker may show up instantly as well, that's because
        // it's borrowing the already prepared AVSession from the Single Scan controller. If your app
        // doesn't use prepareToScan at all, there will be a short delay before scanning starts.
        MultiScanPickerController *multiScanPickerController =
        [[MultiScanPickerController alloc] initWithNibName:@"MultiScanPickerController" bundle:nil];
        multiScanPickerController.delegate = self;
        
        // hide the status bar and show the scanner view
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        [self presentModalViewController:multiScanPickerController animated:FALSE];
        [multiScanPickerController release];
        
    });
}

// This button initiates a multi barcode scan session with yet another overlay style.
// This overlay shows how to do real-time highlighting of discovered barcodes.
- (IBAction) redBoxScanButtonPressed
{
	RLSampleViewControllerRequestVideoAuthorization(^void (void) {
       
        RedBoxPickerController *redBoxPickerController =
        [[RedBoxPickerController alloc] initWithNibName:@"RedBoxPickerController" bundle:nil];
        redBoxPickerController.delegate = self;
        
        // hide the status bar and show the scanner view
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        [self presentModalViewController:redBoxPickerController animated:FALSE];
        [redBoxPickerController release];
        
    });
}

- (IBAction)clearButtonPressed:(id)sender
{
	[scanHistory removeAllObjects];
	[scanHistoryTable reloadData];
	[firstTimeView setHidden:FALSE];
}

#pragma mark - UITableViewDataSource

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return [scanHistory count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSMutableDictionary *scanSession = [scanHistory objectAtIndex:section];
	
	NSDate *scanTime = [scanSession objectForKey:@"Session End Time"];
	
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	NSString *formattedDateString = [dateFormatter stringFromDate:scanTime];
	
	return formattedDateString;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSMutableDictionary *scanSession = [scanHistory objectAtIndex:section];
	
	return [[scanSession objectForKey:@"Scanned Items"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BarcodeResult"];
    if (cell == nil) 
	{
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
				reuseIdentifier:@"BarcodeResult"] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
	
	// Get the barcodeResult that has the data backing this cell
	NSMutableDictionary *scanSession = [scanHistory objectAtIndex:indexPath.section];
	BarcodeResult *barcode = [[scanSession objectForKey:@"Scanned Items"] objectAtIndex:indexPath.row];

    cell.textLabel.text = barcode.barcodeString;
	
	switch (barcode.barcodeType) 
	{
		case kBarcodeTypeEAN13: cell.detailTextLabel.text = @"EAN-13"; break;
		case kBarcodeTypeEAN8: cell.detailTextLabel.text = @"EAN-8"; break;
		case kBarcodeTypeUPCE: cell.detailTextLabel.text = @"UPC-E"; break;
		case kBarcodeTypeEAN5: cell.detailTextLabel.text = @"EAN-5"; break;
		case kBarcodeTypeEAN2: cell.detailTextLabel.text = @"EAN-2"; break;
		case kBarcodeTypeCODE39: cell.detailTextLabel.text = @"Code 39"; break;
		case kBarcodeTypeCODE93: cell.detailTextLabel.text = @"Code 93"; break;
		case kBarcodeTypeCODE128: cell.detailTextLabel.text = @"Code 128"; break;
		case kBarcodeTypeITF: cell.detailTextLabel.text = @"ITF"; break;
		case kBarcodeTypeCodabar: cell.detailTextLabel.text = @"Codabar"; break;
		case kBarcodeTypeGS1Databar: cell.detailTextLabel.text = @"GS1 Databar"; break;
		case kBarcodeTypeGS1DatabarExpanded: cell.detailTextLabel.text = @"GS1 Databar Expanded"; break;
		case kBarcodeTypeQRCODE: cell.detailTextLabel.text = @"QR Code"; break;
		case kBarcodeTypePDF417: cell.detailTextLabel.text = @"PDF 417"; break;
		case kBarcodeTypeDATAMATRIX: cell.detailTextLabel.text = @"Datamatrix"; break;
		case kBarcodeTypeAztec: cell.detailTextLabel.text = @"Aztec"; break;
		default: cell.detailTextLabel.text = @""; break;
	}
	
    return cell;
}



@end
