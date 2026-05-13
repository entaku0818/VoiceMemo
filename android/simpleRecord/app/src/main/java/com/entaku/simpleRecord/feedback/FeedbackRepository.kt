package com.entaku.simpleRecord.feedback

import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

interface FeedbackRepository {
    suspend fun submit(data: Map<String, Any>)
}

class FirebaseFeedbackRepository : FeedbackRepository {
    private val functions = FirebaseFunctions.getInstance("asia-northeast1")

    override suspend fun submit(data: Map<String, Any>) {
        functions.getHttpsCallable("submitFeedback").call(data).await()
    }
}
