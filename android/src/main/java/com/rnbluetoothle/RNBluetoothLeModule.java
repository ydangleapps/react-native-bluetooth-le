
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
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.ParcelUuid;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

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

    @ReactMethod
    public void scan(ReadableArray serviceFilter, Promise promise) {

        // Fail if Android version is too low
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            promise.reject("unsupported", "This feature is not supported on this version of Android.");
            return;
        }

        // Create UUID array
        ArrayList<UUID> services = new ArrayList<UUID>();
        for (int i = 0 ; i < serviceFilter.size() ; i++)
            services.add(UUID.fromString(serviceFilter.getString(i)));

        // Start scan
        BLE.get(getReactApplicationContext()).scan(services, new BLE.ScanListener() {

            @Override
            void onStart() {

                // Successfully started
                promise.resolve(true);

            }

            @Override
            void onStartFailed(Exception ex) {

                // Failed to start
                promise.reject("failed", ex.getLocalizedMessage());

            }

            @Override
            void onScanStopped(Exception ex) {

                // Scan interrupted by our code
                getReactApplicationContext()
                        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                        .emit("BLECentral:ScanEnd", ex == null ? "" : ex.getLocalizedMessage());

            }

            @Override
            public void onScanFailed(int errorCode) {
                super.onScanFailed(errorCode);

                // Get error description
                String error = "An unknown error occurred.";
                if (errorCode == ScanCallback.SCAN_FAILED_INTERNAL_ERROR)
                    error = "An internal error occurred.";
                else if (errorCode == ScanCallback.SCAN_FAILED_ALREADY_STARTED)
                    error = "Another scan has already been started.";
                else if (errorCode == ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED)
                    error = "Unable to register the application.";
                else if (errorCode == ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED)
                    error = "This feature is not supported on this device.";

                // Scan interrupted by the system
                getReactApplicationContext()
                        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                        .emit("BLECentral:ScanEnd", "Scan interrupted. " + error);

            }

            @TargetApi(Build.VERSION_CODES.LOLLIPOP)
            @Override
            public void onScanResult(int callbackType, ScanResult result) {
                super.onScanResult(callbackType, result);

                // Create device info
                WritableMap device = Arguments.createMap();
                device.putInt("rssi", result.getRssi());
                device.putString("name", result.getDevice().getName());
                device.putString("address", result.getDevice().getAddress());

                // Found a result
                if (callbackType == ScanSettings.CALLBACK_TYPE_MATCH_LOST) {

                    // Device lost
                    getReactApplicationContext()
                            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                            .emit("BLECentral:ScanRemoved", device);

                } else {

                    // Device found or updated
                    getReactApplicationContext()
                            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                            .emit("BLECentral:ScanAdded", device);

                }

            }
        });

    }

}