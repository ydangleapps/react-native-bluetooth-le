
package com.rnbluetoothle;

import android.annotation.TargetApi;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.UUID;

public class RNBluetoothLeModule extends ReactContextBaseJavaModule {

    public RNBluetoothLeModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public String getName() {
        return "RNBluetoothLe";
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    @ReactMethod
    public void createService(String uuid, ReadableArray characteristics, Promise promise) {

        // Fail if Android version is too low
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            promise.reject("unsupported", "This feature is not supported on this version of Android.");
            return;
        }

        // Create a service
        BluetoothGattService svc = new BluetoothGattService(UUID.fromString(uuid), BluetoothGattService.SERVICE_TYPE_PRIMARY);

        // Add characteristics
        for (int i = 0 ; i < characteristics.size() ; i++) {

            // Get characteristic info
            ReadableMap info = characteristics.getMap(i);
            String uuidChr = info.getString("uuid");
            boolean canRead = info.getBoolean("canRead");
            boolean canWrite = info.getBoolean("canWrite");
            String data = info.getString("data");

            // Create properties
            int props = 0;
            if (canRead) props |= BluetoothGattCharacteristic.PROPERTY_READ;
            if (canWrite) props |= BluetoothGattCharacteristic.PROPERTY_WRITE;

            // Create permissions
            int permissions = 0;
            if (canRead) permissions |= BluetoothGattCharacteristic.PERMISSION_READ;
            if (canWrite) permissions |= BluetoothGattCharacteristic.PERMISSION_WRITE;

            // Create it
            BluetoothGattCharacteristic chr = new BluetoothGattCharacteristic(UUID.fromString(uuidChr), props, permissions);

            // If data is set, store data
            if (data != null)
                chr.setValue(data);

            // Add to service
            svc.addCharacteristic(chr);

        }

        // Add service
        BLE.get(getReactApplicationContext()).createService(svc, (v, err) -> {
            if (err != null) {
                promise.reject("failed", err.getLocalizedMessage());
                Log.i("BLE", "Failed: " + err);
            } else {
                promise.resolve(true);
                Log.i("BLE", "Successfully added service");
            }
        });

    }

    @ReactMethod
    public void removeService(String uuid, Promise promise) {

        // Remove service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            BLE.get(getReactApplicationContext()).removeService(UUID.fromString(uuid), null);
        }

        // Can't fail
        promise.resolve(true);

    }

}