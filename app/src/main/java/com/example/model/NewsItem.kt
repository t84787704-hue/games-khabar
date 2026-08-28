package com.example.model

import java.util.UUID

enum class NewsCategory(val displayName: String, val badgeName: String) {
    ALL("All", "ALL"),
    NEWS("Taza Khabar", "NEWS"),
    FREE("Free Games", "FREE"),
    REVIEW("Reviews", "REVIEW"),
    TRAILER("Trailers", "TRAILER"),
    DISCOUNT("Discounts", "DISCOUNT"),
    LOW_MB("Low MB Games", "LOW MB")
}

data class NewsItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val description: String,
    val category: NewsCategory,
    val imageUrl: String,
    val youtubeId: String? = null,
    val timeAgo: String,
    val views: Int = 0,
    val rating: Double? = null,
    val originalPrice: String? = null,
    val isFree: Boolean = false,
    val timeLeft: String? = null,
    val storeName: String? = null,
    val isBookmarked: Boolean = false,
    val downloadSize: String? = null
)
