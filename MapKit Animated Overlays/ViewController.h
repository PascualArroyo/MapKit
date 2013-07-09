//
//  ViewController.h
//  MapKit Animated Overlays
//
//  Created by Robert Ryan on 4/29/13.
//  Copyright (c) 2013 Robert Ryan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface ViewController : UIViewController <UIGestureRecognizerDelegate, MKMapViewDelegate, MKAnnotation, MKOverlay>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *drawOverlayButton;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

- (IBAction)didTouchUpInsideDrawButton:(id)sender;

@end
