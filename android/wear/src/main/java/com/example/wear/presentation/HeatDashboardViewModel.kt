package com.example.wear.presentation

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.wear.data.HeatStatus
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class HeatDashboardViewModel(context: Context) : ViewModel(), DataClient.OnDataChangedListener {
    private val dataClient: DataClient = Wearable.getDataClient(context)
    private val nodeClient = Wearable.getNodeClient(context)

    private val _heatStatus = MutableStateFlow(HeatStatus())
    val heatStatus: StateFlow<HeatStatus> = _heatStatus

    init {
        checkConnections()
        setupDataLayerListener()
        syncDataFromPhone()
    }

    private fun checkConnections() {
        viewModelScope.launch {
            try {
                val nodes = nodeClient.connectedNodes.await()
                Log.d("HeatDashboard", "Connected nodes: ${nodes.size}")
                if (nodes.isEmpty()) {
                    Log.w("HeatDashboard", "NO NODES CONNECTED! Check emulator pairing.")
                }
                nodes.forEach { Log.d("HeatDashboard", "Connected to Node: ${it.displayName} (${it.id})") }
            } catch (e: Exception) {
                Log.e("HeatDashboard", "Failed to check nodes", e)
            }
        }
    }

    private fun setupDataLayerListener() {
        // Register without filters to catch everything during debugging
        dataClient.addListener(this)
        Log.d("HeatDashboard", "Data listener registered (all paths)")
    }

    override fun onDataChanged(dataEventBuffer: DataEventBuffer) {
        Log.d("HeatDashboard", "onDataChanged: Received ${dataEventBuffer.count} events")
        for (event in dataEventBuffer) {
            val uri = event.dataItem.uri
            Log.d("HeatDashboard", "Event: type=${event.type}, path=${uri.path}, host=${uri.host}")
            
            if (event.type == DataEvent.TYPE_CHANGED && uri.path == "/heat_status") {
                parseHeatStatusFromDataItem(event.dataItem)
            }
        }
        dataEventBuffer.release()
    }

    private fun syncDataFromPhone() {
        viewModelScope.launch {
            try {
                val dataItems = dataClient.dataItems.await()
                Log.d("HeatDashboard", "Initial sync: found ${dataItems.count} total items in storage")
                
                for (item in dataItems) {
                    if (item.uri.path == "/heat_status") {
                        Log.d("HeatDashboard", "Found existing /heat_status item")
                        parseHeatStatusFromDataItem(item)
                    }
                }
                dataItems.release()
            } catch (e: Exception) {
                Log.e("HeatDashboard", "Error during initial sync", e)
            }
        }
    }

    private fun parseHeatStatusFromDataItem(dataItem: com.google.android.gms.wearable.DataItem) {
        try {
            val dataMap = com.google.android.gms.wearable.DataMapItem.fromDataItem(dataItem).dataMap
            val status = HeatStatus(
                currentTemp = dataMap.getInt("temp", 0),
                exposureSeconds = dataMap.getInt("exposure", 0),
                riskRatio = dataMap.getDouble("risk", 0.0),
                isInShadedArea = dataMap.getBoolean("shaded", false),
                lastUpdated = dataMap.getLong("timestamp", System.currentTimeMillis())
            )
            _heatStatus.value = status
            Log.i("HeatDashboard", "UI STATE UPDATED: $status")
        } catch (e: Exception) {
            Log.e("HeatDashboard", "Error parsing data", e)
        }
    }

    override fun onCleared() {
        super.onCleared()
        dataClient.removeListener(this)
    }
}
