package com.rnbluetoothle;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.os.Build;
import android.support.annotation.RequiresApi;
import android.util.Log;

@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class GATTListener extends BluetoothGattServerCallback {

    /** Link back to the main module */
    BLE module = null;

    /** Constructor */
    GATTListener(BLE module) {
        super();
        this.module = module;
    }


    @Override
    public void onServiceAdded(int status, BluetoothGattService service) {
        super.onServiceAdded(status, service);

        // Refresh advertising state
        Log.i("BLE GATT", "Service added: " + service.getUuid());

        // Fetch the promise
        SettableFuture p = module.pendingPromises.get(service.getUuid());
        if (p == null)
            return;

        // Remove it
        module.pendingPromises.remove(service.getUuid());

        // Complete it
        if (status == BluetoothGatt.GATT_SUCCESS)
            p.resolve(null);
        else
            p.reject(new Exception("Unable to create service. Code " + status));

    }

    @Override
    public void onCharacteristicReadRequest(BluetoothDevice device, int requestId, int offset, BluetoothGattCharacteristic characteristic) {
        super.onCharacteristicReadRequest(device, requestId, offset, characteristic);

        // We don't support offsets
        if (offset != 0) {
            Log.i("BLE GATT", "Device tried to read a characteristic, but we don't support offsets.");
            module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null);
            return;
        }

        // TODO: Support dynamic data, query back to Javascript

        // Check if characteristic has data
        if (characteristic.getValue() != null) {

            // Send data back
            Log.i("BLE GATT", "Device read characteristic: " + characteristic.getUuid());
            module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, characteristic.getValue());
            return;

        }

        // We don't know how to serve this request
        Log.i("BLE GATT", "Device tried to read a characteristic, but we don't have any data for it.");
        module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, offset, null);

    }

    @Override
    public void onCharacteristicWriteRequest(BluetoothDevice device, int requestId, BluetoothGattCharacteristic characteristic, boolean preparedWrite, boolean responseNeeded, int offset, byte[] value) {
        super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value);

        // Stop if no response needed
        if (!responseNeeded)
            return;

        // We don't support writing yet
        Log.i("BLE GATT", "Device tried to write a characteristic, but we don't support that.");
        module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, offset, null);

    }

    @Override
    public void onDescriptorReadRequest(BluetoothDevice device, int requestId, int offset, BluetoothGattDescriptor descriptor) {

        // We don't support offsets
        if (offset != 0) {
            Log.i("BLE GATT", "Device tried to read a descriptor, but we don't support offsets.");
            module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null);
            return;
        }

        // Check if characteristic has data
        if (descriptor.getValue() != null) {

            // Send data back
            Log.i("BLE GATT", "Device read descriptor: " + descriptor.getUuid());
            module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, descriptor.getValue());
            return;

        }

        // We don't know how to serve this request
        Log.i("BLE GATT", "Device tried to read a descriptor, but we don't have any data for it.");
        module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, offset, null);

    }

    @Override
    public void onConnectionStateChange(BluetoothDevice device, int status, int newState) {
        super.onConnectionStateChange(device, status, newState);

        Log.i("BLE GATT", "Connection state changed for " + device.getName() + ": " + newState);

    }

    @Override
    public void onDescriptorWriteRequest(BluetoothDevice device, int requestId, BluetoothGattDescriptor descriptor, boolean preparedWrite, boolean responseNeeded, int offset, byte[] value) {
        super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value);

        // Stop if no response needed
        if (!responseNeeded)
            return;

        // We don't support writing yet
        Log.i("BLE GATT", "Device tried to write a descriptor, but we don't support that.");
        module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null);


    }

    @Override
    public void onExecuteWrite(BluetoothDevice device, int requestId, boolean execute) {
        super.onExecuteWrite(device, requestId, execute);

        // We don't support writing yet
        Log.i("BLE GATT", "Device tried to execute a write, but we don't support that.");
        module.gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null);

    }

    @Override
    public void onMtuChanged(BluetoothDevice device, int mtu) {
        super.onMtuChanged(device, mtu);

        // Log it
        Log.i("BLE GATT", "Device has changed the MTU to " + mtu);

    }

    @Override
    public void onNotificationSent(BluetoothDevice device, int status) {
        super.onNotificationSent(device, status);

        // Log status
        if (status == BluetoothGatt.GATT_SUCCESS)
            Log.i("BLE GATT", "Notification has been sent to " + device.getName());
        else
            Log.w("BLE GATT", "Notification failed to send to " + device.getName());

    }
}
