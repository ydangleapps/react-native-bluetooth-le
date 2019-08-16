
import uuidv4 from 'uuid/v4'
import uuidv5 from 'uuid/v5'
import Characteristic from './Characteristic'
import BLEPeripheral from './BLEPeripheral'

// Message characteristic, used for sending messages to the user's app
let MessageCharacteristicUUID = 'ab7518a6-81d3-451d-b772-1f580f707a83'

// Data characteristic, used for broadcasting the user's advertisement data. Depending
// on the size of the user's advertisement data, there may be multiple data
// characteristics needed to advertise it all.
function dataCharacteristicUUID(index) {
    return uuidv5('split:' + index, 'bb652ee7-940b-4ace-981f-9ce7889dae39')
}

/**
 * This class allows for advertising data to other nearby devices, and for discovering data advertised by other devices.
 */
export default new class BLEDiscovery {

    /** 
     * Setup. Call this once in your app. Options includes:
     * 
     * - `groupID` : A string identifying a group of devices to discover. You can pass your app ID, eg 'com.myapp'.
     * - `deviceID` : A string identifying the current device. 
     * 
    */
    async setup(opts) {

        // Generate service UUID
        if (!opts.groupID) throw new Error(`Please specify a 'groupID'.`)
        let namespace = 'bb652ee7-940b-4ace-981f-9ce7889dae39'
        this.serviceUUID = uuidv5(opts.groupID, namespace)

        // Get device ID
        this.deviceID = opts.deviceID || uuidv4()

    }

    /** Call this after modifying the data property. This sends the data to the device's GATT server and cerates the BLE service. */
    save() {

        // Make sure user has called .setup() first
        if (!this.deviceID)
            throw new Error('You must call BLEDiscovery.setup() first.')

        // Create data characteristics
        let characteristics = this.getCharacteristicsForData()

        // Create message characteristic
        let msgChr = new Characteristic()
        msgChr.uuid = MessageCharacteristicUUID
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
            let chr = new Characteristic()
            chr.uuid = dataCharacteristicUUID(i)
            chr.canRead = true
            chr.canWrite = false
            chr.data = packet
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

}