
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
    @property (strong) dispatch_queue_t queue;
    @property (strong) EventSemaphore* events;
    
    // Peripheral vars
    @property (strong) CBPeripheralManager* peripheralManager;
    @property (strong) NSMutableDictionary<NSString*, CBService*>* services;
    
    // Central vars
    @property (strong) CBCentralManager* centralManager;
    @property (strong) NSMutableArray<CBPeripheral*>* queryingPeripherals;
    @property (strong) NSMutableDictionary<NSString*, CBPeripheral*>* idToPeripheral;

@end
  
