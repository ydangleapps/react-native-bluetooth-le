
/**
 * Represents a characteristic on a Bluetooth LE service. A characteristic can be read, writted to, and notified.
 */
export default class Characteristic {

    /** Characteristic ID */
    uuid = null

    /** True if can be read */
    canRead = false

    /** True if can be written to */
    canWrite = false

    /** Fixed data. If set, this data will be advertised even while the app is closed. */
    data = null

    /** 
     * If canWrite is true, when a remote device writes to this characteristic this callbback
     * will be called with the written data.
     */
    writeCallback = null

}