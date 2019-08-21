package com.rnbluetoothle;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.os.Build;
import android.support.annotation.RequiresApi;

import java.util.ArrayList;

/** Represents a GATT connection to a device. */
@RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR2)
public class BLEConnection extends BluetoothGattCallback {

    /** Remote device */
    BluetoothDevice remoteDevice = null;

    /** GATT server connection */
    BluetoothGatt gatt = null;

    /** Pending operations */
    SettableFuture<Void> pendingConnection = null;
    SettableFuture<Void> pendingServices = null;
    SettableFuture<byte[]> pendingCharacteristicRead = null;

    /** True if connected */
    boolean isConnected = false;

    @Override
    public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
        super.onConnectionStateChange(gatt, status, newState);

        // Get error text
        String error = getError(status);

        // Check if connected
        if (error != null) {

            // Disconnected
            isConnected = false;
            if (pendingConnection != null) {
                pendingConnection.reject(new Exception("Connection failed."));
                pendingConnection = null;
            }

        } else if (newState == BluetoothGatt.STATE_CONNECTED) {

            // Connected again!
            isConnected = true;
            if (pendingConnection != null) {
                pendingConnection.resolve(null);
                pendingConnection = null;
            }

        }

    }

    /** Get error text from GATT status */
    public static String getError(int status) {

        if (status == BluetoothGatt.GATT_CONNECTION_CONGESTED)
            return "The connection is congested.";
        else if (status == BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION)
            return "Insufficient authentication.";
        else if (status == BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION)
            return "Insufficient encryption.";
        else if (status == BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH)
            return "Invalid attribute length.";
        else if (status == BluetoothGatt.GATT_INVALID_OFFSET)
            return "Invalid offset.";
        else if (status == BluetoothGatt.GATT_WRITE_NOT_PERMITTED)
            return "Write not permitted.";
        else if (status == BluetoothGatt.GATT_SUCCESS)
            return null;
        else
            return "An unknown error occurred.";

    }

    @Override
    public void onServicesDiscovered(BluetoothGatt gatt, int status) {
        super.onServicesDiscovered(gatt, status);

        // Get error text
        String error = getError(status);

        // Check if error
        if (error == null) {

            // Done
            if (pendingServices != null) {
                pendingServices.resolve(null);
                pendingServices = null;
            }

        } else {

            // Failed
            if (pendingServices != null) {
                pendingServices.reject(new Exception(error));
                pendingServices = null;
            }

        }

    }

    @Override
    public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
        super.onCharacteristicRead(gatt, characteristic, status);

        // Get error text
        String error = getError(status);

        // Check if error
        if (error == null) {

            // Done
            if (pendingCharacteristicRead != null) {
                pendingCharacteristicRead.resolve(characteristic.getValue());
                pendingCharacteristicRead = null;
            }

        } else {

            // Failed
            if (pendingCharacteristicRead != null) {
                pendingCharacteristicRead.reject(new Exception(error));
                pendingCharacteristicRead = null;
            }

        }

    }
}
