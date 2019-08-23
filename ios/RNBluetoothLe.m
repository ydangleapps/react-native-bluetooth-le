
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
        NSLog(@"[BLE] Init");
        self.queue = dispatch_queue_create("Bluetooth LE - Operations", DISPATCH_QUEUE_SERIAL);
        
        // Setup list of waiting operations
        self.events = [[EventSemaphore alloc] init];
        self.queryingPeripherals = [NSMutableArray array];
        self.idToPeripheral = [NSMutableDictionary dictionary];
        
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
            NSLog(@"[BLE] Error: %@", err.localizedDescription);
            
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
            NSLog(@"[BLE] Peripheral: Waiting for power up...");
            CBPeripheralManager* peripheral = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:opts];
            [self.events waitFor:@"power-up"];
            self.peripheralManager = peripheral;
            NSLog(@"[BLE] Peripheral: Power up complete");
            
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
        
        NSLog(@"[BLE] Peripheral: State restored");
        
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
            NSLog(@"[BLE] Peripheral: Start advertising...");
            [self.peripheralManager startAdvertising:@{
                CBAdvertisementDataServiceUUIDsKey: @[
                    [CBUUID UUIDWithString:uuidStr]
                ]
            }];
            [self.events waitFor:@"advertise"];
            NSLog(@"[BLE] Peripheral: Advertise started");
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
            NSLog(@"[BLE] Central: Waiting for power up...");
            CBCentralManager* central = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:opts];
            [self.events waitFor:@"power-up"];
            self.centralManager = central;
            NSLog(@"[BLE] Central: Power up complete");
            
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
            NSLog(@"[BLE] Central: Scan started");
            [self.centralManager scanForPeripheralsWithServices:uuids options:nil];
            
            // Done
            return @true;
            
        }];
        
    }
    
    /// Called when the user wants to stop the scan
    RCT_REMAP_METHOD(stopScan, stopScanWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
        
        // Do on operation queue
        [self withResolver:resolve rejecter:reject do:^id{
            
            // Stop scan
            NSLog(@"[BLE] Central: Scan stopped");
            [self.centralManager stopScan];
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
        
        // Read manufacturer data, check for our special session identifier.
        // This is to work around a strange bug where every time an iOS device connects to an Android 6+ device, the
        // iOS device discovers a "new" device, which is actually the same device. So we use this ID to determine if
        // the device is the same as one we just discovered previously
        NSString* identifier = peripheral.identifier.UUIDString;
        NSData* data = [advertisementData valueForKey:CBAdvertisementDataManufacturerDataKey];
        if (data.length >= 6) {
            
            // Compare bytes
            uint8_t* bytes = (uint8_t*) data.bytes;
            if (bytes[0] == 0x1C && bytes[1] == 0xEF) {
                
                // Get ID
                uint32_t idNum = 0;
                idNum |= bytes[2] << 0;
                idNum |= bytes[3] << 8;
                idNum |= bytes[4] << 16;
                idNum |= bytes[5] << 24;
                NSLog(@"[BLE] Discovered peripheral has a session ID: %i", idNum);
                identifier = [NSString stringWithFormat:@"SessionID:%i", idNum];
                
            }
            
        }
        
        // Create device info
        NSMutableDictionary* device = [NSMutableDictionary dictionary];
        [device setValue:identifier forKey:@"address"];
        [device setValue:peripheral.name forKey:@"name"];
        [device setValue:RSSI forKey:@"rssi"];
        
        // Store peripheral
        [self.idToPeripheral setObject:peripheral forKey:identifier];
        
        // Notify JS
        [self sendEventWithName:@"BLECentral:ScanAdded" body:device];
        NSLog(@"[BLE] Central: Discovered remote peripheral: %@", peripheral.identifier);
        
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
            CBPeripheral* peripheral = [self.idToPeripheral objectForKey:deviceID];
            peripheral.delegate = self;
            if (!peripheral)
                @throw [NSError errorWithText:@"The specified device was not found."];
            
            // Store peripheral so it doesn't get garbage collected
//            if (![self.queryingPeripherals containsObject:peripheral])
//                [self.queryingPeripherals addObject:peripheral];
            
            // Check if peripheral state is currently connecting, if so wait for it to complete
            if (peripheral.state == CBPeripheralStateConnecting)
                [self.events waitFor:@"connect"];
            
            // Check i fperipheral is bbusy disconnecting
            if (peripheral.state == CBPeripheralStateDisconnecting)
                [self.events waitFor:@"disconnect"];
            
            // Connect to peripheral if needed
            if (peripheral.state == CBPeripheralStateDisconnected) {
                
                // Do connection
                NSLog(@"[BLE] Central: Connecting to peripheral %@", peripheral.identifier);
                [self.centralManager connectPeripheral:peripheral options:nil];
                [self.events waitFor:@"connect"];
                NSLog(@"[BLE] Central: Connect complete");
                
            }
            
            // Sanity check: We should be connected now
            if (peripheral.state != CBPeripheralStateConnected)
                @throw [NSError errorWithText:@"Unable to connect to peripheral, we don't know it's state."];
            
            // Get service
            CBService* service = nil;
            for (CBService* svc in peripheral.services)
                if ([svc.UUID isEqual:[CBUUID UUIDWithString:serviceUUID]])
                    service = svc;
            
            // Discover service if needed
            if (!service) {
                
                // Discover services
                NSLog(@"[BLE] Central: Discovering services...");
                [peripheral discoverServices:nil];
                for (CBService* svc in [self.events waitFor:@"discover-services"])
                    if ([svc.UUID isEqual:[CBUUID UUIDWithString:serviceUUID]])
                        service = svc;
                
                // If still not found, I guess it doesn't exist
                if (!service)
                    @throw [NSError errorWithText:@"The specified service was not found on the remote device."];
                
                NSLog(@"[BLE] Central: Discover complete");
                
            }
            
            // Get characteristic
            CBCharacteristic* characteristic = nil;
            for (CBCharacteristic* chr in service.characteristics)
                if ([chr.UUID isEqual:[CBUUID UUIDWithString:chrUUID]])
                    characteristic = chr;
            
            // Discover characteristics if needed
            if (!characteristic) {
                
                // Discover characteristics
                NSLog(@"[BLE] Central: Discovering characteristics...");
                [peripheral discoverCharacteristics:nil forService:service];
                for (CBCharacteristic* chr in [self.events waitFor:@"discover-characteristics"])
                    if ([chr.UUID isEqual:[CBUUID UUIDWithString:chrUUID]])
                        characteristic = chr;
                
                // If still not found, I guess it doesn't exist
                if (!characteristic)
                    @throw [NSError errorWithText:@"The specified characteristic was not found on the remote device."];
                
                NSLog(@"[BLE] Central: Discover complete");
                
            }
            
            // Check if characteristic can be read
            if (!(characteristic.properties & CBCharacteristicPropertyRead))
                @throw [NSError errorWithText:@"This characteristic is not readable."];
            
            // Try to read the value
            NSData* data = nil;
            @try {
            
                // Read value
                NSLog(@"[BLE] Central: Reading characteristic...");
                [peripheral readValueForCharacteristic:characteristic];
                data = [self.events waitFor:@"read-characteristic"];
                NSLog(@"[BLE] Central: Read complete");
                
            } @catch (NSError* err) {
                
                // Check if a value does actually exist already, if so, use the cached value
                if (characteristic.value) {
                    
                    // Failed, but we have a cached value to use
                    NSLog(@"[BLE] Central: Read failed, using cached value: %@", err.localizedDescription);
                    data = characteristic.value;
                
                } else {
                    
                    // Failed
                    @throw err;
                    
                }
                
            }
            
            // Convert to string
            NSLog(@"[BLE] Central: Characteristic read complete");
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
        }];
        
    }
    
    -(void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
        [self.events resolve:@"connect" withValue:@true];
    }
    
    -(void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
        [self.events reject:@"connect" withError:error];
    }
    
    -(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
        [self.events resolve:@"disconnect" withValue:@true];
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
  
