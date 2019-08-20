
import EventEmitter from "./EventEmitter"
import { NativeModules } from 'react-native'
import Encoder from "./Encoder";

/**
 * Represents a remote Bluetooth LE device.
 * 
 * @event updated Details about this device have changed.
 */
export default class Device extends EventEmitter {

    /** The device name */
    name = ''

    /** The device address */
    address = ''

    /** Signal strength of this device */
    rssi = 0

    /** When using BLEDiscovery, this contains the device's advertised data. It will be NULL if device data has not been read yet. */
    data = null

    /** When using BLEDiscovery, this contains the timestamp of when the data was last read. */
    dataTimestamp = 0

    /** 
     * Read a characteristic's data value.
     * 
     * @param {string} service Service name or UUID.
     * @param {string} characteristic Characteristic name or UUID.
     */
    async read(service, characteristic) {

        // Read it
        return await NativeModules.RNBluetoothLe.readCharacteristic(Encoder.toUUID(service), Encoder.toUUID(characteristic))

    }

}