
#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif

#import <React/RCTEventEmitter.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "EventSemaphore.h"

@interface RNBluetoothLe : RCTEventEmitter <RCTBridgeModule, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>
    
    // Operation queue
    @property (retain) dispatch_queue_t queue;
    @property (retain) EventSemaphore* events;
    
    // Peripheral vars
    @property (retain) CBPeripheralManager* peripheralManager;
    @property (retain) NSMutableDictionary<NSString*, CBService*>* services;
    
    // Central vars
    @property (retain) CBCentralManager* centralManager;
    @property (retain) NSMutableArray<CBPeripheral*>* queryingPeripherals;

@end
  
