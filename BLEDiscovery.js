
import uuidv4 from 'uuid/v4'
import uuidv5 from 'uuid/v5'
import Characteristic from './Characteristic'
import BLEPeripheral from './BLEPeripheral'
import EventEmitter from './EventEmitter'
import BLECentral from './BLECentral'
import { AppState } from 'react-native'

/**
 * This class allows for advertising data to other nearby devices, and for discovering data advertised by other devices.
 * 
 * @event device.found Called when a device has been found. Includes the device as the event data.
 * @event updated Called when the array of devices has been modified.
 */
export default new class BLEDiscovery extends EventEmitter {

    constructor() {
        super()

        /** List of discovered devices */
        this.devices = []

        /** Last error */
        this.error = null

        /** Listen for app state changes */
        this.appState = 'active'
        AppState.addEventListener('change', this.onAppState.bind(this))

    }

    /** Current state of discovery */
    get state() {

        // Check state and return a string
        if (!this.isSetup)
            return "Not set up"
        else if (!this.enabled)
            return "Disabled"
        else if (this.error)
            return this.error.message
        else
            return "Enabled"

    }

    /** 
     * Setup. Call this once in your app. Options includes:
     * 
     * - `groupID` : A string identifying a group of devices to discover. You can pass your app ID, eg 'com.myapp'.
     * - `deviceID` : A string identifying the current device. 
     * 
    */
    async setup(opts) {

        // Stop if already set up
        if (this.isSetup) throw new Error('You must only call BLEDiscovery.setup() once.')
        this.isSetup = true

        // Generate service UUID
        if (!opts.groupID) throw new Error(`Please specify a 'groupID'.`)
        this.serviceName = 'discovery:' + opts.groupID

        // Get device ID
        this.deviceID = opts.deviceID || uuidv4()

    }

    /** Call this to enable discovery and advertisement. */
    async enable() {

        // Catch errors
        try {

            // Stop if already enabled
            if (this.enabled) return
            this.enabled = true

            // Start advertising this device
            await this.save()

            // Start discovering devices
            BLECentral.addEventListener('scan.added', this.onDeviceFound.bind(this))
            BLECentral.addEventListener('scan.updated', this.onDeviceFound.bind(this))
            BLECentral.addEventListener('scan.end', this.onScanEnd.bind(this))
            await BLECentral.startScan([this.serviceName])

            // Enabled successfully
            this.error = null

        } catch (err) {

            // Store error
            this.error = err
            throw err

        }

    }

    /** Call this to disable discovery and advertisement. */
    disable() {

        // Stop if already disabled
        if (!this.enabled) return
        this.enabled = false

        // TODO: Stop and remove data and listeners
        // Start discovering devices
        //BLECentral.addEventListener('scan.added', this.onDeviceFound.bind(this))
        //BLECentral.addEventListener('scan.end', this.onScanEnd.bind(this))
        BLECentral.stopScan()

        // Start advertising this device
        //this.save()

    }

    /** Call this after modifying the data property. This sends the data to the device's GATT server and creates the BLE service. */
    async save() {

        // Stop if not enabled
        if (!this.enabled)
            return

        // Make sure user has called .setup() first
        if (!this.deviceID)
            throw new Error('You must call BLEDiscovery.setup() first.')

        // Create data characteristics
        let characteristics = this.getCharacteristicsForData()

        // Create message characteristic
        let msgChr = Characteristic.named('msg')
        msgChr.canRead = false
        msgChr.canWrite = true
        msgChr.writeCallback = this.onMessageCharacteristicWrite.bind(this)
        characteristics.push(msgChr)

        // Create service
        await BLEPeripheral.createService(this.serviceName, characteristics.map(chr => ({
            uuid: chr.uuid,
            canRead: chr.canRead,
            canWrite: chr.canWrite,
            data: chr.data
        })))

    }

    /** 
     * Advertised data. This must be a JSON-serializable object.
     * 
     * @type {object}
     */
    data = {}

    /**
     * Sets the advertisement data and begins broadcasting it. This can be called again if the data changes.
     * This is a shortcut for modifying `.data` directly and then calling `.save()`.
     */
    advertise(data) {
        this.data = data
        this.save()
    }

    /**
     * Creates a list of characteristics for the current data. This is pretty nasty, but "long read" characteristics seems
     * EXTREMELY buggy on iOS.
     * 
     * @private
     * @returns {Characteristic[]} The characteristics to register on the service.
     */
    getCharacteristicsForData() {

        // Copy data
        let data = Object.assign({}, this.data)

        // Ensure ID is set
        if (!data.id)
            data.id = this.deviceID

        // Create string
        let text = JSON.stringify(data)

        // Break into packets
        let packetSize = 20//448
        let packets = []
        for (let i = 0 ; i < text.length ; i += packetSize)
            packets.push(text.substring(i, i + packetSize))

        // Create a characteristic for each packet
        let characteristics = []
        for (let i = 0 ; i < packets.length ; i++) {

            // Add opcode to indicate if there's more packets
            let packet = packets[i]
            if (i < packets.length-1)
                packet += String.fromCharCode(1)

            // Create characteristic
            let chr = Characteristic.named('data#spl:' + i).withValue(packet)
            characteristics.push(chr)

        }

        // Done
        return characteristics

    }

    /**
     * Called when another device writes to our 'message' characteristic.
     * 
     * @private
     * @param {string} data The data written by the other device
     * @param {string} fromUUID The sender device's bluetooth UUID
     */
    onMessageCharacteristicWrite(data, fromUUID) {
        console.warn('MSG ' + data)
    }

    /**
     * Called when a device is discovered.
     * 
     * @private
     * @param {Device} device The discovered device.
     */
    async onDeviceFound(device) {

        try {

            // Check if device has been read already
            if (device.dataTimestamp > Date.now() - 1000 * 60 * 5) return console.log('Skipping device, already attempted a read: ' + (device.data && device.data.name || device.name || device.address))
            device.dataTimestamp = Date.now()

            // Read data from device
            let txt = ''
            let index = 0
            while (true) {

                // Read data one payload at a time
                let payload = await device.read(this.serviceName, 'data#spl:' + index)

                // Check if more is coming
                if (payload.substring(payload.length-1) == String.fromCharCode(1)) {

                    // More is coming
                    txt += payload.substring(0, payload.length-1)
                    index += 1

                } else {

                    // No more
                    txt += payload
                    break

                }

            }

            // Decode JSON
            let json = null
            try {
                json = JSON.parse(txt)
            } catch (err) {
                throw new Error('Unable to parse JSON from "' + txt + '"')
            }

            // Remove existing device
            this.devices = this.devices.filter(d => d.data.id != json.id)

            // Add device
            device.data = json
            this.devices.push(device)
            this.emit('device.found', device)
            this.emit('updated')

        } catch (err) {

            // Failed
            console.warn('Failed to read device data for ' + (device.name || device.address) + ': ' + err.message);

        }

    }

    /**
     * Called by BLECentral when the scan comes to an end.
     * 
     * @private
     */
    onScanEnd(error) {

        // Log it
        console.warn('Scan ended! ' + (error ? error.message : ''))

        // TODO: Start scan again

    }

    /**
     * Called when the app foreground state changes.
     * 
     * @param {string} newState 
     */
    onAppState(newState) {

        // Check if state changed
        if (this.appState == newState) return
        this.appState = newState

        // Check it
        if (newState == 'active' && this.enabled) {

            // Restart scan
            BLECentral.startScan([this.serviceName])

        } else {

            // Stop scan
            BLECentral.stopScan()

        }

    }

}