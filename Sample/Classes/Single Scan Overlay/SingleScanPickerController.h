/*******************************************************************************
	SingleScanPickerController.h
	
	This is the view controller for the single scan overlay. 
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/
#pragma once

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioServices.h>
#import <QuartzCore/QuartzCore.h>

#import "RedLaserSDK.h"

@interface SingleScanPickerController : BarcodePickerController2
{
	
	IBOutlet UILabel 			*textCue;
	IBOutlet UIBarButtonItem 	*cancelButton;	
	IBOutlet UIBarButtonItem 	*frontButton;
	IBOutlet UIBarButtonItem 	*flashButton;
	IBOutlet UIImageView 		*redlaserLogo;
	
	BOOL 						viewHasAppeared;
	BOOL						torchIsOn;
	
	SystemSoundID 				scanSuccessSound;
	
	CAShapeLayer 				*rectLayer;
	
	UIImageOrientation			guideOrientation;
}

- (IBAction) cancelButtonPressed;
- (IBAction) flashButtonPressed;
- (IBAction) rotateButtonPressed;
- (IBAction) cameraToggleButtonPressed;

- (void) setLayoutOrientation:(UIImageOrientation) newOrientation;
@end
