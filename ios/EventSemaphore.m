//
//  EventSemaphore.m
//  RNBluetoothLe
//
//  Created by Josh Fox on 2019/08/21.
//

#import "EventSemaphore.h"

@implementation EventSemaphore
    
    -(id) init {
        self = [super init];
        
        // Setup list of waiting operations
        self.events = [NSMutableDictionary dictionary];
        
        // Setup dictionary lock
        self.dictionaryLock = [[NSLock alloc] init];
        
        // Done
        return self;
        
    }
    
    -(id) waitFor:(NSString*)event {
        return [self waitFor:event do:^{}];
    }
    
    -(id) waitFor:(NSString*)event do:(void(^)(void))action {
        
        // Sanity check: The event should not exist already
        NSAssert(![self.events objectForKey:event], @"Event name already exists!");
        
        // Create event
        WaitFor* wait = [[WaitFor alloc] init];
        
        // Store it
        [self.dictionaryLock lock];
        [self.events setObject:wait forKey:event];
        [self.dictionaryLock unlock];
        
        // Do action
        action();
        
        // Wait for it
        [wait wait:15];
        
        // Remove it
        [self.dictionaryLock lock];
        [self.events removeObjectForKey:event];
        [self.dictionaryLock unlock];
        
        // Check if error
        if (wait.error)
            @throw wait.error;
        else
            return wait.value;
        
    }
    
    -(void) resolve:(NSString*)event withValue:(id)value {
        
        // Get event
        [self.dictionaryLock lock];
        WaitFor* eventWait = [self.events objectForKey:event];
        [self.dictionaryLock unlock];
        
        // Sanity check: The event should exist already
        //NSAssert(eventWait, @"Event must exist before it is resolved!");
        
        // Resolve
        [eventWait resolve:value];
        
    }
    
    -(void) reject:(NSString*)event withError:(NSError*)error {
        
        // Get event
        [self.dictionaryLock lock];
        WaitFor* eventWait = [self.events objectForKey:event];
        [self.dictionaryLock unlock];
        
        // Sanity check: The event should exist already
        //NSAssert(eventWait, @"Event must exist before it is rejected!");
        
        // Reject
        [eventWait reject:error];
        
    }
    
    -(void) reject:(NSString*)event withErrorText:(NSString*)error {
        
        // Create error
        NSError* err = [[NSError alloc] initWithDomain:@"failed" code:1 userInfo:@{ NSLocalizedDescriptionKey: error }];
        [self reject:event withError:err];
        
    }

@end
