
import { NativeEventEmitter, NativeModules } from 'react-native'

/**
 * Manages events received from the native module
 */
export default new class Events {

    constructor() {

        // Event listener
        this.emitter = new NativeEventEmitter(NativeModules.RNBluetoothLe)

    }

    /** Listen for an event */
    addListener(name, callback) {
        return this.emitter.addListener(name, callback)
    }

    /** Wait for the specified event, and return it's value */
    async waitFor(name, timeout = 15000, dataTest = null) {

        // Create triggerable promise
        let resolvePromise = null
        let rejectPromise = null
        let promise = new Promise((resolve, reject) => {
            resolvePromise = resolve
            rejectPromise = reject
        })

        // Create var
        let timer = null
        let subscription = null

        // Create response function
        let responder = function(data) {

            // If there's a test function, test the data and only continue if it returns true
            if (dataTest && dataTest(data) == false)
                return

            // Resolve promise
            resolvePromise(data)

            // Stop timer
            clearTimeout(timer)

            // Remove listener
            subscription.remove()

        }

        // Register listener
        subscription = this.emitter.addListener(name, responder)

        // Register timeout
        timer = setTimeout(e => {

            // Remove listener
            subscription.remove()

            // Reject promise
            rejectPromise(new Error('Expected event did not arrive.'))

        }, timeout)

        // Done
        return promise

    }

}