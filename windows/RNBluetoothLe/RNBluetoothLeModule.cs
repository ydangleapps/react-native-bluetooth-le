using ReactNative.Bridge;
using System;
using System.Collections.Generic;
using Windows.ApplicationModel.Core;
using Windows.UI.Core;

namespace Bluetooth.Le.RNBluetoothLe
{
    /// <summary>
    /// A module that allows JS to share data.
    /// </summary>
    class RNBluetoothLeModule : NativeModuleBase
    {
        /// <summary>
        /// Instantiates the <see cref="RNBluetoothLeModule"/>.
        /// </summary>
        internal RNBluetoothLeModule()
        {

        }

        /// <summary>
        /// The name of the native module.
        /// </summary>
        public override string Name
        {
            get
            {
                return "RNBluetoothLe";
            }
        }
    }
}
