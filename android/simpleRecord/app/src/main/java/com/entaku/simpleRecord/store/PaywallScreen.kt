package com.entaku.simpleRecord.store

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.entaku.simpleRecord.R

private fun Context.findActivity(): Activity? {
    var context = this
    while (context is ContextWrapper) {
        if (context is Activity) return context
        context = (context as ContextWrapper).baseContext
    }
    return null
}

private val premiumFeatures = listOf(
    R.string.premium_feature_no_ads,
    R.string.premium_feature_transcription,
    R.string.premium_feature_high_quality,
    R.string.premium_feature_cloud,
)

@Composable
fun PaywallScreen(
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val billingManager = remember { BillingRepository.getInstance(context) }
    val premiumManager = remember { PremiumRepository.getInstance(context) }
    val billingState by billingManager.billingState.collectAsState()
    val isPremium by premiumManager.isPremium.collectAsState()

    DisposableEffect(Unit) {
        billingManager.connect()
        onDispose { billingManager.disconnect() }
    }

    LaunchedEffect(isPremium) {
        if (isPremium) onNavigateBack()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
    ) {
        PaywallTopBar(onNavigateBack = onNavigateBack)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(16.dp))
            PremiumHeroSection()
            Spacer(Modifier.height(32.dp))
            PremiumFeatureList()
            Spacer(Modifier.height(40.dp))
            BillingContent(
                billingState = billingState,
                billingManager = billingManager
            )
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun PaywallTopBar(onNavigateBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onNavigateBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
        }
        Text(
            text = stringResource(R.string.premium_title),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun PremiumHeroSection() {
    Icon(
        Icons.Default.Star,
        contentDescription = null,
        modifier = Modifier.size(64.dp),
        tint = MaterialTheme.colorScheme.primary
    )
    Spacer(Modifier.height(12.dp))
    Text(
        text = stringResource(R.string.premium_headline),
        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
        textAlign = TextAlign.Center
    )
    Spacer(Modifier.height(8.dp))
    Text(
        text = stringResource(R.string.premium_subheadline),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center
    )
}

@Composable
private fun PremiumFeatureList() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        premiumFeatures.forEach { resId ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(Modifier.width(12.dp))
                Text(stringResource(resId), style = MaterialTheme.typography.bodyLarge)
            }
        }
    }
}

@Composable
private fun BillingContent(
    billingState: BillingState,
    billingManager: BillingRepository
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    when (val state = billingState) {
        is BillingState.Loading, is BillingState.Purchasing -> {
            CircularProgressIndicator()
        }
        is BillingState.Error -> {
            Text(
                state.message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = { billingManager.connect() },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.transcription_retry))
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { billingManager.restorePurchases {} },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.premium_restore))
            }
        }
        is BillingState.Ready -> {
            val product = state.products.firstOrNull()
            if (product != null) {
                Button(
                    onClick = {
                        if (activity != null) {
                            billingManager.launchPurchaseFlow(activity, product)
                        } else {
                            android.util.Log.e("BillingContent", "Activity is null — cannot launch purchase flow")
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            stringResource(R.string.premium_free_trial),
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                        )
                        Text(
                            stringResource(R.string.premium_trial_then_price, product.price),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.premium_trial_terms, product.price),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            } else {
                Text(
                    stringResource(R.string.premium_unavailable),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
            Spacer(Modifier.height(16.dp))
            OutlinedButton(
                onClick = { billingManager.restorePurchases {} },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.premium_restore))
            }
        }
    }
}
