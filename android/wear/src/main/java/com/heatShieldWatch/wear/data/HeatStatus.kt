package com.heatShieldWatch.wear.data

data class HeatStatus(
    val currentTemp: Int = 0, // in Celsius
    val exposureSeconds: Int = 0,
    val riskRatio: Double = 0.0, // 0.0 to 1.0
    val isInShadedArea: Boolean = false,
    val lastUpdated: Long = System.currentTimeMillis()
) {
    fun getRiskLevelText(): String = when {
        riskRatio < 0.33 -> "LOW"
        riskRatio < 0.66 -> "MODERATE"
        else -> "CRITICAL"
    }

    fun getFormattedExposure(): String = when {
        exposureSeconds == 0 -> "0 min"
        exposureSeconds < 60 -> "${exposureSeconds}s"
        else -> {
            val minutes = exposureSeconds / 60
            val seconds = exposureSeconds % 60
            if (seconds > 0) "${minutes}m ${seconds}s" else "${minutes}m"
        }
    }
}
