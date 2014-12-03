//
//  ViewController.h
//  location_bluetooth
//
//  Created by Diana Perez on 10/11/14.
//  Copyright (c) 2014 Diana Perez. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "BLE.h"

@interface ViewController : UIViewController <CLLocationManagerDelegate, BLEDelegate>

@end

