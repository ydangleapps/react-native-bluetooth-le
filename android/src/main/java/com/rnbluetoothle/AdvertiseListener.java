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

    /** Constructor */
    AdvertiseListener(BLE module) {
        super();
        this.module = module;
    }

    @Override
    public void onStartFailure(int errorCode) {
        super.onStartFailure(errorCode);

        Log.e("BLE", "Failed to start advertising! Code " + errorCode);

    }

    @Override
    public void onStartSuccess(AdvertiseSettings settingsInEffect) {
        super.onStartSuccess(settingsInEffect);

        Log.i("BLE", "Advertising has started successfully.");

    }
}
