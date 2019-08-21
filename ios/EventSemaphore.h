//
//  EventSemaphore.h
//  RNBluetoothLe
//
//  Created by Josh Fox on 2019/08/21.
//

#import <Foundation/Foundation.h>
#import "WaitFor.h"

NS_ASSUME_NONNULL_BEGIN

/// This class pauses a thread until an event has been triggered from another thread.
@interface EventSemaphore : NSObject
    
    @property (retain) NSMutableDictionary<NSString*, WaitFor*>* events;
    @property (retain) NSLock* dictionaryLock;
    
    -(id) waitFor:(NSString*)event;
    -(id) waitFor:(NSString*)event do:(void(^)(void))action;
    -(void) resolve:(NSString*)event withValue:(id)value;
    -(void) reject:(NSString*)event withError:(NSError*)error;
    -(void) reject:(NSString*)event withErrorText:(NSString*)error;

@end

NS_ASSUME_NONNULL_END
