
import uuidv5 from 'uuid/v5'

/**
 * Represents a characteristic on a Bluetooth LE service. A characteristic can be read, writted to, and notified.
 */
export default class Characteristic {

    /** Create a new named characteristic, where the UUID is generated from the name */
    static named(name) {

        // Create it
        let chr = new Characteristic()
        chr.uuid = uuidv5(name, 'bb652ee7-940b-4ace-981f-9ce7889dae39')
        return chr

    }

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

    /**
     * Sets this characteristic to read-only, with the specified data.
     * 
     * @chainable
     * @param {string} txt The data to set.
     */
    withValue(txt) {
        this.canRead = true
        this.canWrite = false
        this.data = txt
        this.writeCallback = null
        return this
    }

}