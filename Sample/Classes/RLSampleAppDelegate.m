/*******************************************************************************
	RLSampleAppDelegate.m
	
	App delegate. Nothing interesting here in terms of how the sample app works.
	
	Chall Fry
	February 2012
	Copyright (c) 2012 eBay Inc. All rights reserved.	
*/

#import "RLSampleAppDelegate.h"
#import "RLSampleViewController.h"
#import <Parse/Parse.h>
#import <ParseCrashReporting/ParseCrashReporting.h>
#import <ParseUI/ParseUI.h>

@implementation RLSampleAppDelegate

@synthesize window;
@synthesize viewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application 
{    
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
	
    // Override point for customization after app launch
    
// [Optional] Power your app with Local Datastore. For more info, go to
        // https://parse.com/docs/ios_guide#localdatastore/iOS
        [Parse enableLocalDatastore];
        
        // Initialize Parse.
        [Parse setApplicationId:@"AHwpdyMSuaTN2UZ4J2rZ9nRosZo3Lc3I2ITeF6wU"
                      clientKey:@"UjYAPyJRKuOSH9iAxTTuqU9RnIWhH1yWdTvtHUWc"];
        
        // [Optional] Track statistics around application opens.
        //[PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
        
        // ...
    
    [window setRootViewController:viewController];
    [window makeKeyAndVisible];
}

- (void)dealloc 
{
    [viewController release];
    [window release];
    [super dealloc];
}


@end
