//
//  ViewController.m
//  location_bluetooth
//
//  Created by Diana Perez on 10/11/14.
//  Copyright (c) 2014 Diana Perez. All rights reserved.
//

#import "ViewController.h"
#import <MapKit/MapKit.h>

#define IS_OS_8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
#define METERS_PER_MILE 1609.344
#define MINIMUM_ZOOM_ARC 0.014 //approximately 1 miles (1 degree of arc ~= 69 miles)
#define ANNOTATION_REGION_PAD_FACTOR 1.15
#define MAX_DEGREES_ARC 360

@interface ViewController ()
//conexiones a los objectos de la vista
@property (weak, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *connectLabel;
@property (weak, nonatomic) IBOutlet UILabel *rssilabel;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet MKMapView *mapLocation;
//updater

@property NSTimer *myTimer;

//declaracion de instancia a el framework
@property (nonatomic, strong) BLE *ble;
//varible para guardar latitud
@property float latitude;
//varibale para guardar longitud
@property float longitude;

//varible para guardar latitud
@property float masterlatitude;
//varibale para guardar longitud
@property float masterlongitude;

@property NSMutableArray *locationArray;
@property MKPointAnnotation *pointAnnotation;


//variable para guardar el rssi
@property NSNumber *rssi;

@end

@implementation ViewController
{
    //declara instancia del location manager
    CLLocationManager *locationManager;
}

//a realizar cuando la vista se carga
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //inicia una instancia del location manager
    locationManager = [[CLLocationManager alloc] init];
    self.locationArray = [[NSMutableArray alloc] init];
    
//si es iphone 8, pide persmisos para utilizar los servicios de localizacion
#ifdef __IPHONE_8_0
    NSUInteger code = [CLLocationManager authorizationStatus];
    if (code == kCLAuthorizationStatusNotDetermined && ([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)] || [locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])) {
        // choose one request according to your business.
        if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"]){
            [locationManager requestAlwaysAuthorization];
        } else if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
            [locationManager  requestWhenInUseAuthorization];
        } else {
            NSLog(@"Info.plist does not contain NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription");
        }
    }
#endif
    
    //inicia a una instancia del manager del BLE
    self.ble = [[BLE alloc]init];
    //inizializa el bluetooth para ser tilizado por la libreria BLE
    [self.ble controlSetup:1];
    //asigna los delegados a este controlador para ser utilizados
    self.ble.delegate = self;
    //
}

//cuando la vista aparece en pantalla
-(void)viewDidAppear:(BOOL)animated
{
    //obtiene una primera localizacion al iniciar la aplicacion
   NSTimer *timerLocation = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                    target:self
                                                  selector:@selector(getCurrentLocation:)
                                                  userInfo:nil
                                                   repeats:YES];
    
    //asigna el updater al controlador
    [self performSelector:@selector(getCurrentLocation:) withObject:nil afterDelay:1.0];
}

//acciones cuando presionas el boton concetar
- (IBAction)connectButton:(id)sender {
    //si la etiqueta del boton es connect
    if([self.connectButton.titleLabel.text isEqual:@"Connect"])
    {
        //inicializa la busqueda de perifericos para poder conectarse
        [self scanForPeripherals];
    }
    else if([self.connectButton.titleLabel.text isEqual:@"Disconnect"]) // si la etiqueta es disconnect
    {
        //se desconecta del periferico al que esta conectado
        [self disconnectFromPeripheral];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//obtiene la localización actual del dispositivo
- (void)getCurrentLocation:(NSTimer*)timer
{
    //inicializa los delegados en el controlador
    locationManager.delegate = self;
    //set up el location manager para que sea los mas accurate
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    
    //inicia la accion de actualizar la localización
    [locationManager startUpdatingLocation];
    
    //muestra la localizacion el mapa
    self.mapLocation.showsUserLocation = YES;
}


//set up el updater para actualizar el bluetooth y enviar información al periferico cada 5 seg
-(void)updateSetUp{
    
    //inicializa el timer
     self.myTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                         target:self
                                       selector:@selector(sendLocationBluetooth:)
                                       userInfo:nil
                                        repeats:YES];
    
    //asigna el updater al controlador
    [self performSelector:@selector(sendLocationBluetooth:) withObject:nil afterDelay:1.0];
}


//consulta si hay conexion y envia la localización actual
- (void)sendLocationBluetooth:(NSTimer*)timer
{
    //obtiene la localizacion
    //[self getCurrentLocation];
    
    //obtinene lat, long y rs
    NSString *lat = [NSString stringWithFormat:@"%f", self.latitude];
    NSString *lon = [NSString stringWithFormat:@"%f", self.longitude];
    NSString *rs  = [NSString stringWithFormat:@"%@", self.rssi];
    
    //si esta conectado
    if([self.ble isConnected]){
        
        //utiliza un buffer de 16 cada uno con 8 bits,
        //por cada variable se envia un buffer
        for(int i = 0; i < 3; i++)
        {
            UInt8 buf[16] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
            int count;
            NSString *a = @"<";
            const char cochar = [a characterAtIndex:0];
            buf[0] = (int)cochar;
            
            if(i == 0)
            {
                for(int i= 0; i < [lat length]; i++)
                {
                    NSString *a = @"*";
                    const char cochar = [a characterAtIndex:0];
                    buf[1] = (int)cochar;
                    //const char c = [lat characterAtIndex:i];
                    int temp = [self intForCharacter:[lat characterAtIndex:i]];
                    buf[i+2] = temp;
                    count = [lat length];
                }
            }
            else if(i == 1)
            {
                for(int i= 0; i < [lon length]; i++)
                {
                    NSString *a = @"+";
                    const char cochar = [a characterAtIndex:0];
                    buf[1] = (int)cochar;
                    int temp = [self intForCharacter:[lon characterAtIndex:i]];
                    buf[i+2] = temp;
                    count = [lon length];
                }
            }
            else if(i == 2)
            {
                for(int i= 0; i < [rs length]; i++)
                {
                    NSString *a = @"~";
                    const char cochar = [a characterAtIndex:0];
                    buf[1] = (int)cochar;
                    int temp = [self intForCharacter:[rs characterAtIndex:i]];
                    buf[i+2] = temp;
                    count = [rs length];
                }
            }
            a = @">";
            const char cochar2 = [a characterAtIndex:0];
            buf[count + 2] = (int)cochar2;
            NSData *d = [[NSData alloc]initWithBytes:buf length:50];
            
            //escribe en el periferico la información del buffer
            [self.ble write:d];
            NSLog(@"Enviado");
        }
    }
}

//conversion de entero a caracter
- (int)intForCharacter:(char) character
{
    int tem2 = character;
    return tem2;
}

//delegados asociados a la localizacion
#pragma mark - CLLocationManagerDelegate

//acción cuando no se obtien ela localización
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
    UIAlertView *errorAlert = [[UIAlertView alloc]
                               initWithTitle:@"Error" message:@"Failed to Get Your Location" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [errorAlert show];
}

//accion si se obtiene la localizacion
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
   //se obtiene la ultima localización obtenida
    CLLocation *newLocation = [locations lastObject];
    //obtines long y lat
    self.latitude = newLocation.coordinate.latitude;
    self.longitude = newLocation.coordinate.longitude;

    //si la informacion es correcta se actualiza las etiquetas
    if (newLocation != nil) {
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.longitude];
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", newLocation.coordinate.latitude];
    }
    
    //detiene la obtención de localiación
    [locationManager stopUpdatingLocation];
    
    if(self.masterlatitude && self.masterlongitude)
    {
        if(!self.pointAnnotation)
        {
            self.pointAnnotation = [self createAnnotations];
            [self.mapLocation addAnnotation:self.pointAnnotation];
        }
        else{
            CLLocationCoordinate2D location;
            location.latitude = self.masterlatitude;
            location.longitude = self.masterlongitude;
            [self.pointAnnotation setCoordinate:(location)];
        }
    }
    
    [self zoomMapViewToFitAnnotations:self.mapLocation animated:YES];
}


- (void)zoomMapViewToFitAnnotations:(MKMapView *)mapView animated:(BOOL)animated
{
    NSArray *annotations = mapView.annotations;
    int count = [mapView.annotations count];
    if ( count == 0) { return; } //bail if no annotations
    
    //convert NSArray of id <MKAnnotation> into an MKCoordinateRegion that can be used to set the map size
    //can't use NSArray with MKMapPoint because MKMapPoint is not an id
    MKMapPoint points[count]; //C array of MKMapPoint struct
    for( int i=0; i<count; i++ ) //load points C array by converting coordinates to points
    {
        CLLocationCoordinate2D coordinate = [(id <MKAnnotation>)[annotations objectAtIndex:i] coordinate];
        points[i] = MKMapPointForCoordinate(coordinate);
    }
    //create MKMapRect from array of MKMapPoint
    MKMapRect mapRect = [[MKPolygon polygonWithPoints:points count:count] boundingMapRect];
    //convert MKCoordinateRegion from MKMapRect
    MKCoordinateRegion region = MKCoordinateRegionForMapRect(mapRect);
    
    //add padding so pins aren't scrunched on the edges
    region.span.latitudeDelta  *= ANNOTATION_REGION_PAD_FACTOR;
    region.span.longitudeDelta *= ANNOTATION_REGION_PAD_FACTOR;
    //but padding can't be bigger than the world
    if( region.span.latitudeDelta > MAX_DEGREES_ARC ) { region.span.latitudeDelta  = MAX_DEGREES_ARC; }
    if( region.span.longitudeDelta > MAX_DEGREES_ARC ){ region.span.longitudeDelta = MAX_DEGREES_ARC; }
    
    //and don't zoom in stupid-close on small samples
    if( region.span.latitudeDelta  < MINIMUM_ZOOM_ARC ) { region.span.latitudeDelta  = MINIMUM_ZOOM_ARC; }
    if( region.span.longitudeDelta < MINIMUM_ZOOM_ARC ) { region.span.longitudeDelta = MINIMUM_ZOOM_ARC; }
    //and if there is a sample of 1 we want the max zoom-in instead of max zoom-out
    if( count == 1 )
    {
        region.span.latitudeDelta = MINIMUM_ZOOM_ARC;
        region.span.longitudeDelta = MINIMUM_ZOOM_ARC;
    }
    [mapView setRegion:region animated:animated];
}



- (MKPointAnnotation *)createAnnotations
{
    MKPointAnnotation *point = [[MKPointAnnotation alloc] init];;
    CLLocation *theLocation = [[CLLocation alloc]initWithLatitude:self.masterlatitude longitude:self.masterlongitude];
    CLLocationCoordinate2D location;
    location.latitude = self.masterlatitude;
    location.longitude = self.masterlongitude;
    [point setCoordinate:(location)];
    [point setTitle:@"Master"];
    
    //ITS RIGHT HERE THAT I GET THE ERROR
    return point;
}


         
//delegados de las libreria BLE
#pragma mark - BLEDelegate
//si conecta con el periferico, muetras la etiqueta de conectado, cambias la etqiueta del boton a disconnect y asignas una acción al boton por si hay una desconexion del periferico
-(void)bleDidConnect{
    [self.connectLabel setText:@"Connected"];
    [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    [self.connectButton addTarget:self action:@selector(disconnectFromPeripheral) forControlEvents:UIControlEventTouchUpInside];
}

//si se desconecta
-(void)bleDidDisconnect{
    [self.connectLabel setText:@"Disconnected"];
    [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    
    
    [self.connectButton removeTarget:self action:@selector(disconnectFromPeripheral) forControlEvents:UIControlEventTouchUpInside];
    [self.connectButton addTarget:self action:@selector(connectButton:) forControlEvents:UIControlEventTouchUpInside];
    
    
    //dejas de utilizar el updater ya que el periferico esta desconectado
    [self.myTimer invalidate];
    self.myTimer = nil;
}

//si recibes información desde el periferico
-(void)bleDidReceiveData:(unsigned char *)data length:(int)length{
    
    NSData *d = [NSData dataWithBytes:data length:length];
    NSString *s = [[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding];
    [self processData:s];
    if(self.masterlatitude && self.masterlongitude)
    {
        
    }
    NSLog(@"Datos Recibidos: %@",s);
}

-(void)processData:(NSString *) data
{
    NSArray *listItems = [data componentsSeparatedByString:@">"];
    for(NSString *str in listItems)
    {
        if(![str isEqual:@""])
        {
            NSString *newStr = [str stringByReplacingOccurrencesOfString:@"<" withString:@""];
            if([[newStr substringToIndex:1] isEqual:@"+"])
            {
                self.masterlongitude = [[newStr substringFromIndex:1] floatValue];
            }
            else if([[newStr substringToIndex:1] isEqual:@"*"])
            {
                self.masterlatitude = [[newStr substringFromIndex:1] floatValue];
            }
            
        }
    }
    
}



//si se actualiza el rssi
-(void)bleDidUpdateRSSI:(NSNumber *)rssi{
    self.rssilabel.text = [NSString stringWithFormat:@"RSSI:%@",rssi];
    self.rssi = rssi;
}

//acciones que afectan a la libreria BLE
#pragma mark - BLE Actions
-(void)scanForPeripherals{
    
    //si hay un periferico ya utilizado anteriomente, reseteas la vareable
    if(self.ble.peripherals){
        self.ble.peripherals = nil;
    }
    
    //desactivas el boton durante la conexion
    self.connectButton.enabled = NO;
    
    //buscas el periferico, con un time out por si no lo encuentran
    [self.ble findBLEPeripherals:2];
    //ejecutas un updater para ejecutarse hasta que se conecte
    [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
}

-(void)disconnectFromPeripheral{
    //this seems like its for disconnecting...
    //si se desconecta, cancela la conexion con el periferico si el periferico esta activo
    if(self.ble.activePeripheral){
        if (self.ble.activePeripheral.isConnected) {
            [[self.ble CM] cancelPeripheralConnection:[self.ble activePeripheral]];
        }
    }
}

//updater de conexion
-(void)connectionTimer:(NSTimer*)timer{
    
    //si hay una conexion con un periferico
    if(self.ble.peripherals.count > 0){
        //se inicia la conexion
        [self.ble connectPeripheral:[self.ble.peripherals objectAtIndex:0]];
        //inicializa el updater para enviar la localización
        [self updateSetUp];
        //habilita el boton para poder desconectarse luego
        self.connectButton.enabled = YES;

    }else{ // si no hay conexion habilita el boton nuevamente para conectar
        self.connectButton.enabled = YES;
    }
}

@end
