//
//  ViewController.h
//  MapKit Animated Overlays
//
//  Created by Robert Ryan on 4/29/13.
//  Copyright (c) 2013 Robert Ryan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <QuartzCore/QuartzCore.h>

@interface ViewController : UIViewController <MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *drawOverlayButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteOverlayButton;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

- (IBAction)didTouchUpInsideDrawButton:(id)sender;
- (IBAction)deleteOverlay:(id)sender;


@end
