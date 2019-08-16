
#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif

#import <React/RCTEventEmitter.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface RNBluetoothLe : RCTEventEmitter <RCTBridgeModule, CBPeripheralManagerDelegate>
    
    @property (retain) CBPeripheralManager* peripheralManager;
    @property (retain) NSMutableDictionary<NSString*, CBService*>* services;

@end
  
