
import { NativeEventEmitter, NativeModules } from 'react-native'
import EventEmitter from './EventEmitter'
import Device from './Device'
import Encoder from './Encoder'

/**
 * Manages discovering and connecting to services.
 * 
 * @event scan.start Scanning has started
 * @event scan.end Scanning has ended. If ended with an error, the error is returned as the event data
 * @event scan.added Discovered a new device
 * @event scan.updated A device which has already been discovered was updated
 * @event scan.removed A device is no longer in range
 * @event updated A change has occurred
 */
export default new class BLECentral extends EventEmitter {

    constructor() {
        super()

        /** 
         * List of discovered devices 
         * @type {Device[]}
         */
        this.devices = []

        /** True if scanning */
        this.scanning = false

        // Event listener
        this.emitter = new NativeEventEmitter(NativeModules.RNBluetoothLe)
        this.emitter.addListener('BLECentral:ScanEnd', this.onScanEnd.bind(this))
        this.emitter.addListener('BLECentral:ScanAdded', this.onScanAdded.bind(this))

    }

    /** 
     * Begin scanning for devices.
     * 
     * @param {string[]} serviceFilter An optional list of service UUIDs. If set, will only return devices with these services available.
     * @returns {Device[]} Resolves once the scan has started. Returns a list of already connected devices.
     */
    async startScan(serviceFilter = []) {

        // Convert all service names to UUIDs
        serviceFilter = serviceFilter.map(name => Encoder.toUUID(name))

        // Send request to native code
        await NativeModules.RNBluetoothLe.scan(serviceFilter)
        this.scanning = true
        this.emit('scan.start')
        this.emit('updated')

    }

    /**
     * Called by native code when the scan has ended.
     * 
     * @private
     */
    onScanEnd(errorText) {

        // Emit event
        this.scanning = false
        this.emit('scan.end', errorText ? new Error(errorText) : null)
        this.emit('updated')

    }

    /**
     * Called by native code when the scan has discovered a device. It may be an updated entry of an already discovered device.
     * 
     * @private
     */
    onScanAdded(deviceInfo) {

        // Check if device already exists
        let device = this.devices.find(d => d.address == deviceInfo.address)
        if (device) {

            // Device updated
            device.name = deviceInfo.name
            device.rssi = deviceInfo.rssi
            device.emit('updated', device)
            this.emit('scan.updated', device)
            this.emit('updated')

        } else {

            // Device added
            device = new Device()
            device.address = deviceInfo.address
            device.name = deviceInfo.name
            device.rssi = deviceInfo.rssi
            this.devices.push(device)
            this.emit('scan.added', device)
            this.emit('updated')

        }

    }

}