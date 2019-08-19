package com.rnbluetoothle;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Future;
import java.util.concurrent.FutureTask;

public class SettableFuture<T> {

    // Synchronizes threads
    CountDownLatch latch = new CountDownLatch(1);

    // Success value
    T value = null;

    // Fail exception
    Exception error = null;

    // Future
    Future<T> future = null;

    /** Get future */
    public Future<T> getFuture() {

        // Create if needed
        if (future == null)
            future = new FutureTask<T>(() -> this.get());

        // Done
        return future;

    }

    /** Manually wait for the result */
    public T get() throws Exception {

        // Wait for completion
        latch.await();

        // Check return value
        if (error != null)
            throw error;
        else
            return value;

    }

    /** Resolve with value */
    public void resolve(T value) {
        this.value = value;
        latch.countDown();
    }

    /** Reject with error */
    public void reject(Exception e) {
        this.error = e;
        latch.countDown();
    }

}
