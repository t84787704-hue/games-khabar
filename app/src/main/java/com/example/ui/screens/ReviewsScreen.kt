package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.NewsRepository
import com.example.model.NewsCategory
import com.example.model.NewsItem
import com.example.ui.components.NewsDetailBottomSheet
import com.example.ui.theme.BgScaffold
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg
import com.example.ui.theme.CardBg2
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.ReviewPurple
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextWhite

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReviewsScreen(
    modifier: Modifier = Modifier
) {
    val newsList by NewsRepository.newsList.collectAsState()
    val reviewItems = newsList.filter { it.category == NewsCategory.REVIEW || it.rating != null }
    var selectedNewsItem by remember { mutableStateOf<NewsItem?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(BgScaffold)
    ) {
        LazyColumn(modifier = Modifier.fillMaxSize()) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = ReviewPurple,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Game Reviews ⭐",
                            color = TextWhite,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                    Text(
                        text = "Sachay reviews aur detailed ratings (10 me se score)",
                        color = TextGray,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            items(reviewItems) { item ->
                ReviewCardItem(
                    newsItem = item,
                    onClick = { selectedNewsItem = item }
                )
            }

            item {
                Spacer(modifier = Modifier.height(90.dp))
            }
        }

        selectedNewsItem?.let { item ->
            NewsDetailBottomSheet(
                newsItem = item,
                sheetState = sheetState,
                onDismiss = { selectedNewsItem = null },
                onBookmarkToggle = { NewsRepository.toggleBookmark(item.id) }
            )
        }
    }
}

@Composable
fun ReviewCardItem(
    newsItem: NewsItem,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, BorderColor, RoundedCornerShape(16.dp))
            .clickable { onClick() }
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(140.dp)
        ) {
            AsyncImage(
                model = newsItem.imageUrl,
                contentDescription = newsItem.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )

            // Rating Circle Badge
            Box(
                modifier = Modifier
                    .padding(12.dp)
                    .align(Alignment.TopEnd)
                    .size(46.dp)
                    .background(Color.Black.copy(alpha = 0.8f), CircleShape)
                    .border(2.dp, NeonGreen, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "${newsItem.rating ?: 9.0}",
                    color = NeonGreen,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Black
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp)
        ) {
            Text(
                text = newsItem.title,
                color = TextWhite,
                fontSize = 15.sp,
                fontWeight = FontWeight.ExtraBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = newsItem.description,
                color = TextGray,
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 18.sp
            )

            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${newsItem.timeAgo} • ${(newsItem.views / 1000.0).toStringAsFixed(1)}k views",
                    color = TextGray,
                    fontSize = 11.sp
                )

                Text(
                    text = "Pura Review Parhein →",
                    color = NeonGreen,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

private fun Double.toStringAsFixed(digits: Int): String = String.format("%.${digits}f", this)
