
module.exports = runner => {

    // Add iOS minimum deployment version
    runner.register().before('prepare.ios.link').do(async ctx => {
        ctx.ios.requireDeploymentTarget('10.0')
    })
    
    // Add iOS permission requirement
    runner.register().before('prepare.ios.permissions').do(ctx => {
        ctx.ios.permissions.add('NSBluetoothPeripheralUsageDescription')
    })

}