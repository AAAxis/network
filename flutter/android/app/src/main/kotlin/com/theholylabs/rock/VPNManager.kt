package com.theholylabs.rock

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

class VPNManager(private val context: Context, private val binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
    
    private val TAG = "VPNManager"
    private val channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())
    
    init {
        channel = MethodChannel(binaryMessenger, "com.theholylabs.network/vpn_status")
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private val isConnected = AtomicBoolean(false)
    private val connectionStartTime = AtomicLong(0)
    private var pendingConnectionResult: MethodChannel.Result? = null
    private var pendingConnectionParams: ConnectionParams? = null
    
    private data class ConnectionParams(
        val serverAddress: String,
        val username: String,
        val password: String,
        val sharedSecret: String,
        val countryCode: String?,
        val countryName: String?
    )
    
    private fun clearPendingConnection() {
        pendingConnectionParams = null
        pendingConnectionResult = null
    }
    
    fun connect(
        serverAddress: String,
        username: String,
        password: String,
        sharedSecret: String,
        countryCode: String?,
        countryName: String?,
        result: MethodChannel.Result
    ) {
        Log.d(TAG, "Requesting VPN connection to $serverAddress ($countryName)")
        
        // Store connection parameters and result for after permission is granted
        pendingConnectionParams = ConnectionParams(serverAddress, username, password, sharedSecret, countryCode, countryName)
        pendingConnectionResult = result
        
        // Request VPN permission
        val activity = context as MainActivity
        activity.requestVpnPermission()
    }
    
    fun onVpnPermissionResult(granted: Boolean) {
        Log.d(TAG, "VPN permission result: $granted")
        
        if (!granted) {
            Log.e(TAG, "VPN permission denied by user")
            pendingConnectionResult?.error("PERMISSION_DENIED", "VPN permission denied by user", null)
            clearPendingConnection()
            return
        }
        
        val params = pendingConnectionParams
        val result = pendingConnectionResult
        
        if (params == null || result == null) {
            Log.e(TAG, "No pending connection parameters or result is null")
            clearPendingConnection()
            return
        }
        
        // Clear pending data
        clearPendingConnection()
        
        // Start VPN connection in background thread
        Thread {
            try {
                Log.d(TAG, "Starting VPN service for ${params.serverAddress}")
                
                // Start the VPN service with IPSec credentials
                val serviceIntent = Intent(context, RockVpnService::class.java).apply {
                    action = RockVpnService.ACTION_CONNECT
                    putExtra(RockVpnService.EXTRA_SERVER_ADDRESS, params.serverAddress)
                    putExtra(RockVpnService.EXTRA_COUNTRY_NAME, params.countryName ?: "Unknown")
                    putExtra(RockVpnService.EXTRA_COUNTRY_CODE, params.countryCode ?: "Unknown")
                    putExtra(RockVpnService.EXTRA_USERNAME, params.username)
                    putExtra(RockVpnService.EXTRA_PASSWORD, params.password)
                    putExtra(RockVpnService.EXTRA_SHARED_SECRET, params.sharedSecret)
                }
                
                context.startService(serviceIntent)
                
                // Wait a moment for service to establish connection
                Thread.sleep(2000)
                
                // Check if VPN service is connected
                val service = RockVpnService.instance
                if (service != null && service.isConnected()) {
                    isConnected.set(true)
                    connectionStartTime.set(System.currentTimeMillis())
                    
                    // Notify Flutter about connection status (must run on main thread)
                    mainHandler.post {
                        channel.invokeMethod("onVPNStatusChanged", mapOf(
                            "status" to "connected",
                            "isConnected" to true,
                            "countryName" to (params.countryName ?: "Unknown"),
                            "countryCode" to (params.countryCode ?: "Unknown"),
                            "serverAddress" to params.serverAddress
                        ))
                    }
                    
                    Log.d(TAG, "VPN connection successful")
                    result.success(true)
                } else {
                    throw Exception("VPN service failed to establish connection")
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN connection failed", e)
                isConnected.set(false)
                connectionStartTime.set(0)
                
                mainHandler.post {
                    channel.invokeMethod("onVPNStatusChanged", mapOf(
                        "status" to "failed",
                        "isConnected" to false,
                        "error" to e.message
                    ))
                }
                
                result.error("CONNECTION_FAILED", e.message, null)
            }
        }.start()
    }
    
    fun disconnect(result: MethodChannel.Result) {
        Log.d(TAG, "Disconnecting VPN")
        
        Thread {
            try {
                // Stop the VPN service
                val serviceIntent = Intent(context, RockVpnService::class.java).apply {
                    action = RockVpnService.ACTION_DISCONNECT
                }
                context.startService(serviceIntent)
                
                // Wait a moment for service to disconnect
                Thread.sleep(1000)
                
                isConnected.set(false)
                connectionStartTime.set(0)
                
                // Notify Flutter about disconnection (must run on main thread)
                mainHandler.post {
                    channel.invokeMethod("onVPNStatusChanged", mapOf(
                        "status" to "disconnected",
                        "isConnected" to false
                    ))
                }
                
                Log.d(TAG, "VPN disconnected successfully")
                result.success(true)
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN disconnection failed", e)
                result.error("DISCONNECTION_FAILED", e.message, null)
            }
        }.start()
    }
    
    val isConnectedValue: Boolean
        get() = isConnected.get()
    
    fun getConnectionDuration(): Long {
        val startTime = connectionStartTime.get()
        if (startTime == 0L) return 0
        return (System.currentTimeMillis() - startTime) / 1000 // Return duration in seconds
    }
    
    fun testServerConnectivity(serverAddress: String, port: Int, result: MethodChannel.Result) {
        Thread {
            try {
                val socket = Socket()
                socket.connect(InetSocketAddress(serverAddress, port), 5000) // 5 second timeout
                socket.close()
                
                Log.d(TAG, "Server $serverAddress:$port is reachable")
                result.success(true)
                
            } catch (e: Exception) {
                Log.e(TAG, "Server $serverAddress:$port is not reachable", e)
                result.success(false)
            }
        }.start()
    }
}

