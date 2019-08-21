//
//  WaitFor.h
//  RNBluetoothLe
//
//  Created by Josh Fox on 2019/08/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WaitFor : NSObject
    
    @property (retain) dispatch_semaphore_t semaphore;
    @property (retain) id value;
    @property (retain) NSError* error;
    @property BOOL isComplete;
    
    /// Waits for the process to complete. If there was an error, `.error` will be set, otherwise `.value` will be set.
    -(void) wait:(NSTimeInterval)timeout;
    
    /// Signals the operation is complete, with the specified value
    -(void) resolve:(id)value;
    
    /// Signals the operation has failed
    -(void) reject:(NSError*)value;

@end

NS_ASSUME_NONNULL_END
