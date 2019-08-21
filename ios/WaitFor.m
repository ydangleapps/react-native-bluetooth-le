//
//  WaitFor.m
//  RNBluetoothLe
//
//  Created by Josh Fox on 2019/08/21.
//

#import "WaitFor.h"

@interface NSError (Helper)
    +(instancetype) errorWithText:(NSString*)txt;
@end

@implementation WaitFor
    
    // Constructor
    -(id) init {
        self = [super init];
        
        // Create semaphore
        self.semaphore = dispatch_semaphore_create(0);
        self.isComplete = NO;
        
        // Done
        return self;
        
    }
    
    -(void) wait:(NSTimeInterval)timeout {
        
        // Stop if already complete
        if (self.isComplete)
            return;
        
        // Wait for semaphore
        long result = dispatch_semaphore_wait(self.semaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * 1000000000L));
        
        // Check if timed out
        if (result)
            self.error = [NSError errorWithText:@"Operation timed out."];
        
    }
    
    /// Signals the operation is complete, with the specified value
    -(void) resolve:(id)value {
        
        // Stop if already complete
        if (self.isComplete)
            return;
        
        // Store result
        self.value = value;
        
        // Notify semaphore
        dispatch_semaphore_signal(self.semaphore);
        
    }
    
    /// Signals the operation has failed
    -(void) reject:(NSError*)error {
        
        // Stop if already complete
        if (self.isComplete)
            return;
        
        // Store result
        self.error = error;
        
        // Notify semaphore
        dispatch_semaphore_signal(self.semaphore);
        
    }

@end
