
# react-native-bluetooth-le

## Getting started

`$ npm install react-native-bluetooth-le --save`

### Mostly automatic installation

`$ react-native link react-native-bluetooth-le`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-bluetooth-le` and add `RNBluetoothLe.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNBluetoothLe.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNBluetoothLePackage;` to the imports at the top of the file
  - Add `new RNBluetoothLePackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-bluetooth-le'
  	project(':react-native-bluetooth-le').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-bluetooth-le/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-bluetooth-le')
  	```

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNBluetoothLe.sln` in `node_modules/react-native-bluetooth-le/windows/RNBluetoothLe.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Bluetooth.Le.RNBluetoothLe;` to the usings at the top of the file
  - Add `new RNBluetoothLePackage()` to the `List<IReactPackage>` returned by the `Packages` method


## Usage
```javascript
import RNBluetoothLe from 'react-native-bluetooth-le';

// TODO: What to do with the module?
RNBluetoothLe;
```
  