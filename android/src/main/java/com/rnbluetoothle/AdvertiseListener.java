package com.rnbluetoothle;

import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseSettings;
import android.os.Build;
import android.support.annotation.RequiresApi;
import android.util.Log;

@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class AdvertiseListener extends AdvertiseCallback {

    /** Link back to the main module */
    BLE module = null;

    /** Promise to resolve when done */
    SettableFuture<Void> startPromise = null;

    /** Constructor */
    AdvertiseListener(BLE module) {
        super();
        this.module = module;
    }

    @Override
    public void onStartFailure(int errorCode) {
        super.onStartFailure(errorCode);

        // Get reason
        String error = "An unknown error occurred when trying to start advertising.";
        if (errorCode == ADVERTISE_FAILED_ALREADY_STARTED)
            error = "Unable to start advertising, it has already been started.";
        else if (errorCode == ADVERTISE_FAILED_DATA_TOO_LARGE)
            error = "Unable to start advertising, data is too large.";
        else if (errorCode == ADVERTISE_FAILED_FEATURE_UNSUPPORTED)
            error = "Unable to start advertising, this feature is not supported on this device.";
        else if (errorCode == ADVERTISE_FAILED_TOO_MANY_ADVERTISERS)
            error = "Unable to start advertising, there are too many advertisers.";

        Log.e("BLE", "Failed to start advertising! Code " + errorCode);
        if (startPromise != null)
            startPromise.reject(new Exception(error));

    }

    @Override
    public void onStartSuccess(AdvertiseSettings settingsInEffect) {
        super.onStartSuccess(settingsInEffect);

        Log.i("BLE", "Advertising has started successfully.");
        if (startPromise != null)
            startPromise.resolve(null);

    }

}
