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
@property (nonatomic, weak) MKPolyline *polyLine;
@property (nonatomic, weak) MKPointAnnotation *previousAnnotation;
@property (nonatomic, weak) MKPointAnnotation *centerAnnotation;
@property (nonatomic) BOOL isDrawingPolygon;
@property (nonatomic) BOOL isDelete;
@property (nonatomic) BOOL canEnding;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    
    self.annotations = [[NSMutableArray alloc] init]; //Vertices
    self.annotationsMed = [[NSMutableArray alloc] init]; //Puntos intermedios
    self.coordinates = [[NSMutableArray alloc] init]; //Coordenadas de los vertices
    
    [self.mapView setDelegate: self]; //Establecemos el delegado
    self.mapView.mapType = MKMapTypeStandard;
    self.isDelete = NO; //Establece si se pueden borrar los vertices al tocarlos
    self.canEnding = NO; //Necesario para que no se repita el evento termiar de editar dos veces seguidas
    
}

- (IBAction)deleteOverlay:(id)sender
{
    //Cambiamos la opcion de borrado y su boton
    
    if (!self.isDelete)
    {
        self.isDelete = YES;
        [self.deleteOverlayButton setTitle:@"Done"];
    }
    
    else
    {
       self.isDelete = NO;
        [self.deleteOverlayButton setTitle:@"Delete"];
    }
    
}

- (IBAction)didTouchUpInsideDrawButton:(id)sender
{
    if (!self.isDrawingPolygon)
    {
        //Comenzamos a dibujar el poligono, si antes habia otro lo borramos
        
        self.isDrawingPolygon = YES;
        self.isDelete = NO;
        
        [self.mapView removeOverlays:self.mapView.overlays];
        [self.mapView removeAnnotations:self.annotations];
        [self.mapView removeAnnotations:self.annotationsMed];
        
        [self.annotations removeAllObjects];
        [self.annotationsMed removeAllObjects];
        [self.coordinates removeAllObjects];
        
        if(self.centerAnnotation)
            [self.mapView removeAnnotation:self.centerAnnotation];
        
        
        //Interaccion del usuario con los mapas desactivada para dibujar el poligono
        self.mapView.userInteractionEnabled = NO;
        
        // cambiamos el texto de los botones
        
        [self.drawOverlayButton setTitle:@"Done"];
        [self.deleteOverlayButton setTitle:@"Delete"];
    }
    else
    {
        //Hemos pulsado sobre done y ahora tiene que dibujarse el poligo
        
        self.isDrawingPolygon = NO;
        
        
        //Volvemos a habilitar la interaccion del usuario con el mapa
        self.mapView.userInteractionEnabled = YES;
        
        NSInteger numberOfPoints = [self.coordinates count];
        
        //Si tiene mas de dos vertices dibujamos el poligono
        if (numberOfPoints > 2)
        {
            [self dibujarTodo: numberOfPoints];
        }
        else
        {
            //Sino borramos los posibles vertices creados y las lineas
            
            [self.mapView removeOverlays:self.mapView.overlays];
            [self.mapView removeAnnotations:self.annotations];
            [self.mapView removeAnnotations:self.annotationsMed];
            
            [self.annotations removeAllObjects];
            [self.annotationsMed removeAllObjects];
            [self.coordinates removeAllObjects];
        }
        
        
        //cambiamos el nombre del boton
        [self.drawOverlayButton setTitle:@"Start"];
        
        // borramos el ultimo vertice, ya que sera el primero
        
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
    newAnnotation.subtitle = @"Normal";
    
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
    
    //Si tenemos mas de tres vertices, comprobamos si queremos cerrar los vertices al estar el primero y el ultimo muy proximos
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
        for (int i=0; i< [self.annotations count]; i++) {
            
            MKPointAnnotation * annotation;
            annotation = [self.annotations objectAtIndex:i];
            
            MKAnnotationView * view;
            
            view = [self.mapView viewForAnnotation:annotation];
            
            [view setSelected:YES];
        }
    
        for (int i=0; i< [self.annotationsMed count]; i++) {
        
            MKPointAnnotation * annotation;
            annotation = [self.annotationsMed objectAtIndex:i];
        
            MKAnnotationView * view;
        
            view = [self.mapView viewForAnnotation:annotation];
        
            [view setSelected:YES];
        }
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
        [[annotationView layer] setBorderWidth:1.0f];
        annotationView.alpha = 0.5;
    }
    
    if ([annotation.subtitle isEqualToString:@"Normal"]) {
        annotationView.frame = CGRectMake(annotationView.bounds.origin.x-13, annotationView.bounds.origin.y-13, 26, 26);
        annotationView.backgroundColor = [UIColor redColor];
        [[annotationView layer] setCornerRadius:13.0f];
    }
    else if ([annotation.subtitle isEqualToString:@"Med"]) {
        annotationView.frame = CGRectMake(annotationView.bounds.origin.x-8, annotationView.bounds.origin.y-8, 16, 16);
        annotationView.backgroundColor = [UIColor yellowColor];
        [[annotationView layer] setCornerRadius:8.0f];
    }
    else
    {
        return nil;
    }

    [annotationView setSelected:YES animated:YES];
    [annotationView setCanShowCallout:NO];
    [annotationView setDraggable:YES];
    [annotationView setAccessibilityFrame: CGRectMake(annotationView.bounds.origin.x-50, annotationView.bounds.origin.y-50, 100, 100)];
    
    return annotationView;
}


-(void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    
    NSLog(@"*** didSelectAnnotationView ***");
    
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
                    
                    [self.coordinates replaceObjectAtIndex:i withObject:[NSValue valueWithMKCoordinate:view.annotation.coordinate]];
                }
            }
            
            NSInteger numberOfPoints = [self.coordinates count];
            
            if (numberOfPoints > 2)
            {
                [self dibujarTodo: numberOfPoints];
            }
            
        }
        
    }

     //GENERA UN NUEVO VERTICE AL PULSAR UN VERTICE INTERMEDIO
    
    /*
      if ([view.annotation.subtitle isEqualToString:@"Med"])
      {
          MKPointAnnotation *newAnnotation = [[MKPointAnnotation alloc] init];
          newAnnotation.subtitle = @"Normal";
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
    */
    
   // [view setSelected:YES];
    
}

-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState
{
    
    switch (newState)
    {
            
        case MKAnnotationViewDragStateStarting:
            
            NSLog(@"MKAnnotationViewDragStateStarting");
           
            if ([view.annotation.subtitle isEqualToString:@"Med"])
            {
                view.bounds = CGRectMake(0, 0, 26, 26);
                [[view layer] setCornerRadius:13.0f];
            }
            else
            {
                view.bounds = CGRectMake(0, 0, 40, 40);
                [[view layer] setCornerRadius:20.0f];
            }
            view.alpha = 1;
            
            self.canEnding = YES;
            
            break;
            
            
        case MKAnnotationViewDragStateEnding:
            
            NSLog(@"MKAnnotationViewDragStateEnding");
            
            if (self.canEnding == YES) {
                
                self.canEnding = NO;
                view.alpha= 0.5;
                
                if ([view.annotation.subtitle isEqualToString:@"Med"]) {
                    
                    view.bounds = CGRectMake(0, 0, 16, 16);
                    [[view layer] setCornerRadius:8.0f];
                    
                    MKPointAnnotation *newAnnotation = [[MKPointAnnotation alloc] init];
                    newAnnotation.subtitle = @"Normal";
                    newAnnotation.coordinate = view.annotation.coordinate;
                    
                    [self.mapView addAnnotation:newAnnotation];
                    
                    for (int i = 0; i < [self.annotationsMed count]; i++) {
                        if (view.annotation == [self.annotationsMed objectAtIndex:i]) {
                            [self.annotations insertObject:newAnnotation atIndex:i+1];
                            [self.coordinates insertObject:[NSValue valueWithMKCoordinate:newAnnotation.coordinate] atIndex:i+1];
                        }
                    }
                    
                    NSLog(@"Fin");
                    
                    NSInteger numberOfPoints = [self.coordinates count];
                    
                    if (numberOfPoints > 2)
                    {
                        [self dibujarTodo: numberOfPoints];
                    }
                    
                    
                }
                
                else
                {
                    
                    view.bounds = CGRectMake(0, 0, 26, 26);
                    [[view layer] setCornerRadius:13.0f];
                    
                    CLLocationCoordinate2D droppedAt = view.annotation.coordinate;
                    NSLog(@"dropped at %f,%f", droppedAt.latitude, droppedAt.longitude);
                    
                    for (int i=0; i< [self.annotations count]; i++) {
                        
                        MKPointAnnotation * annotation;
                        annotation = [self.annotations objectAtIndex:i];
                        
                        if (annotation == view.annotation) {
                            
                            [self.coordinates replaceObjectAtIndex:i withObject:[NSValue valueWithMKCoordinate:view.annotation.coordinate]];
                        }
                    }
                    
                    
                    NSInteger numberOfPoints = [self.coordinates count];
                    
                    
                    if (numberOfPoints > 2)
                    {
                        [self dibujarTodo: numberOfPoints];
                    }
                    
                }

                
            }
            
            
            break;
            
        case MKAnnotationViewDragStateCanceling:
            
            NSLog(@"MKAnnotationViewDragStateCanceling");
            
            
            if ([view.annotation.subtitle isEqualToString:@"Med"])
            {
                view.bounds = CGRectMake(0, 0, 16, 16);
                [[view layer] setCornerRadius:8.0f];
            }
            else
            {
                view.bounds = CGRectMake(0, 0, 26, 26);
                [[view layer] setCornerRadius:13.0f];
            }
            view.alpha = 0.5;
            
            self.canEnding = NO;
            
            break;
            
    }
    
    
}


- (void) dibujarTodo:(int)numberOfPoints
{
    [self.mapView removeOverlays:self.mapView.overlays];
    
    CLLocationCoordinate2D points[numberOfPoints];
    CLLocationCoordinate2D centro;
    
    centro.latitude = 0;
    centro.longitude = 0;
    
    for (NSInteger i = 0; i < numberOfPoints; i++)
    {
        points[i] = [self.coordinates[i] MKCoordinateValue];
        
        centro.latitude = centro.latitude + points[i].latitude;
        centro.longitude = centro.longitude + points[i].longitude;
        
    }
    
    centro.latitude = centro.latitude/numberOfPoints;
    centro.longitude = centro.longitude/numberOfPoints;
    
    [self.mapView addOverlay:[MKPolygon polygonWithCoordinates:points count:numberOfPoints]];
    
    NSLog(@"%lf",[self polygonArea]);
    
    [self puntosMedios];
    
    if (self.centerAnnotation) {
        [self.mapView removeAnnotation:self.centerAnnotation];
    }
    
    
    MKPointAnnotation * newAnnotation = [[MKPointAnnotation alloc] init];
    newAnnotation.coordinate = centro;
    newAnnotation.title = [NSString stringWithFormat:@"Nombre Parcela"];
    newAnnotation.subtitle = [NSString stringWithFormat:@"%lf hectáreas",[self polygonArea]];
    
    self.centerAnnotation = newAnnotation;
    
    [self.mapView addAnnotation:self.centerAnnotation];
    
}

- (void) puntosMedios{
    
    CLLocationCoordinate2D coordinate1;
    CLLocationCoordinate2D coordinate2;
    CLLocationCoordinate2D coordinateMed;
    
    [self.mapView removeAnnotations:self.annotationsMed];
    [self.annotationsMed removeAllObjects];
    
    for (int i=0; i< [self.coordinates count]; i++) {
       
        [self.coordinates[i] MKCoordinateValue];
        
        coordinate1 = [self.coordinates[i] MKCoordinateValue];
        coordinate2 = [self.coordinates[(i+1)%[self.coordinates count]] MKCoordinateValue];
        
        coordinateMed.latitude = (coordinate1.latitude + coordinate2.latitude)/2;
        coordinateMed.longitude = (coordinate1.longitude + coordinate2.longitude)/2;
        
        MKPointAnnotation *annotationMed = [[MKPointAnnotation alloc] init];
        annotationMed.coordinate = coordinateMed;
        annotationMed.subtitle = @"Med";
        
        [self.annotationsMed addObject:annotationMed];
        
        [self.mapView addAnnotation:annotationMed];
        
    }
    
}

- (double) polygonArea
{
    double area = 0;
    int j = [self.coordinates count]-1;
    
    CLLocationCoordinate2D point1, point2;
    
    for (int i=0; i<[self.coordinates count]; i++)
    {
        point1 = [self.coordinates[i] MKCoordinateValue];
        point2 = [self.coordinates[j] MKCoordinateValue];
        
        area = area + (point1.longitude + point2.longitude) * (point1.latitude - point2.latitude);
        j = i;
    }
    
    area = (area/2)*1000000;
    
    if (area < 0) {
        area = -area;
    }
    
    return area;
    
}


- (IBAction)mapTypeChanged:(id)sender {
    switch (self.mapTypeSegmentedControl.selectedSegmentIndex) {
        case 0:
            self.mapView.mapType = MKMapTypeStandard;
            break;
        case 1:
            self.mapView.mapType = MKMapTypeHybrid;
            break;
        case 2:
            self.mapView.mapType = MKMapTypeSatellite;
            break;
        default:
            break;
    }
}

@end
