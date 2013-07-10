//
//  ViewController.m
//  MapKit Animated Overlays
//
//  Created by Robert Ryan on 4/29/13.
//  Copyright (c) 2013 Robert Ryan. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <MKMapViewDelegate>

@property (nonatomic, strong) NSMutableArray *coordinates;
@property (nonatomic, strong) NSMutableArray *annotations;
@property (nonatomic, strong) NSMutableArray *annotationsMed;
@property (nonatomic, weak) MKPolyline *polyLine;                  // used during the drawing of the polyline, but discarded once the MKPolygon is added
@property (nonatomic, weak) MKPointAnnotation *previousAnnotation; // if you're using other annotations, you might want to use a custom annotation type here
@property (nonatomic) BOOL isDrawingPolygon;
@property (nonatomic) BOOL isDelete;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    
    self.annotations = [[NSMutableArray alloc] init];
    self.annotationsMed = [[NSMutableArray alloc] init];
    self.coordinates = [[NSMutableArray alloc] init];
    
    [self.mapView setDelegate: self];
    self.isDelete = NO;
    
}

- (IBAction)deleteOverlay:(id)sender
{
    
    if (!self.isDelete)
    {
        self.isDelete = YES;
        [self.deleteOverlayButton setTitle:@"Done"];
    }
    
    else
    {
       self.isDelete = NO;
        [self.deleteOverlayButton setTitle:@"Delete Overlay"];
    }
    
}

- (IBAction)didTouchUpInsideDrawButton:(id)sender
{
    if (!self.isDrawingPolygon)
    {
        // We're starting the drawing of our polyline/polygon, so
        // let's initialize everything
        
        self.isDrawingPolygon = YES;
        self.isDelete = NO;
        
        [self.mapView removeOverlays:self.mapView.overlays];
        [self.mapView removeAnnotations:self.annotations];
        [self.mapView removeAnnotations:self.annotationsMed];
        
        [self.annotations removeAllObjects];
        [self.annotationsMed removeAllObjects];
        [self.coordinates removeAllObjects];
        
        // turn off map interaction so touches can fall through to
        // here
        
        self.mapView.userInteractionEnabled = NO;
        
        // change our "draw overlay" button to "done"
        
        [self.drawOverlayButton setTitle:@"Done"];
        [self.deleteOverlayButton setTitle:@"Delete Overlay"];
    }
    else
    {
        // We're finishing the drawing of our polyline, so let's
        // clean up, remove polyline, and add polygon
        
        self.isDrawingPolygon = NO;
        
        // let's restore map interaction
        
        self.mapView.userInteractionEnabled = YES;
        
        // and, if we drew more than two points, let's draw our polygon
        
        NSInteger numberOfPoints = [self.coordinates count];
        
        if (numberOfPoints > 2)
        {
            CLLocationCoordinate2D points[numberOfPoints];
            for (NSInteger i = 0; i < numberOfPoints; i++)
                points[i] = [self.coordinates[i] MKCoordinateValue];
            [self.mapView addOverlay:[MKPolygon polygonWithCoordinates:points count:numberOfPoints]];
            
            if (self.polyLine)
                [self.mapView removeOverlay:self.polyLine];
            
            [self puntosMedios];
        }
        else
        {
            
            [self.mapView removeOverlays:self.mapView.overlays];
            [self.mapView removeAnnotations:self.annotations];
            [self.mapView removeAnnotations:self.annotationsMed];
            
            [self.annotations removeAllObjects];
            [self.annotationsMed removeAllObjects];
            [self.coordinates removeAllObjects];
        }
        // and if we had a polyline, let's remove it
        
        
        // change our "draw overlay" button to "done"
        
        [self.drawOverlayButton setTitle:@"Draw overlay"];
        
        // remove our old point annotation
        
        if (self.previousAnnotation)
            [self.mapView removeAnnotation:self.previousAnnotation];
    }
}

- (void)addCoordinate:(CLLocationCoordinate2D)coordinate replaceLastObject:(BOOL)replaceLast end:(BOOL) end
{
    if (replaceLast && [self.coordinates count] > 0)
        [self.coordinates removeLastObject];
    
    [self.coordinates addObject:[NSValue valueWithMKCoordinate:coordinate]];
    
    NSInteger numberOfPoints = [self.coordinates count];
    
    // if we have more than one point, then we're drawing a line segment
    
    if (numberOfPoints > 1)
    {
        MKPolyline *oldPolyLine = self.polyLine;
        CLLocationCoordinate2D points[numberOfPoints];
        for (NSInteger i = 0; i < numberOfPoints; i++)
            points[i] = [self.coordinates[i] MKCoordinateValue];
        MKPolyline *newPolyLine = [MKPolyline polylineWithCoordinates:points count:numberOfPoints];
        [self.mapView addOverlay:newPolyLine];
        
        self.polyLine = newPolyLine;
        
        // note, remove old polyline _after_ adding new one, to avoid flickering effect
        
        if (oldPolyLine)
            [self.mapView removeOverlay:oldPolyLine];
        
    }
    
    // let's draw an annotation where we tapped
    
    MKPointAnnotation *newAnnotation = [[MKPointAnnotation alloc] init];
    newAnnotation.coordinate = coordinate;
    
    [self.mapView addAnnotation:newAnnotation];
    
    // if we had an annotation for the previous location, remove it
    
    if (self.previousAnnotation)
        [self.mapView removeAnnotation:self.previousAnnotation];
    
    // and save this annotation for future reference
    if (!end) {
        self.previousAnnotation = newAnnotation;
    }
    else
    {
        if ([self isClosingPolygonWithCoordinate:coordinate])
        {
            [self.coordinates removeLastObject];
            [self didTouchUpInsideDrawButton:nil];
            
            [self.mapView removeAnnotation:newAnnotation];
            [self puntosMedios];
        }
        else
        {
            [self.annotations addObject:newAnnotation];
        }
        
        
    }

}


- (BOOL)isClosingPolygonWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    if ([self.coordinates count] > 2)
    {
        CLLocationCoordinate2D startCoordinate = [self.coordinates[0] MKCoordinateValue];
        CGPoint start = [self.mapView convertCoordinate:startCoordinate
                                          toPointToView:self.mapView];
        CGPoint end = [self.mapView convertCoordinate:coordinate
                                        toPointToView:self.mapView];
        CGFloat xDiff = end.x - start.x;
        CGFloat yDiff = end.y - start.y;
        CGFloat distance = sqrtf(xDiff * xDiff + yDiff * yDiff);
        if (distance < 30.0)
        {
            return YES;
        }
    }
    
    return NO;
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.mapView];
    
    if (!self.isDrawingPolygon)
    {
        //[self.mapView setSelectedAnnotations:self.annotations];
    }
    
    else
    {
        CLLocationCoordinate2D coordinate = [self.mapView convertPoint:location toCoordinateFromView:self.mapView];
        
        [self addCoordinate:coordinate replaceLastObject:NO end:NO];
    }
   
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.isDrawingPolygon)
    {
        //[self.mapView setSelectedAnnotations:self.annotations];
    }
    
    else
    {
        UITouch *touch = [touches anyObject];
        CGPoint location = [touch locationInView:self.mapView];
        CLLocationCoordinate2D coordinate = [self.mapView convertPoint:location toCoordinateFromView:self.mapView];
        
        [self addCoordinate:coordinate replaceLastObject:YES end:NO];
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.isDrawingPolygon)
    {
        
    }
    
    else
    {
        UITouch *touch = [touches anyObject];
        CGPoint location = [touch locationInView:self.mapView];
        CLLocationCoordinate2D coordinate = [self.mapView convertPoint:location toCoordinateFromView:self.mapView];
        
        [self addCoordinate:coordinate replaceLastObject:YES end:YES];
    }
    
}

#pragma mark - MKMapViewDelegate

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    MKOverlayPathView *overlayPathView;
    
    if ([overlay isKindOfClass:[MKPolygon class]])
    {
        overlayPathView = [[MKPolygonView alloc] initWithPolygon:(MKPolygon*)overlay];
        
        overlayPathView.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
        overlayPathView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayPathView.lineWidth = 3;
        
        return overlayPathView;
    }
    
    else if ([overlay isKindOfClass:[MKPolyline class]])
    {
        overlayPathView = [[MKPolylineView alloc] initWithPolyline:(MKPolyline *)overlay];
        
        overlayPathView.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
        overlayPathView.lineWidth = 3;
        
        return overlayPathView;
    }
    
    return nil;
}


- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    static NSString * const annotationIdentifier = @"CustomAnnotation";
    
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
    
    if (annotationView)
    {
        annotationView.annotation = annotation;
    }
    else
    {
        annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationIdentifier];
        annotationView.alpha = 0.5;
    }
    
    if ([annotation.subtitle isEqualToString:@"Med"]) {
        annotationView.image = [UIImage imageNamed:@"annotation2.png"];
    }
    else
    {
        annotationView.image = [UIImage imageNamed:@"annotation.png"];
    }

    [annotationView setSelected:YES animated:YES];
    [annotationView setCanShowCallout:NO];
    [annotationView setDraggable:YES];
    [annotationView setAccessibilityFrame: CGRectMake(annotationView.bounds.origin.x-50, annotationView.bounds.origin.y-50, 100, 100)];
    
    return annotationView;
}


-(void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if (self.isDelete && [self.coordinates count] > 3) {
        if (![view.annotation.subtitle isEqualToString:@"Med"]) {
            
            for (int i=0; i< [self.annotations count]; i++) {
                     
                MKPointAnnotation * annotation;
                annotation = [self.annotations objectAtIndex:i];
                
                if (annotation == view.annotation) {
                         
                    [self.coordinates removeObjectAtIndex:i];
                }
            }
             
            [self.annotations removeObject:view.annotation];
            [self.mapView removeAnnotation:view.annotation];
            
            
            
            for (int i=0; i< [self.annotations count]; i++) {
                
                MKPointAnnotation * annotation;
                annotation = [self.annotations objectAtIndex:i];
                
                if (annotation == view.annotation) {
                    // NSLog(@"%d",i);
                    
                    [self.coordinates replaceObjectAtIndex:i withObject:[NSValue valueWithMKCoordinate:view.annotation.coordinate]];
                }
            }
            
            
            NSInteger numberOfPoints = [self.coordinates count];
            
            
            if (numberOfPoints > 2)
            {
                [self.mapView removeOverlays:self.mapView.overlays];
                
                CLLocationCoordinate2D points[numberOfPoints];
                
                for (NSInteger i = 0; i < numberOfPoints; i++)
                    points[i] = [self.coordinates[i] MKCoordinateValue];
                
                [self.mapView addOverlay:[MKPolygon polygonWithCoordinates:points count:numberOfPoints]];
                [self puntosMedios];
            }
            
            
        }
    }
    
      if ([view.annotation.subtitle isEqualToString:@"Med"])
      {
          MKPointAnnotation *newAnnotation = [[MKPointAnnotation alloc] init];
          newAnnotation.coordinate = view.annotation.coordinate;
          
          [self.mapView addAnnotation:newAnnotation];
          
          for (int i = 0; i < [self.annotationsMed count]; i++) {
              if (view.annotation == [self.annotationsMed objectAtIndex:i]) {
                  [self.annotations insertObject:newAnnotation atIndex:i+1];
                  [self.coordinates insertObject:[NSValue valueWithMKCoordinate:newAnnotation.coordinate] atIndex:i+1];
              }
          }
          
          [self puntosMedios];
          
          
      }
    
    
    
    
}

-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
{
    
    switch (newState)
    {
        case MKAnnotationViewDragStateNone:
            
            NSLog(@"MKAnnotationViewDragStateNone");
            view.alpha = 0.5;
            view.bounds = CGRectMake(0, 0, 30, 30);
            
            break;
            
        case MKAnnotationViewDragStateStarting:
            
            NSLog(@"MKAnnotationViewDragStateStarting");
            view.alpha = 1;
            view.bounds = CGRectMake(0, 0, 45, 45);
            
            break;
            
        case MKAnnotationViewDragStateDragging:
            
            NSLog(@"MKAnnotationViewDragStateDragging");
            view.alpha = 1;
            view.bounds = CGRectMake(0, 0, 45, 45);
            
            break;
            
            
        case MKAnnotationViewDragStateEnding:
            
            view.alpha= 0.5;
            view.bounds = CGRectMake(0, 0, 30, 30);
            NSLog(@"MKAnnotationViewDragStateEnding");
            
            
            if ([view.annotation.subtitle isEqualToString:@"Med"]) {
                
                MKPointAnnotation *newAnnotation = [[MKPointAnnotation alloc] init];
                newAnnotation.coordinate = view.annotation.coordinate;
                
                [self.mapView addAnnotation:newAnnotation];
                
                for (int i = 0; i < [self.annotationsMed count]; i++) {
                    if (view.annotation == [self.annotationsMed objectAtIndex:i]) {
                        [self.annotations insertObject:newAnnotation atIndex:i+1];
                        [self.coordinates insertObject:[NSValue valueWithMKCoordinate:newAnnotation.coordinate] atIndex:i+1];
                    }
                }
                
                NSInteger numberOfPoints = [self.coordinates count];
            
                if (numberOfPoints > 2)
                {
                    [self.mapView removeOverlays:self.mapView.overlays];
                
                    CLLocationCoordinate2D points[numberOfPoints];
                
                    for (NSInteger i = 0; i < numberOfPoints; i++)
                        points[i] = [self.coordinates[i] MKCoordinateValue];
                
                    [self.mapView addOverlay:[MKPolygon polygonWithCoordinates:points count:numberOfPoints]];
                
                    [self puntosMedios];
                }
            
            }
    
            else
            {
                
                CLLocationCoordinate2D droppedAt = view.annotation.coordinate;
                NSLog(@"dropped at %f,%f", droppedAt.latitude, droppedAt.longitude);
                
                for (int i=0; i< [self.annotations count]; i++) {
                    
                    MKPointAnnotation * annotation;
                    annotation = [self.annotations objectAtIndex:i];
                    
                    if (annotation == view.annotation) {
                        // NSLog(@"%d",i);
                        
                        [self.coordinates replaceObjectAtIndex:i withObject:[NSValue valueWithMKCoordinate:view.annotation.coordinate]];
                    }
                }
                
                
                NSInteger numberOfPoints = [self.coordinates count];
                
                
                if (numberOfPoints > 2)
                {
                    [self.mapView removeOverlays:self.mapView.overlays];
                    
                    CLLocationCoordinate2D points[numberOfPoints];
                    
                    for (NSInteger i = 0; i < numberOfPoints; i++)
                        points[i] = [self.coordinates[i] MKCoordinateValue];
                    
                    [self.mapView addOverlay:[MKPolygon polygonWithCoordinates:points count:numberOfPoints]];
                    
                    [self puntosMedios];
                }
                
            }
            
            
            break;
            
        case MKAnnotationViewDragStateCanceling:
            
            NSLog(@"MKAnnotationViewDragStateCanceling");
            view.alpha = 0.5;
            view.bounds = CGRectMake(0, 0, 30, 30);
            
            [view setSelected:YES];
            
            break;
            
    }
    
    if (oldState == MKAnnotationViewDragStateDragging) {
        
         NSLog(@"OldState MKAnnotationViewDragStateDragging");
        
    }
    
}

- (void) puntosMedios{
    
    CLLocationCoordinate2D coordinate1;
    CLLocationCoordinate2D coordinate2;
    CLLocationCoordinate2D coordinateMed;
    
    [self.mapView removeAnnotations:self.annotationsMed];
    [self.annotationsMed removeAllObjects];
    
    for (int i=0; i< [self.coordinates count]; i++) {
       
        [self.coordinates[i] MKCoordinateValue];
        
        coordinate1 = [self.coordinates[i] MKCoordinateValue];;
        coordinate2 = [self.coordinates[(i+1)%[self.coordinates count]] MKCoordinateValue];;
        
        coordinateMed.latitude = (coordinate1.latitude + coordinate2.latitude)/2;
        coordinateMed.longitude = (coordinate1.longitude + coordinate2.longitude)/2;
        
        MKPointAnnotation *annotationMed = [[MKPointAnnotation alloc] init];
        annotationMed.coordinate = coordinateMed;
        annotationMed.subtitle = @"Med";
        
        [self.annotationsMed addObject:annotationMed];
        
        [self.mapView addAnnotation:annotationMed];
        
    }
    
}

@end
