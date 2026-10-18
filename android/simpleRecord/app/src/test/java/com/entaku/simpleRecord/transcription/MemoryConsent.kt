package com.entaku.simpleRecord.transcription

class MemoryConsent : AIConsentStore {
    private val permissions = mutableSetOf<AIPurpose>()
    override fun allowed(purpose: AIPurpose) = purpose in permissions
    override fun allow(purpose: AIPurpose) { permissions.add(purpose) }
    override fun reset() { permissions.clear() }
}
