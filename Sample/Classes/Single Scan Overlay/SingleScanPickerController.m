/*******************************************************************************
	SingleScanPickerController.m
	
	This is the view controller for the single scan overlay. 
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/

#import "SingleScanPickerController.h"

@implementation SingleScanPickerController

- (void) dealloc 
{
	if ([self isViewLoaded])
		[self viewDidUnload];
		
	[super dealloc];
}

- (void) viewDidLoad 
{
    [super viewDidLoad];
	
	// Create target rectangle
	rectLayer = [[CAShapeLayer layer] retain];
	rectLayer.fillColor = [[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.2] CGColor];
	rectLayer.strokeColor = [[UIColor whiteColor] CGColor];
	rectLayer.lineWidth = 3;
	[self.view.layer addSublayer:rectLayer];
	guideOrientation = UIImageOrientationUp;
			
	// Prepare an audio session
	AudioSessionInitialize(NULL, NULL, NULL, NULL);
	AudioSessionSetActive(TRUE);

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
}

- (void) viewDidUnload 
{		
	AudioServicesDisposeSystemSoundID(scanSuccessSound);
	AudioSessionSetActive(FALSE);
	
	[rectLayer release];
	rectLayer = nil;
	
	[textCue release];
	textCue = nil;
	[cancelButton release];
	cancelButton = nil;
	[frontButton release];
	frontButton = nil;
	[flashButton release];
	flashButton = nil;
	[redlaserLogo release];
	redlaserLogo = nil;
	
	[super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	if (self.hasTorch)
	{
		[flashButton setEnabled:YES];
		[flashButton setStyle:UIBarButtonItemStyleBordered];
		[self turnTorch:NO];
	} else
	{
		[flashButton setEnabled:NO];
	}
	
	// The front camera button uses the "Done" style to indicate the pressed state.
	if (self.useFrontCamera)
	{
		[frontButton setStyle:UIBarButtonItemStyleDone];
	} else
	{
		[frontButton setStyle:UIBarButtonItemStyleBordered];
	}

	textCue.text = @"";
	viewHasAppeared = NO;
	
	[self setLayoutOrientation:guideOrientation];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	viewHasAppeared = YES;
}

- (NSUInteger) supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
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
	
	
	// Make the RedLaser stripe more vivid when Barcode is in Range.
	BOOL inRange = [(NSNumber*)[status objectForKey:@"InRange"] boolValue];
	if (inRange)
	{
		rectLayer.strokeColor = [[UIColor greenColor] CGColor];
	}
	else
	{
		rectLayer.strokeColor = [[UIColor whiteColor] CGColor];
	}
	
	// Beep when we find a new code
	NSSet *newFoundBarcodes = [status objectForKey:@"NewFoundBarcodes"];
	if ([newFoundBarcodes count])
	{
		AudioServicesPlayAlertSound(scanSuccessSound);
	}
	
	// Exit if we've found a code, and the view has fully appeared.
	// The viewHasAppeared check is to work around a bug with modal views not going away
	// if dismissed while they're still animating into place.
	NSSet *foundBarcodes = [status objectForKey:@"FoundBarcodes"];
	if ([foundBarcodes count] && viewHasAppeared)
	{
		[self doneScanning];
	}
	
	int guidanceLevel = [[status objectForKey:@"Guidance"] intValue];
	if (guidanceLevel == 1)
	{
		textCue.text = @"Try moving the camera close to each part of the barcode";
	} else if (guidanceLevel == 2)
	{
		textCue.text = [status objectForKey:@"PartialBarcode"];
	} else 
	{
		textCue.text = @"";
	}
}

#pragma mark Button Handlers

- (IBAction) cancelButtonPressed
{
	[self doneScanning];
}

- (IBAction) flashButtonPressed 
{
	torchIsOn = !torchIsOn;
	[self turnTorch:torchIsOn];
}

- (IBAction) rotateButtonPressed
{
	// Swap the UI orientation. 
	if (guideOrientation == UIImageOrientationUp)
		guideOrientation = UIImageOrientationRight;
	else
		guideOrientation = UIImageOrientationUp;
	
	[self setLayoutOrientation:guideOrientation];
}

// Toggles between front and back cameras
- (IBAction) cameraToggleButtonPressed
{
	if (self.useFrontCamera)
	{
		[frontButton setStyle:UIBarButtonItemStyleBordered];
		self.useFrontCamera = false;
	} else
	{
		[frontButton setStyle:UIBarButtonItemStyleDone];
		self.useFrontCamera = true;
	}
	
	// Set the torch button appropriately
	if (self.hasTorch)
	{
		[flashButton setEnabled:YES];
		torchIsOn = NO;
		[self turnTorch:torchIsOn];
	} else
	{
		[flashButton setEnabled:NO];
	}
}

- (void) setLayoutOrientation:(UIImageOrientation) newOrientation
{
	CGRect 				guideRect;
	CGRect				boundsRect = self.view.bounds;
	CGPoint				rectCenter = self.view.center;
	CGAffineTransform 	transform;
	CGMutablePathRef 	path = CGPathCreateMutable();
	
	// Adjust the center of our 'target' rect, to account for the toolbar at the bottom
	rectCenter.y -= 22;
		
	if (newOrientation == UIImageOrientationUp)
	{
		guideRect = CGRectMake(boundsRect.origin.x, rectCenter.y - 125,
				boundsRect.size.width, 250);
		transform = CGAffineTransformMakeRotation(0);	
		CGPathAddRect(path, NULL, guideRect);
	} else if (newOrientation == UIImageOrientationRight)
	{
		guideRect = CGRectMake(rectCenter.x - 60, boundsRect.origin.y,
				120, boundsRect.size.height - 44);
		transform = CGAffineTransformMakeRotation(M_PI_2); // 90 degree rotation
		
		// This makes a rectangular path that starts in the upper right instead of
		// upper left. This makes the animation 'rotate' the rect.
		CGPathMoveToPoint(path, nil, CGRectGetMaxX(guideRect), CGRectGetMinY(guideRect));
		CGPathAddLineToPoint(path, nil, CGRectGetMaxX(guideRect), CGRectGetMaxY(guideRect));
		CGPathAddLineToPoint(path, nil, CGRectGetMinX(guideRect), CGRectGetMaxY(guideRect));
		CGPathAddLineToPoint(path, nil, CGRectGetMinX(guideRect), CGRectGetMinY(guideRect));
		CGPathCloseSubpath (path);
	}
	// Note: Could handle other UIImageOrientations here as well, but the 'rotate' button
	// is just a toggle.
	
	// Rotate the red rectangle to the new layout position
	CABasicAnimation *targetRectReshaper = [CABasicAnimation animationWithKeyPath:@"path"];
	targetRectReshaper.duration = 0.5;
	targetRectReshaper.fillMode = kCAFillModeForwards;
	[targetRectReshaper setRemovedOnCompletion:NO];
	[targetRectReshaper setDelegate:self];
	targetRectReshaper.toValue = (id) path;
	[rectLayer addAnimation:targetRectReshaper forKey:@"animatePath"];
	CGPathRelease(path);

	// Also rotate the RedLaser logo
	[UIView beginAnimations:@"setScanningOrientation" context:nil];
	[UIView setAnimationCurve: UIViewAnimationCurveLinear];
	[UIView setAnimationDuration: 0.5];
	redlaserLogo.transform = transform;
	[UIView commitAnimations];
}

- (void) animationDidStop:(CABasicAnimation *)theAnimation finished:(BOOL)flag
{
	[rectLayer setPath:(CGPathRef) theAnimation.toValue];
	[rectLayer removeAnimationForKey:[theAnimation keyPath]];
}


@end
