package com.example.wear.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.Warning
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.ui.tooling.preview.WearPreviewDevices
import androidx.wear.compose.ui.tooling.preview.WearPreviewFontScales
import com.example.wear.data.HeatStatus
import com.example.wear.presentation.theme.AndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { AndroidTheme { HeatDashboardScreen() } }
    }
}

@Composable
fun HeatDashboardScreen(
        viewModel: HeatDashboardViewModel =
                viewModel(factory = HeatDashboardViewModelFactory(context = LocalContext.current))
) {
    val heatStatus = viewModel.heatStatus.collectAsState()

    AppScaffold {
        ScreenScaffold(scrollState = rememberScalingLazyListState()) { padding ->
            ScalingLazyColumn(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    state = rememberScalingLazyListState(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                item { HeatStatusHeader(heatStatus.value) }
                item { TemperatureCard(heatStatus.value) }
                item { ExposureCard(heatStatus.value) }
                item { RiskMeterCard(heatStatus.value) }
            }
        }
    }
}

@Composable
fun HeatStatusHeader(status: HeatStatus) {
    Box(
            modifier =
                    Modifier.fillMaxWidth()
                            .background(
                                    color =
                                            if (status.isInShadedArea) Color(0xFF1B5E20)
                                            else Color(0xFFB71C1C),
                                    shape = RoundedCornerShape(8.dp)
                            )
                            .padding(12.dp),
            contentAlignment = Alignment.Center
    ) {
        Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                    imageVector =
                            if (status.isInShadedArea) Icons.Default.CheckCircle
                            else Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                    text = if (status.isInShadedArea) "SHADED" else "EXPOSED",
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun TemperatureCard(status: HeatStatus) {
    Card(title = "Temperature", value = "${status.currentTemp}°C", icon = Icons.Default.Thermostat)
}

@Composable
fun ExposureCard(status: HeatStatus) {
    Card(
            title = "Sun Exposure",
            value = status.getFormattedExposure(),
            icon = Icons.Default.CheckCircle
    )
}

@Composable
fun RiskMeterCard(status: HeatStatus) {
    val riskLevel = status.getRiskLevelText()
    val riskColor =
            when {
                status.riskRatio < 0.33 -> Color(0xFF4CAF50) // Green
                status.riskRatio < 0.66 -> Color(0xFFFFA726) // Amber
                else -> Color(0xFFD32F2F) // Red
            }

    Box(
            modifier =
                    Modifier.fillMaxWidth()
                            .background(Color(0xFF212121), shape = RoundedCornerShape(8.dp))
                            .padding(12.dp)
    ) {
        Column {
            Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                        text = "Risk Level",
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.W500
                )
                Text(
                        text = riskLevel,
                        color = riskColor,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                )
            }
            Spacer(modifier = Modifier.height(6.dp))
            // Simple horizontal bar for risk
            Box(
                    modifier =
                            Modifier.fillMaxWidth()
                                    .height(8.dp)
                                    .background(Color(0xFF424242), shape = RoundedCornerShape(4.dp))
            ) {
                Box(
                        modifier =
                                Modifier.fillMaxWidth(status.riskRatio.toFloat().coerceIn(0f, 1f))
                                        .height(8.dp)
                                        .background(riskColor, shape = RoundedCornerShape(4.dp))
                )
            }
        }
    }
}

@Composable
fun Card(title: String, value: String, icon: ImageVector? = null) {
    Box(
            modifier =
                    Modifier.fillMaxWidth()
                            .background(Color(0xFF212121), shape = RoundedCornerShape(8.dp))
                            .padding(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            if (icon != null) {
                Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = Color(0xFF81C784),
                        modifier = Modifier.size(20.dp).padding(end = 8.dp)
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                        text = title,
                        color = Color(0xFFB0BEC5),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.W500
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                        text = value,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@WearPreviewDevices
@WearPreviewFontScales
@Composable
fun DefaultPreview() {
    AndroidTheme {
        HeatDashboardScreen(
                viewModel = viewModel(factory = HeatDashboardViewModelFactory(LocalContext.current))
        )
    }
}
