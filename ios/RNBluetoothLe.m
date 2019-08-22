
#import "RNBluetoothLe.h"

@implementation NSError (Helper)

    +(instancetype) errorWithText:(NSString*)txt {
        return [[NSError alloc] initWithDomain:@"failed" code:1 userInfo:@{ NSLocalizedDescriptionKey: txt }];
    }

@end

// Implementation
@implementation RNBluetoothLe
    
    +(BOOL) requiresMainQueueSetup {
        return NO;
    }
    
    -(id) init {
        self = [super init];
        
        // Setup operation queue
        self.queue = dispatch_queue_create("Bluetooth LE - Operations", DISPATCH_QUEUE_SERIAL);
        
        // Setup list of waiting operations
        self.events = [[EventSemaphore alloc] init];
        self.queryingPeripherals = [NSMutableArray array];
        
        // Done
        return self;
        
    }
    
    /// Perform an action in the operation queue
    -(void) do:(void(^)(void))action catch:(void(^)(NSError* error))errorCallback {
        
        // Do on queue
        dispatch_async(self.queue, ^{
            
            // Catch errors
            @try {
                
                // Run operation
                action();
                
            } @catch (NSException* exception) {
                
                // Failed! We need to convert the exception to an NSError though
                NSError* error = [[NSError alloc] initWithDomain:exception.name code:1 userInfo:@{
                    NSLocalizedDescriptionKey: exception.reason
                }];
                
                // Call callback
                errorCallback(error);
                
            } @catch (NSError* err) {
                
                // Failed!
                errorCallback(err);
                
            }
            
            
        });
        
    }
    
    /// Perform an action in the operation queue, and return the result to the promise
    -(void) withResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject do:(id(^)(void))action {
        
        // Do on queue
        [self do:^{
            
            // Do action
            id result = action();
            
            // Success, resolve promise
            resolve(result);
            
        } catch:^(NSError* err) {
            
            // Failed, reject promise
            reject(err.domain, err.localizedDescription, err);
            
        }];
        
    }
    
    RCT_EXPORT_MODULE()

    /// Which thread the JS functions are called on
//    -(dispatch_queue_t) methodQueue {
//        if (!RNBLEQueue)
//        return RNBLEQueue;
//    }
    
    /// Which events we send to JS
    -(NSArray<NSString*>*)supportedEvents {
        return @[@"BLEPeripheral:ReadyStateChanged", @"BLECentral:ScanEnd", @"BLECentral:ScanAdded", @"BLECentral:ScanRemoved"];
    }
    
    /// Start the bluetooth system for use as a peripheral
    -(void) preparePeripheral {
        
        // Check if manager exists already
        if (!self.peripheralManager) {
            
            // Create manager options
            NSDictionary* opts = @{
                CBPeripheralManagerOptionShowPowerAlertKey: @false,
                CBPeripheralManagerOptionRestoreIdentifierKey: @"reactnative.ble.peripheral"
            };
            
            // Create manager, wait for power up
            CBPeripheralManager* peripheral = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:opts];
            [self.events waitFor:@"power-up"];
            self.peripheralManager = peripheral;
            
        }
        
        // Create service array if needed
        if (!self.services)
            self.services = [NSMutableDictionary dictionary];
        
    }
    
    /// Called when the bluetooth power state changes
    -(void) peripheralManagerDidUpdateState:(CBPeripheralManager*)peripheral {
        
        // Get state
        if (peripheral.state == CBManagerStatePoweredOn)
            [self.events resolve:@"power-up" withValue:@true];
        else if (peripheral.state == CBManagerStatePoweredOff)
            [self.events reject:@"power-up" withErrorText:@"Bluetooth is turned off."];
        else if (peripheral.state == CBManagerStateUnsupported)
            [self.events reject:@"power-up" withErrorText:@"Bluetooth is not supported."];
        else if (peripheral.state == CBManagerStateUnauthorized)
            [self.events reject:@"power-up" withErrorText:@"Bluetooth permission has been denied. Please go to Settings to re-enable it."];
        
    }
    
    -(void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary<NSString *,id> *)dict {
        
        NSLog(@"Bluetooth LE: State restored");
        
    }
    
    /// Called to create a new peripheral service. If UUID already exists, it will be replaced.
    RCT_REMAP_METHOD(createService, createServiceWithUUID:(NSString*)uuidStr
                     characteristics:(NSArray*)characteristicDescriptions
                     withResolver:(RCTPromiseResolveBlock)resolve
                     rejecter:(RCTPromiseRejectBlock)reject) {
        
        // Do on operation queue
        [self withResolver:resolve rejecter:reject do:^id{
        
            // Prepare peripheral manager
            [self preparePeripheral];
            
            // Create service
            CBMutableService* svc = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:uuidStr] primary:YES];
            [self.services setObject:svc forKey:uuidStr];
            
            // Add each characteristic
            NSMutableArray* chrs = [NSMutableArray array];
            for (NSDictionary* dict in characteristicDescriptions) {
                
                // Fetch characteristic info
                NSString* uuid = [dict valueForKey:@"uuid"];
                BOOL canRead = [[dict valueForKey:@"canRead"] boolValue];
                BOOL canWrite = [[dict valueForKey:@"canWrite"] boolValue];
                NSString* dataStr = [dict valueForKey:@"data"];
                if ([dataStr isKindOfClass:[NSNull class]] || dataStr.length == 0)
                    dataStr = nil;
                
                // Create properties
                CBCharacteristicProperties props = 0;
                if (canRead) props |= CBCharacteristicPropertyRead;
                if (canWrite) props |= CBCharacteristicPropertyWrite;
                
                // Create permissions
                CBAttributePermissions perms = 0;
                if (canRead) perms |= CBAttributePermissionsReadable;
                if (canWrite) props |= CBAttributePermissionsWriteable;
                
                // Convert data to NSData if exists
                NSData* data = [dataStr dataUsingEncoding:NSUTF8StringEncoding];
                
                // Create characteristic
                CBMutableCharacteristic* chr = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:uuid] properties:props value:data permissions:perms];
                
                // Save it
                [chrs addObject:chr];
                
            }
            
            // Register service
            svc.characteristics = chrs;
            [self.peripheralManager addService:svc];
            
            // Stop advertising if already advertising
            if (self.peripheralManager.isAdvertising)
                [self.peripheralManager stopAdvertising];
            
            // Start advertising
            [self.peripheralManager startAdvertising:@{
                CBAdvertisementDataServiceUUIDsKey: @[
                    [CBUUID UUIDWithString:uuidStr]
                ]
            }];
            [self.events waitFor:@"advertise"];
            return nil;
            
        }];
        
    }
    
    -(void) peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
        
        // Advertisement started
        if (error)
            [self.events reject:@"advertise" withError:error];
        else
            [self.events resolve:@"advertise" withValue:@true];
        
    }
    
    -(void) setupCentral {
        
        // Check if central manager has been created
        if (!self.centralManager) {
            
            // Create manager options
            NSDictionary* opts = @{
                CBPeripheralManagerOptionShowPowerAlertKey: @false
            };
            
            // Create central manager, wait for power up
            CBCentralManager* central = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:opts];
            [self.events waitFor:@"power-up"];
            self.centralManager = central;
            
        }
        
    }
    
    /// Called when the user wants to initiate a scan
    RCT_REMAP_METHOD(scan, scanWithServiceFilter:(NSArray*)services resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
        
        // Do on operation queue
        [self withResolver:resolve rejecter:reject do:^id{
            
            // Setup central
            [self setupCentral];
            
            // Create list of service UUIDs to filter by if specified
            NSMutableArray<CBUUID*>* uuids = nil;
            if (services.count) {
                
                // Create UUIDs
                uuids = [NSMutableArray array];
                for (NSString* str in services)
                    [uuids addObject:[CBUUID UUIDWithString:str]];
                
            }
            
            // Start scan
            [self.centralManager scanForPeripheralsWithServices:uuids options:nil];
            
            // Done
            return @true;
            
        }];
        
    }
    
    -(void) centralManagerDidUpdateState:(CBCentralManager*)central {
        
        // Check state
        if (central.state == CBManagerStatePoweredOn)
            [self.events resolve:@"power-up" withValue:@true];
        else if (central.state == CBManagerStatePoweredOff)
            [self.events reject:@"power-up" withErrorText:@"Bluetooth is turned off."];
        else if (central.state == CBManagerStateUnsupported)
            [self.events reject:@"power-up" withErrorText:@"Bluetooth is not supported."];
        else if (central.state == CBManagerStateUnauthorized)
            [self.events reject:@"power-up" withErrorText:@"Bluetooth permission has been denied. Please go to Settings to re-enable it."];
        
    }
    
    -(void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
        
        // Create device info
        NSMutableDictionary* device = [NSMutableDictionary dictionary];
        [device setValue:[peripheral.identifier UUIDString] forKey:@"address"];
        [device setValue:peripheral.name forKey:@"name"];
        [device setValue:RSSI forKey:@"rssi"];
        
        // Store peripheral
        if (![self.queryingPeripherals containsObject:peripheral])
            [self.queryingPeripherals addObject:peripheral];
        
        // Notify JS
        [self sendEventWithName:@"BLECentral:ScanAdded" body:device];
        NSLog(@"Discovered peripheral: %@", peripheral.identifier);
        
    }
    
    RCT_REMAP_METHOD(readCharacteristic, readCharacteristicWithDeviceID:(NSString*)deviceID
                     serviceUUID:(NSString*)serviceUUID
                     characteristicUUID:(NSString*)chrUUID
                     resolver:(RCTPromiseResolveBlock)resolve
                     rejecter:(RCTPromiseRejectBlock)reject) {
        
        // Do on operation queue
        [self withResolver:resolve rejecter:reject do:^id{
            
            // Setup central
            [self setupCentral];
            
            // Find device
            NSArray<CBPeripheral*>* peripherals = [self.centralManager retrievePeripheralsWithIdentifiers:@[[[NSUUID alloc] initWithUUIDString:deviceID]]];
            CBPeripheral* peripheral = peripherals.count > 0 ? [peripherals objectAtIndex:0] : nil;
            peripheral.delegate = self;
            if (!peripheral)
                @throw [NSError errorWithText:@"The specified device was not found."];
            
            // Store peripheral so it doesn't get garbage collected
//            if (![self.queryingPeripherals containsObject:peripheral])
//                [self.queryingPeripherals addObject:peripheral];
            
            // Connect to peripheral if needed
            if (peripheral.state != CBPeripheralStateConnected) {
                
                // Do connection
                [self.centralManager connectPeripheral:peripheral options:nil];
                [self.events waitFor:@"connect"];
                
            }
            
            // Get service
            CBService* service = nil;
            for (CBService* svc in peripheral.services)
                if ([svc.UUID isEqual:[CBUUID UUIDWithString:serviceUUID]])
                    service = svc;
            
            // Discover service if needed
            if (!service) {
                
                // Discover services
                [peripheral discoverServices:nil];
                for (CBService* svc in [self.events waitFor:@"discover-services"])
                    if ([svc.UUID isEqual:[CBUUID UUIDWithString:serviceUUID]])
                        service = svc;
                
                // If still not found, I guess it doesn't exist
                if (!service)
                    @throw [NSError errorWithText:@"The specified service was not found on the remote device."];
                
            }
            
            // Get characteristic
            CBCharacteristic* characteristic = nil;
            for (CBCharacteristic* chr in service.characteristics)
                if ([chr.UUID isEqual:[CBUUID UUIDWithString:chrUUID]])
                    characteristic = chr;
            
            // Discover characteristics if needed
            if (!characteristic) {
                
                // Discover characteristics
                [peripheral discoverCharacteristics:nil forService:service];
                for (CBCharacteristic* chr in [self.events waitFor:@"discover-characteristics"])
                    if ([chr.UUID isEqual:[CBUUID UUIDWithString:chrUUID]])
                        characteristic = chr;
                
                // If still not found, I guess it doesn't exist
                if (!characteristic)
                    @throw [NSError errorWithText:@"The specified characteristic was not found on the remote device."];
                
            }
            
            // Read value
            [peripheral readValueForCharacteristic:characteristic];
            NSData* data = [self.events waitFor:@"read-characteristic"];
            if (!data.length)
                return @"";
            
            // Convert to string
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
        }];
        
    }
    
    -(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
        [self.events resolve:@"connect" withValue:@true];
    }
    
    -(void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
        [self.events reject:@"connect" withError:error];
    }
    
    -(void) peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error {
        
        // Discover finished
        if (error)
            [self.events reject:@"discover-services" withError:error];
        else
            [self.events resolve:@"discover-services" withValue:peripheral.services];
        
    }
    
    -(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
        
        // Discover finished
        if (error)
            [self.events reject:@"discover-characteristics" withError:error];
        else
            [self.events resolve:@"discover-characteristics" withValue:service.characteristics];
        
    }
    
    -(void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
        
        // Read finished
        if (error)
            [self.events reject:@"read-characteristic" withError:error];
        else
            [self.events resolve:@"read-characteristic" withValue:characteristic.value];
        
    }

@end
  
