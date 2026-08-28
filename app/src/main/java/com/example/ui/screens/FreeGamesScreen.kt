package com.example.ui.screens

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.NewsRepository
import com.example.model.NewsCategory
import com.example.model.NewsItem
import com.example.ui.components.NewsDetailBottomSheet
import com.example.ui.components.NewsListItem
import com.example.ui.theme.AlertRed
import com.example.ui.theme.BgScaffold
import com.example.ui.theme.CardBg
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextWhite

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FreeGamesScreen(
    modifier: Modifier = Modifier
) {
    val newsList by NewsRepository.newsList.collectAsState()
    val freeGames = newsList.filter { it.isFree || it.category == NewsCategory.FREE || it.category == NewsCategory.DISCOUNT }
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
                            imageVector = Icons.Default.LocalFireDepartment,
                            contentDescription = null,
                            tint = AlertRed,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Aaj FREE Games 🔥",
                            color = TextWhite,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }
                    Text(
                        text = "Epic Games & Steam ke 100% free claims aur discounts",
                        color = TextGray,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )

                    Spacer(modifier = Modifier.height(14.dp))

                    // Live Banner
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(CardBg)
                            .padding(14.dp)
                    ) {
                        Column {
                            Text(
                                text = "⏰ Limited Time Alert",
                                color = NeonGreen,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.ExtraBold
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Ye games mukhtasir waqt ke liye free hain. Ek bar claim karli toh hamesha aapke account me rahengi.",
                                color = TextWhite,
                                fontSize = 12.sp,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
            }

            items(freeGames) { item ->
                NewsListItem(
                    newsItem = item,
                    onClick = { selectedNewsItem = item },
                    onBookmarkToggle = { NewsRepository.toggleBookmark(item.id) }
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
