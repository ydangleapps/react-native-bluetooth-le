
#import "RNBluetoothLe.h"

@implementation RNBluetoothLe
    
    RCT_EXPORT_MODULE()

    /// Which thread the JS functions are called on
    -(dispatch_queue_t) methodQueue {
        return dispatch_get_main_queue();
    }
    
    /// Which events we send to JS
    -(NSArray<NSString*>*)supportedEvents {
        return @[@"BLEPeripheral:StateChanged"];
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
            
            // Create manager
            self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:opts];
            
        }
        
        // Send current state
        [self peripheralManagerDidUpdateState:self.peripheralManager];
        
    }
    
    /// Called when the bluetooth power state changes
    -(void) peripheralManagerDidUpdateState:(CBPeripheralManager*)peripheral {
        
        // Get state
        NSString* state = @"";
        if (peripheral.state == CBManagerStatePoweredOn)
            state = @"ready";
        else if (peripheral.state == CBManagerStateUnsupported)
            state = @"unsupported";
        else if (peripheral.state == CBManagerStatePoweredOff)
            state = @"off";
        else if (peripheral.state == CBManagerStateUnauthorized)
            state = @"unauthorized";
        
        // Notify JS
        [self sendEventWithName:@"BLEPeripheral:StateChanged" body:state];
        
    }
    
    /// Called to create a new peripheral service. If UUID already exists, it will be removed first.
    RCT_REMAP_METHOD(createService, createServiceWithUUID:(NSString*)uuidStr characteristics:(NSArray*)characteristicDescriptions) {
        
        // Prepare peripheral manager
        [self preparePeripheral];
        
        // Create service
        CBMutableService* svc = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:uuidStr] primary:YES];
        
        // Add each characteristic
        NSMutableArray* chrs = [NSMutableArray array];
        for (NSDictionary* dict in characteristicDescriptions) {
            
            // Fetch characteristic info
            NSString* uuid = [dict valueForKey:@"uuid"];
            BOOL canRead = [[dict valueForKey:@"canRead"] boolValue];
            BOOL canWrite = [[dict valueForKey:@"canWrite"] boolValue];
            NSString* dataStr = [dict valueForKey:@"data"];
            if (dataStr.length == 0)
                dataStr = nil;
            
            // Create properties
            CBCharacteristicProperties props = 0;
            if (canRead) props |= CBCharacteristicPropertyRead;
            if (canWrite) props |= CBCharacteristicPropertyWrite;
            
            // Convert data to NSData if exists
            NSData* data = [dataStr dataUsingEncoding:NSUTF8StringEncoding];
            
            // Create characteristic
            CBMutableCharacteristic* chr = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:uuid] properties:props value:data permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];
            
            // Save it
            [chrs addObject:chr];
            
        }
        
        // Register service
        svc.characteristics = chrs;
        [self.peripheralManager addService:svc];
        
    }

@end
  
