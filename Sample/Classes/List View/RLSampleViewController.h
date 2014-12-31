/*******************************************************************************
	RLSampleViewController.h
	
	This is the view controller for the results table.
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/

#pragma once

#import <UIKit/UIKit.h>
#import "RedLaserSDK.h"

#import "SingleScanPickerController.h"
#import "MultiScanPickerController.h"
#import "RedBoxPickerController.h"

@interface RLSampleViewController : UIViewController 
		<BarcodePickerControllerDelegate, UITableViewDelegate, UITableViewDataSource> 
{
	NSMutableArray				*scanHistory;
	
	IBOutlet UITableView 		*scanHistoryTable;
	IBOutlet UILabel 			*appNameAndVersionLabel;
	IBOutlet UIView 			*firstTimeView;
	IBOutlet UILabel 			*appInfoLabel;
	IBOutlet UIToolbar			*topToolbar;
		
	SingleScanPickerController	*singleScanPickerController;
}

- (IBAction) clearButtonPressed:(id)sender;

- (IBAction) scanButtonPressed;
- (IBAction) multiScanButtonPressed;
- (IBAction) redBoxScanButtonPressed;


@end

