
import EventEmitter from "./EventEmitter"

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

}