/*******************************************************************************
	MultiScanPickerController.m

	This is the view controller for the multiple scan overlay. 
	
	The MultiScanPicker uses a different UI than the single scan picker,
	mostly to show what's possible. Other than that, the major difference
	between this and the single scan UI is that this UI doesn't exit until
	the done button is clicked.
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/

#import "MultiScanPickerController.h"

@implementation MultiScanPickerController

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
	{
		barcodeTableData = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void) dealloc 
{
	if ([self isViewLoaded])
		[self viewDidUnload];
		
	[barcodeTableData release];
	
	[super dealloc];
}

- (void) viewDidLoad 
{
    [super viewDidLoad];
				
	// Prepare an audio session
	AudioSessionInitialize(NULL, NULL, NULL, NULL);
	AudioSessionSetActive(TRUE);

	// Create target line object
	targetLine = [[CAShapeLayer layer] retain];
	targetLine.fillColor = [[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5] CGColor];
	targetLine.strokeColor = [[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5] CGColor];
	targetLine.lineWidth = 3;
	[self.view.layer addSublayer:targetLine];

	// Load up the beep sound
	UInt32 flag = 0;
	float aBufferLength = 1.0; // In seconds
	NSURL *soundFileURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] 
			pathForResource:@"beep" ofType:@"wav"] isDirectory:NO]; 
	AudioServicesCreateSystemSoundID((CFURLRef) soundFileURL, &scanSuccessSound);
	OSStatus error = AudioServicesSetProperty(kAudioServicesPropertyIsUISound,
			sizeof(UInt32), &scanSuccessSound, sizeof(UInt32), &flag);
	error = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, 
			sizeof(aBufferLength), &aBufferLength);
			
	[[doneButton layer] setCornerRadius:18.0f];
	[[doneButton layer] setMasksToBounds:YES];
	[[doneButton layer] setBorderWidth:1.0f];

	[[torchButton layer] setCornerRadius:18.0f];
	[[torchButton layer] setMasksToBounds:YES];
	[[torchButton layer] setBorderWidth:1.0f];

	[[rotateButton layer] setCornerRadius:18.0f];
	[[rotateButton layer] setMasksToBounds:YES];
	[[rotateButton layer] setBorderWidth:1.0f];

}

- (void) viewDidUnload 
{
	if (scanSuccessSound)
	{
		AudioServicesDisposeSystemSoundID(scanSuccessSound);
		AudioSessionSetActive(FALSE);
		scanSuccessSound = 0;
	}
		
	[torchButton release];
	torchButton = nil;
	[doneButton release];
	doneButton = nil;
	[rotateButton release];
	rotateButton = nil;
	[foundBarcodesTable release];
	foundBarcodesTable = nil;
	[redlaserLogo release];
	redlaserLogo = nil;
	
	[targetLine release];
	targetLine = nil;

	[super viewDidUnload];
}

- (NSUInteger) supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	// Set the initial path for the target line object
	CGMutablePathRef path = CGPathCreateMutable();
	CGRect activeRegionRect = CGRectMake(self.view.bounds.origin.x, self.view.center.y - 125,
										 self.view.bounds.size.width, 250);
	CGPathMoveToPoint(path, nil, CGRectGetMinX(activeRegionRect) + 40, CGRectGetMidY(activeRegionRect));
	CGPathAddLineToPoint(path, nil, CGRectGetMaxX(activeRegionRect) - 40, CGRectGetMidY(activeRegionRect));
	targetLine.path = path;
	CGPathRelease(path);

	if ([self hasTorch])
	{
		[torchButton setEnabled:YES];
		[torchButton setSelected:FALSE];
		[torchButton setBackgroundColor:[UIColor lightGrayColor]];
		[self turnTorch:NO];
	} else
	{
		[torchButton setEnabled:NO];
	}
}

- (void) statusUpdated:(NSDictionary*) status
{
	// In the status dictionary:
	
	// "FoundBarcodes" key is a NSSet of all discovered barcodes this scan session
	// "NewFoundBarcodes" is a NSSet of barcodes discovered in the most recent pass.
		// When a barcode is found, it is added to both sets. The NewFoundBarcodes
		// set is cleaned out each pass.
	
	// "Guidance" can be used to help guide the user through the process of discovering
	// a long barcode in sections. Currently only works for Code 39.
	
	// "Valid" is TRUE once there are valid barcode results.
	// "InRange" is TRUE if there's currently a barcode detected the viewfinder. The barcode
	//		may not have been decoded yet. It is possible for barcodes to be found without
	// 		InRange ever being set.
	
	// Beep when we find a new code, and add the code to our table for immediate display
	NSSet *newFoundBarcodes = [status objectForKey:@"NewFoundBarcodes"];
	if ([newFoundBarcodes count])
	{
		AudioServicesPlayAlertSound(scanSuccessSound);
		[barcodeTableData addObjectsFromArray:[newFoundBarcodes allObjects]];
		[foundBarcodesTable reloadData];
	}
	
	// For demonstration puproses, mark everything we find as 'unwanted'. This will put
	// a red X over the barcode when it's onscreen. Unwanted barcodes will continue
	// to show up in the status dictionary, and will be returned to the delegate--you
	// have to filter them out. This is the easy method of telling the user that they're
	// trying to scan the wrong thing. See the Red Box Picker for a more customizable method.
	for (BarcodeResult *result in newFoundBarcodes)
	{
		[self reportUnwantedBarcode:result];
	}
}

#pragma mark Button Handlers

- (IBAction) doneButtonPressed
{
	[self doneScanning];
}

- (IBAction) torchButtonPressed 
{
	if ([torchButton isSelected]) 
	{
		[torchButton setSelected:FALSE];
		[torchButton setBackgroundColor:[UIColor lightGrayColor]];
		[self turnTorch:NO];
	} else 
	{
		[torchButton setSelected:TRUE];
		[torchButton setBackgroundColor:[UIColor whiteColor]];
		[self turnTorch:YES];
	}
}

- (IBAction) rotatePressed
{
	CGRect 				activeRegionRect;
	CGRect				boundsRect = self.view.bounds;
	CGPoint				rectCenter = self.view.center;
	CGMutablePathRef 	path = CGPathCreateMutable();
			
	if (guideOrientation == UIImageOrientationUp)
	{
		activeRegionRect = CGRectMake(rectCenter.x - 60, boundsRect.origin.y,
				120, boundsRect.size.height);
		guideOrientation = UIImageOrientationRight;
		CGPathMoveToPoint(path, nil, CGRectGetMidX(activeRegionRect), CGRectGetMinY(activeRegionRect) + 80);
		CGPathAddLineToPoint(path, nil, CGRectGetMidX(activeRegionRect), CGRectGetMaxY(activeRegionRect) - 80);
	} else if (guideOrientation == UIImageOrientationRight)
	{
		activeRegionRect = CGRectMake(boundsRect.origin.x, rectCenter.y - 125,
				boundsRect.size.width, 250);
		guideOrientation = UIImageOrientationDown;
		CGPathMoveToPoint(path, nil, CGRectGetMaxX(activeRegionRect) - 40, CGRectGetMidY(activeRegionRect));
		CGPathAddLineToPoint(path, nil, CGRectGetMinX(activeRegionRect) + 40, CGRectGetMidY(activeRegionRect));
	} else if (guideOrientation == UIImageOrientationDown)
	{
		activeRegionRect = CGRectMake(rectCenter.x - 60, boundsRect.origin.y,
				120, boundsRect.size.height);
		guideOrientation = UIImageOrientationLeft;
		CGPathMoveToPoint(path, nil, CGRectGetMidX(activeRegionRect), CGRectGetMaxY(activeRegionRect) - 80);
		CGPathAddLineToPoint(path, nil, CGRectGetMidX(activeRegionRect), CGRectGetMinY(activeRegionRect) + 80);
	} else if (guideOrientation == UIImageOrientationLeft)
	{
		activeRegionRect = CGRectMake(boundsRect.origin.x, rectCenter.y - 125,
				boundsRect.size.width, 250);
		guideOrientation = UIImageOrientationUp;
		CGPathMoveToPoint(path, nil, CGRectGetMinX(activeRegionRect) + 40, CGRectGetMidY(activeRegionRect));
		CGPathAddLineToPoint(path, nil, CGRectGetMaxX(activeRegionRect) - 40, CGRectGetMidY(activeRegionRect));
	}
	
	// Rotate the red rectangle to the new layout position
	CABasicAnimation *targetLineReshaper = [CABasicAnimation animationWithKeyPath:@"path"];
	targetLineReshaper.duration = 0.5;
	targetLineReshaper.fillMode = kCAFillModeForwards;
	[targetLineReshaper setRemovedOnCompletion:NO];
	[targetLineReshaper setDelegate:self];
	targetLineReshaper.toValue = (id) path;
	[targetLine addAnimation:targetLineReshaper forKey:@"animatePath"];
	CGPathRelease(path);
	
	// Animate the change to the logo
	[UIView beginAnimations:@"setScanningOrientation" context:nil];
	[UIView setAnimationCurve: UIViewAnimationCurveLinear ];
	[UIView setAnimationDuration: 0.5];
	redlaserLogo.transform = CGAffineTransformRotate(redlaserLogo.transform, M_PI_2);
	[UIView commitAnimations];
}

- (void) animationDidStop:(CABasicAnimation *)theAnimation finished:(BOOL)flag
{
	[targetLine setPath:(CGPathRef) theAnimation.toValue];
	[targetLine removeAnimationForKey:[theAnimation keyPath]];
}

#pragma mark Table View Delegate

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	cell.backgroundColor = [UIColor clearColor];
}


#pragma mark Table View Data Source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{	
	return [barcodeTableData count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BarcodeResult"];
    if (cell == nil) 
	{
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 
				reuseIdentifier:@"TransparentResultOverlay"] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.textColor = [UIColor whiteColor];
    }
	
	// Get the barcodeResult that has the data backing this cell
	BarcodeResult *barcode = [barcodeTableData objectAtIndex:[barcodeTableData count] - indexPath.row - 1];

	// Set the text of the cell to the first 20 characters of the string
	if ([barcode.barcodeString length] > 20)
		cell.textLabel.text = [[barcode.barcodeString substringToIndex:20]
				stringByAppendingString:@"…"];
	else
    	cell.textLabel.text = barcode.barcodeString;

	
	switch (barcode.barcodeType) 
	{
		case kBarcodeTypeEAN13: cell.detailTextLabel.text = @"EAN-13"; break;
		case kBarcodeTypeEAN8: cell.detailTextLabel.text = @"EAN-8"; break;
		case kBarcodeTypeUPCE: cell.detailTextLabel.text = @"UPC-E"; break;
		case kBarcodeTypeEAN5: cell.detailTextLabel.text = @"EAN-5"; break;
		case kBarcodeTypeEAN2: cell.detailTextLabel.text = @"EAN-2"; break;
		case kBarcodeTypeCODE39: cell.detailTextLabel.text = @"Code 39"; break;
		case kBarcodeTypeCODE128: cell.detailTextLabel.text = @"Code 128"; break;
		case kBarcodeTypeITF: cell.detailTextLabel.text = @"ITF"; break;
		case kBarcodeTypeCodabar: cell.detailTextLabel.text = @"Codabar"; break;
		case kBarcodeTypeCODE93: cell.detailTextLabel.text = @"Code 93"; break;
		case kBarcodeTypeQRCODE: cell.detailTextLabel.text = @"QR Code"; break;
		case kBarcodeTypeDATAMATRIX: cell.detailTextLabel.text = @"Datamatrix"; break;
		case kBarcodeTypePDF417: cell.detailTextLabel.text = @"PDF 417"; break;
		case kBarcodeTypeGS1Databar: cell.detailTextLabel.text = @"GS1 Databar"; break;
		case kBarcodeTypeGS1DatabarExpanded: cell.detailTextLabel.text = @"GS1 Databar Expanded"; break;
		case kBarcodeTypeAztec: cell.detailTextLabel.text = @"Aztec"; break;
		default: cell.detailTextLabel.text = @""; break;
	}
	
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return 22;
}


@end
