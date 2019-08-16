
module.exports = runner => {
    
    // Add iOS permission requirement
    runner.register().before('prepare.ios.permissions').do(ctx => {
        ctx.ios.permissions.add('NSBluetoothPeripheralUsageDescription')
    })

}