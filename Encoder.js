
import uuidv5 from 'uuid/v5'

const UUIDRegex = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/gi
const Namespace = 'bb652ee7-940b-4ace-981f-9ce7889dae39'

/**
 * This class handles encoding and decoding data.
 */
export default class Encoder {

    /** Get a UUID from a named ID. If the string is already a UUID, it is passed back directly. */
    static toUUID(txt) {

        // Convert to string if needed
        if (typeof txt != 'string')
            txt = '' + txt

        // Check if already a UUID
        if (UUIDRegex.exec(txt))
            return txt

        // Convert to a named UUID
        return uuidv5(txt, Namespace)

    }

}