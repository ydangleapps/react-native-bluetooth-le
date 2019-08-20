
import uuidv4 from 'uuid/v4'
import uuidv5 from 'uuid/v5'
import Characteristic from './Characteristic'
import BLEPeripheral from './BLEPeripheral'
import EventEmitter from './EventEmitter'
import BLECentral from './BLECentral'

/**
 * This class allows for advertising data to other nearby devices, and for discovering data advertised by other devices.
 */
export default new class BLEDiscovery extends EventEmitter {

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
        let namespace = 'bb652ee7-940b-4ace-981f-9ce7889dae39'
        this.serviceUUID = uuidv5(opts.groupID, namespace)

        // Get device ID
        this.deviceID = opts.deviceID || uuidv4()

        // Start discovering devices
        BLECentral.addEventListener('scan.added', this.onDeviceFound.bind(this))
        BLECentral.startScan([this.serviceUUID])

    }

    /** Call this after modifying the data property. This sends the data to the device's GATT server and creates the BLE service. */
    save() {

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
        BLEPeripheral.createService(this.serviceUUID, characteristics.map(chr => ({
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
     * Creates a list of characteristics for the current data.
     * 
     * @private
     * @returns {Characteristic[]} The characteristics to register on the service.
     */
    getCharacteristicsForData() {

        // Add device ID to the data
        let data = this.data/*Object.assign({}, this.data, {
            _id: this.deviceID
        })*/

        // Create string
        let text = JSON.stringify(data)

        // Break into packets
        let packetSize = 448
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
            let chr = Characteristic.named('data#spl:').withValue(packet)
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
    onDeviceFound(device) {

        console.warn('DISCOVERED ' + device.name + ' ' + device.address)

    }

}