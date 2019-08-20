package com.rnbluetoothle;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.ParcelUuid;
import android.support.annotation.RequiresApi;
import android.util.Log;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/**
 * This class handles the main interaction with the Bluetooth LE hardware.
 */
@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class BLE {

    /** Callback with value */
    interface Callback<T> {
        void run(T value, Exception ex);
    }

    /** Scan listener */
    static abstract class ScanListener extends ScanCallback {

        /** Called when scanning has started successfully */
        abstract void onStart();

        /** Called when scanning failed to start */
        abstract void onStartFailed(Exception ex);

        /** Called when the scan is stopped */
        abstract void onScanStopped(Exception ex);

    }

    /** Singleton */
    public static BLE get(Context ctx) {
        if (singleton == null) singleton = new BLE(ctx.getApplicationContext());
        return singleton;
    }
    private static BLE singleton = null;

    /** App context */
    Context ctx = null;

    /** We don't want anyone calling the constructor except ourselves. */
    private BLE(Context ctx) {
        this.ctx = ctx;
    }

    /** Bluetooth operation queue */
    ExecutorService executor = Executors.newSingleThreadExecutor();

    /** Bluetooth adapter */
    BluetoothAdapter adapter = null;

    /** GATT server */
    BluetoothGattServer gattServer = null;

    /** List of pending promises */
    HashMap<UUID, SettableFuture> pendingPromises = new HashMap<>();

    /** List of advertised services */
    ArrayList<BluetoothGattService> services = new ArrayList<>();

    /** Advertise listener */
    AdvertiseListener advertiseListener = new AdvertiseListener(this);

    /**
     * Sets up the Bluetooth environment
     */
    private void setup() throws Exception {

        // Stop if already set up
        if (gattServer != null)
            return;

        // Get bluetooth manager
        BluetoothManager manager = (BluetoothManager) ctx.getSystemService(Context.BLUETOOTH_SERVICE);

        // Get bluetooth adapter, check if enabled
        this.adapter = manager.getAdapter();
        if (!this.adapter.isEnabled())
            throw new Exception("Bluetooth is currently disabled.");

        // Check if BLE advertisement is supported
        if (!adapter.isMultipleAdvertisementSupported())
            throw new Exception("This device does not support multiple advertisement.");

        // Get bluetooth GATT server
        this.gattServer = manager.openGattServer(ctx, new GATTListener(this));
        if (gattServer == null)
            throw new Exception("Unable to open GATT server.");

    }

    /**
     * Register a Bluetooth LE service.
     *
     * @param service The service to register
     * @return Success or failure
     */
    public Future createService(BluetoothGattService service, Callback<Boolean> cb) {

        // Do on queue
        return executor.submit(() -> {

            try {

                // Setup bluetooth
                setup();

                // Remove existing service
                for (BluetoothGattService s : services) {
                    if (s.getUuid().equals(service.getUuid())) {
                        gattServer.removeService(s);
                        services.remove(s);
                    }
                }

                // Store listener
                SettableFuture promise = new SettableFuture();
                pendingPromises.put(service.getUuid(), promise);

                // Add service
                this.services.add(service);
                this.gattServer.addService(service);

                // Wait until service has been registered
                promise.get();

                // Readvertise
                this.readvertise();

                // Start service
                ctx.startService(new Intent(ctx, BLEService.class));

                // Done
                cb.run(true, null);

            } catch (Exception ex) {

                // Failed
                cb.run(null, ex);

            }

        });

    }

    /**
     * Remove the specified service.
     *
     * @param uuid
     */
    public Future removeService(UUID uuid, Callback cb) {

        // Do on queue
        return executor.submit(() -> {

            // Remove existing service
            for (BluetoothGattService s : services) {
                if (s.getUuid().equals(uuid)) {
                    gattServer.removeService(s);
                    services.remove(s);
                }
            }

            // Check how many services remain
            if (services.size() > 0) {

                // Readvertise
                readvertise();

            } else {

                // Stop advertising
                BluetoothLeAdvertiser advertiser = adapter.getBluetoothLeAdvertiser();
                advertiser.stopAdvertising(advertiseListener);

                // Stop server
                gattServer.close();
                gattServer = null;

                // Stop service
                ctx.stopService(new Intent(ctx, BLEService.class));

            }

            // Done
            if (cb != null)
                cb.run(true, null);

        });

    }

    /** Update advertised data */
    private void readvertise() {

        // Sanity check
        if (adapter == null)
            return;

        // Create advertise settings
        AdvertiseSettings settings = new AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(true)
                .build();

        // Create advertise data
        AdvertiseData.Builder dataBuilder = new AdvertiseData.Builder().setIncludeTxPowerLevel(true);
        for (BluetoothGattService svc : services)
            dataBuilder = dataBuilder.addServiceUuid(new ParcelUuid(svc.getUuid()));

        // Create advertise scan data
        AdvertiseData scanData = new AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .build();

        // Get advertiser
        BluetoothLeAdvertiser advertiser = adapter.getBluetoothLeAdvertiser();
        advertiser.startAdvertising(settings, dataBuilder.build(), scanData, advertiseListener);

    }

    // Current scan
    private ScanListener currentScan = null;

    /**
     * Start scanning for remote devices nearby.
     *
     * @param serviceFilter An optional list of services. If specified, will only return devices with these services.
     * @param listener Response listener
     */
    public void scan(List<UUID> serviceFilter, ScanListener listener) {

        // Do on queue
        executor.submit(() -> {

            try {

                // Setup bluetooth
                setup();

                // Get discoverer
                BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();

                // Stop existing scan if any
                if (currentScan != null) {
                    currentScan.onScanStopped(new Exception("Another scan was started."));
                    scanner.stopScan(currentScan);
                }

                // Create scan settings
                ScanSettings settings = new ScanSettings.Builder()
                        .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                        .build();

                // Start scanning, check filter
                if (serviceFilter.size() == 0) {

                    // Scan without a filter
                    currentScan = listener;
                    scanner.startScan(null, settings, listener);

                } else {

                    // Create service filter
                    ArrayList<ScanFilter> filters = new ArrayList<>();
                    for (UUID uuid : serviceFilter)
                        filters.add(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(uuid)).build());

                    // Scan with filter
                    currentScan = listener;
                    scanner.startScan(filters, settings, listener);

                }

                // Done
                listener.onStart();

            } catch (Exception ex) {

                // Failed
                listener.onStartFailed(ex);

            }

        });

    }

}