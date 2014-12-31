/*******************************************************************************
	MultiScanPickerController.h
	
	This is the view controller for the multiple scan picker.
	
	The MultiScanPicker uses a different UI than single scan,
	mostly to show what's possible. Other than that, the major difference
	between this and the single scan UI is that this UI doesn't exit until
	the done button is clicked.
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/
#pragma once

#import "RedLaserSDK.h"
#import "AudioToolbox/AudioServices.h"
#import <QuartzCore/QuartzCore.h>

@interface MultiScanPickerController : BarcodePickerController2
		<UITableViewDataSource, UITableViewDelegate>
{
	IBOutlet UIImageView 		*redlaserLogo;
	IBOutlet UIButton 			*torchButton;
	IBOutlet UIButton			*doneButton;
	IBOutlet UIButton 			*rotateButton;
	IBOutlet UITableView 		*foundBarcodesTable;

	SystemSoundID 				scanSuccessSound;
	NSMutableArray				*barcodeTableData;
	CAShapeLayer				*targetLine;
	
	UIImageOrientation			guideOrientation;
}

- (IBAction) torchButtonPressed;
- (IBAction) doneButtonPressed;
- (IBAction) rotatePressed;

@end
