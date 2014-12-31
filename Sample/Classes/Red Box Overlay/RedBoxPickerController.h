/*******************************************************************************
	RedBoxPickerController.h
	Part of RLSample
 
	This is a scan picker example that frames discovered barcodes with red boxes.
	
	Chall Fry
	November 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/

#import <UIKit/UIKit.h>

#import "RedLaserSDK.h"

@interface RedBoxView : UIView
{
@public
	NSSet				*barcodes;
}

@property (retain) NSSet *barcodes;

@end

@interface RedBoxPickerController : BarcodePickerController2
{
	IBOutlet UIBarButtonItem	*torchButton;
	IBOutlet UIBarButtonItem	*frontBackCameraButton;
	IBOutlet UIBarButtonItem 	*captureButton;
	IBOutlet UILabel			*numBarcodesFoundLabel;
	IBOutlet UILabel			*guidanceLabel;
	IBOutlet UILabel			*inRangeLabel;
	IBOutlet UILabel 			*savingImageLabel;
	IBOutlet RedBoxView			*redBoxView;
	
	bool						imageSaveInProgress;
}

- (IBAction) cancelScan;
- (IBAction) captureImage;
- (IBAction) toggleTorch;
- (IBAction) toggleFrontBackCamera;

- (void) image: (UIImage *) image didFinishSavingWithError: (NSError *) error
		contextInfo: (void *) contextInfo;

@end

