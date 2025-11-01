package com.theholylabs.rock

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

class MainActivity : FlutterFragmentActivity() {
    
    private val VPN_CHANNEL = "com.theholylabs.network/vpn"
    private var vpnManager: VPNManager? = null
    private val VPN_REQUEST_CODE = 1001  // Use a unique code to avoid conflicts
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup VPN method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleVPNMethodCall(call, result)
            }
        
        // Initialize VPN manager after channel setup
        vpnManager = VPNManager(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_REQUEST_CODE) {
            // Handle our VPN permission result first, before calling super
            vpnManager?.onVpnPermissionResult(resultCode == Activity.RESULT_OK)
            return
        }
        // Let other plugins handle their results
        super.onActivityResult(requestCode, resultCode, data)
    }
    
    fun requestVpnPermission() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            // Permission already granted
            vpnManager?.onVpnPermissionResult(true)
        }
    }
    
    private fun handleVPNMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                result.success(true)
            }
            "connect" -> {
                val args = call.arguments as? Map<*, *>
                if (args != null) {
                    val serverAddress = args["serverAddress"] as? String
                    val username = args["username"] as? String
                    val password = args["password"] as? String
                    val sharedSecret = args["sharedSecret"] as? String
                    val countryCode = args["countryCode"] as? String
                    val countryName = args["countryName"] as? String
                    
                    if (serverAddress != null && username != null && password != null && sharedSecret != null) {
                        vpnManager?.connect(serverAddress, username, password, sharedSecret, countryCode, countryName, result)
                    } else {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Arguments must be a map", null)
                }
            }
            "disconnect" -> {
                vpnManager?.disconnect(result)
            }
            "isConnected" -> {
                result.success(vpnManager?.isConnectedValue ?: false)
            }
            "getConnectionDuration" -> {
                result.success(vpnManager?.getConnectionDuration() ?: 0)
            }
            "testServerConnectivity" -> {
                val args = call.arguments as? Map<*, *>
                if (args != null) {
                    val serverAddress = args["serverAddress"] as? String
                    val port = (args["port"] as? Number)?.toInt() ?: 500
                    if (serverAddress != null) {
                        vpnManager?.testServerConnectivity(serverAddress, port, result)
                    } else {
                        result.error("INVALID_ARGS", "Missing serverAddress", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Arguments must be a map", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
}

