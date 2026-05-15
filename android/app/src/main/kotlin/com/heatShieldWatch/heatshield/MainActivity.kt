package com.heatShieldWatch.heatshield

import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.heatshield/watch_companion"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isWatchReachable" -> isWatchReachable(result)
                        "sendMessageToWatch" -> {
                            val path = call.argument<String>("path")
                            val payload = call.argument<String>("payload") ?: ""

                            if (path.isNullOrBlank()) {
                                result.error("INVALID_ARGUMENT", "'path' is required.", null)
                            } else {
                                sendMessageToWatch(path, payload, result)
                            }
                        }
                        "sendHeatStatusToWatch" -> {
                            val temp = call.argument<Int>("temp") ?: 0
                            val exposure = call.argument<Int>("exposure") ?: 0
                            val risk = call.argument<Double>("risk") ?: 0.0
                            val shaded = call.argument<Boolean>("shaded") ?: false
                            sendHeatStatusToWatch(temp, exposure, risk, shaded, result)
                        }
                        else -> result.notImplemented()
                    }
                }
    }

    private fun isWatchReachable(result: MethodChannel.Result) {
        Thread {
                    try {
                        val nodes = Tasks.await(Wearable.getNodeClient(this).connectedNodes)
                        runOnUiThread { result.success(nodes.isNotEmpty()) }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("WATCH_CHECK_FAILED", e.message ?: "Unknown error", null)
                        }
                    }
                }
                .start()
    }

    private fun sendMessageToWatch(path: String, payload: String, result: MethodChannel.Result) {
        Thread {
                    try {
                        val nodeClient = Wearable.getNodeClient(this)
                        val messageClient = Wearable.getMessageClient(this)
                        val nodes = Tasks.await(nodeClient.connectedNodes)

                        if (nodes.isEmpty()) {
                            runOnUiThread { result.success(false) }
                            return@Thread
                        }

                        var sentToAtLeastOneNode = false
                        val payloadBytes = payload.toByteArray(Charsets.UTF_8)

                        for (node in nodes) {
                            Tasks.await(messageClient.sendMessage(node.id, path, payloadBytes))
                            sentToAtLeastOneNode = true
                        }

                        runOnUiThread { result.success(sentToAtLeastOneNode) }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("WATCH_SEND_FAILED", e.message ?: "Unknown error", null)
                        }
                    }
                }
                .start()
    }

    private fun sendHeatStatusToWatch(
            temp: Int,
            exposure: Int,
            risk: Double,
            shaded: Boolean,
            result: MethodChannel.Result
    ) {
        Thread {
                    try {
                        val dataClient = Wearable.getDataClient(this@MainActivity)
                        val putDataMapRequest =
                                com.google.android.gms.wearable.PutDataMapRequest.create(
                                        "/heat_status"
                                )
                        putDataMapRequest.dataMap.apply {
                            putInt("temp", temp)
                            putInt("exposure", exposure)
                            putDouble("risk", risk)
                            putBoolean("shaded", shaded)
                            putLong("timestamp", System.currentTimeMillis())
                        }
                        val request = putDataMapRequest.asPutDataRequest().setUrgent()

                        Tasks.await(dataClient.putDataItem(request))
                        runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error(
                                    "HEAT_STATUS_SEND_FAILED",
                                    e.message ?: "Unknown error",
                                    null
                            )
                        }
                    }
                }
                .start()
    }
}
