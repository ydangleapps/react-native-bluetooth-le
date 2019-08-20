
import { NativeEventEmitter, NativeModules } from 'react-native'
import Encoder from './Encoder'

/**
 * Manages creating services.
 */
export default new class BLEPeripheral {

    /** Constructor */
    constructor() {

        /** True if bluetooth is ready */
        this.ready = false

        // Add an event listener
        this.emitter = new NativeEventEmitter(NativeModules.RNBluetoothLe)
        this.emitter.addListener('BLEPeripheral:ReadyStateChanged', this.onReadyStateChange.bind(this))

        // List of registered services
        this.services = {}

    }

    /** Called when the bluetooth state changes */
    onReadyStateChange(state) {

        // Check if ready
        this.ready = state == 'ready'

        // If ready, re-register services
        if (this.ready) {
            for (let uuid in this.services) {
                console.warn('BLE: Recreating service ' + uuid + ' with ' + this.services[uuid].length + ' characteristic(s).')
                NativeModules.RNBluetoothLe.createService(uuid, this.services[uuid])
            }
        }

    }

    /** 
     * Create a service.
     * 
     * @param {string} name The name or UUID for your service.
     * @param {Characteristic[]} The list of characteristics.
     */
    async createService(name, characteristics) {

        // Convert name to UUID
        let uuid = Encoder.toUUID(name)

        // Store service
        this.services[uuid] = characteristics

        // Send to native code if ready
        console.warn('BLE: Creating service ' + uuid + ' with ' + characteristics.length + ' characteristic(s).')
        await NativeModules.RNBluetoothLe.createService(uuid, characteristics)

    }

    /**
     * Remove the specified service.
     * 
     * @param {string} name The service's name or UUID.
     */
    async removeService(name) {
        return await NativeModules.RNBluetoothLe.removeService(Encoder.toUUID(uuid))
    }

}