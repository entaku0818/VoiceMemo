package com.entaku.simpleRecord.store

import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaywallScreenTest {

    private fun product(planType: PlanType, id: String = planType.name, price: String = "¥300") =
        PremiumProduct(id, id, price, planType, mockk())

    // --- resolvePaywallPlansUiState ---

    @Test
    fun `no products resolves to Unavailable`() {
        val result = resolvePaywallPlansUiState(emptyList(), isAnnualSelected = false)
        assertEquals(PaywallPlansUiState.Unavailable, result)
    }

    @Test
    fun `annual package unavailable falls back to single monthly plan UI`() {
        val monthly = product(PlanType.MONTHLY, price = "¥300")
        val result = resolvePaywallPlansUiState(listOf(monthly), isAnnualSelected = true)

        val single = result as? PaywallPlansUiState.SinglePlan
            ?: error("expected SinglePlan, got $result")
        assertEquals(monthly, single.product)
    }

    @Test
    fun `monthly and annual both available resolves to DualPlan`() {
        val monthly = product(PlanType.MONTHLY)
        val annual = product(PlanType.ANNUAL)
        val result = resolvePaywallPlansUiState(listOf(monthly, annual), isAnnualSelected = true)

        val dual = result as? PaywallPlansUiState.DualPlan
            ?: error("expected DualPlan, got $result")
        assertEquals(monthly, dual.monthly)
        assertEquals(annual, dual.annual)
        assertTrue(dual.isAnnualSelected)
    }

    @Test
    fun `DualPlan selectedProduct follows isAnnualSelected flag`() {
        val monthly = product(PlanType.MONTHLY)
        val annual = product(PlanType.ANNUAL)

        val annualSelected = resolvePaywallPlansUiState(listOf(monthly, annual), isAnnualSelected = true)
            as PaywallPlansUiState.DualPlan
        assertEquals(annual, annualSelected.selectedProduct)

        val monthlySelected = resolvePaywallPlansUiState(listOf(monthly, annual), isAnnualSelected = false)
            as PaywallPlansUiState.DualPlan
        assertEquals(monthly, monthlySelected.selectedProduct)
    }

    @Test
    fun `no MONTHLY-typed product falls back to first product as monthly slot`() {
        // offeringにMONTHLY種別が無い場合、既存挙動を保つため先頭商品を月額枠として扱う
        val other = product(PlanType.OTHER, id = "other")
        val result = resolvePaywallPlansUiState(listOf(other), isAnnualSelected = false)

        val single = result as? PaywallPlansUiState.SinglePlan
            ?: error("expected SinglePlan, got $result")
        assertEquals(other, single.product)
    }

    // --- defaultIsAnnualSelected ---

    @Test
    fun `defaultIsAnnualSelected is true when annual package exists`() {
        assertTrue(defaultIsAnnualSelected(listOf(product(PlanType.MONTHLY), product(PlanType.ANNUAL))))
    }

    @Test
    fun `defaultIsAnnualSelected is false when annual package is absent`() {
        assertFalse(defaultIsAnnualSelected(listOf(product(PlanType.MONTHLY))))
    }

    @Test
    fun `defaultIsAnnualSelected is false for empty product list`() {
        assertFalse(defaultIsAnnualSelected(emptyList()))
    }
}
