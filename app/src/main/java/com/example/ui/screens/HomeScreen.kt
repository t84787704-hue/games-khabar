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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
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
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.NewsRepository
import com.example.model.NewsCategory
import com.example.model.NewsItem
import com.example.ui.components.FreeGameCard
import com.example.ui.components.HeroFeaturedCard
import com.example.ui.components.NewsDetailBottomSheet
import com.example.ui.components.NewsListItem
import com.example.ui.theme.AlertRed
import com.example.ui.theme.BgOuter
import com.example.ui.theme.BgScaffold
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg2
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextWhite

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateToCategory: (NewsCategory) -> Unit,
    modifier: Modifier = Modifier
) {
    val newsList by NewsRepository.newsList.collectAsState()
    var selectedCategory by remember { mutableStateOf(NewsCategory.ALL) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedNewsItem by remember { mutableStateOf<NewsItem?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val focusManager = LocalFocusManager.current

    // Filter logic
    val filteredNews = newsList.filter { item ->
        val matchesCategory = when (selectedCategory) {
            NewsCategory.ALL -> true
            else -> item.category == selectedCategory
        }
        val matchesSearch = if (searchQuery.isBlank()) {
            true
        } else {
            item.title.contains(searchQuery, ignoreCase = true) ||
                    item.description.contains(searchQuery, ignoreCase = true)
        }
        matchesCategory && matchesSearch
    }

    val freeAndDiscountGames = newsList.filter { it.isFree || it.category == NewsCategory.FREE || it.category == NewsCategory.DISCOUNT }
    val heroItem = newsList.firstOrNull { it.id == "hero_1" } ?: newsList.firstOrNull()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(BgScaffold)
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize()
        ) {
            // 1. Top Custom App Bar
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(NeonGreen),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "GK",
                                color = BgOuter,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Black
                            )
                        }

                        Spacer(modifier = Modifier.width(10.dp))

                        Column {
                            Text(
                                text = "GAMES KHABAR",
                                color = TextWhite,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.ExtraBold,
                                letterSpacing = 0.5.sp
                            )
                            Text(
                                text = "FREE GAMES • NEWS",
                                color = TextGray,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 1.sp
                            )
                        }
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box {
                            IconButton(onClick = { /* Notification action */ }) {
                                Icon(
                                    imageVector = Icons.Filled.NotificationsNone,
                                    contentDescription = "Notifications",
                                    tint = TextWhite
                                )
                            }
                            Box(
                                modifier = Modifier
                                    .padding(top = 10.dp, end = 10.dp)
                                    .size(8.dp)
                                    .align(Alignment.TopEnd)
                                    .background(AlertRed, CircleShape)
                            )
                        }
                    }
                }
            }

            // 2. Search Bar in Roman Urdu
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(CardBg2)
                        .border(1.dp, BorderColor, RoundedCornerShape(24.dp))
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 14.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "Search",
                            tint = TextGray,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        TextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            placeholder = {
                                Text(
                                    text = "Koi game search karo... PUBG, GTA",
                                    color = TextGray,
                                    fontSize = 13.sp
                                )
                            },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent,
                                focusedTextColor = TextWhite,
                                unfocusedTextColor = TextWhite
                            ),
                            modifier = Modifier.weight(1f)
                        )
                        if (searchQuery.isNotEmpty()) {
                            IconButton(
                                onClick = { searchQuery = "" },
                                modifier = Modifier.size(24.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Clear",
                                    tint = TextGray,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }

            // 3. Category Horizontal Pills
            item {
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp)
                ) {
                    items(NewsCategory.values()) { category ->
                        val isSelected = selectedCategory == category
                        FilterChip(
                            selected = isSelected,
                            onClick = { selectedCategory = category },
                            label = {
                                Text(
                                    text = category.displayName,
                                    fontSize = 12.sp,
                                    fontWeight = if (isSelected) FontWeight.ExtraBold else FontWeight.Medium
                                )
                            },
                            shape = RoundedCornerShape(20.dp),
                            colors = FilterChipDefaults.filterChipColors(
                                containerColor = CardBg2,
                                labelColor = TextGray,
                                selectedContainerColor = NeonGreen,
                                selectedLabelColor = BgOuter
                            ),
                            border = FilterChipDefaults.filterChipBorder(
                                enabled = true,
                                selected = isSelected,
                                borderColor = BorderColor,
                                selectedBorderColor = NeonGreen
                            )
                        )
                    }
                }
            }

            // 4. Hero Featured Card (Only when search is empty and All category selected)
            if (searchQuery.isEmpty() && selectedCategory == NewsCategory.ALL && heroItem != null) {
                item {
                    Spacer(modifier = Modifier.height(6.dp))
                    HeroFeaturedCard(
                        newsItem = heroItem,
                        onClick = {
                            NewsRepository.incrementView(heroItem.id)
                            selectedNewsItem = heroItem
                        }
                    )
                }
            }

            // 5. Aaj FREE Hai 🔥 Section
            if (searchQuery.isEmpty() && (selectedCategory == NewsCategory.ALL || selectedCategory == NewsCategory.FREE)) {
                item {
                    Spacer(modifier = Modifier.height(18.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "Aaj FREE Hai 🔥",
                                color = TextWhite,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.ExtraBold
                            )
                        }

                        TextButton(onClick = { selectedCategory = NewsCategory.FREE }) {
                            Text(
                                text = "Sab Dekho",
                                color = NeonGreen,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    LazyRow(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp)
                    ) {
                        items(freeAndDiscountGames) { game ->
                            FreeGameCard(
                                game = game,
                                onClick = {
                                    NewsRepository.incrementView(game.id)
                                    selectedNewsItem = game
                                }
                            )
                        }
                    }
                }
            }

            // 6. Section Header 2: Taza Khabrain
            item {
                Spacer(modifier = Modifier.height(20.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(NeonGreen, CircleShape)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = if (selectedCategory == NewsCategory.ALL) "Taza Khabrain" else selectedCategory.displayName,
                        color = TextWhite,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "• ${filteredNews.size} posts",
                        color = TextGray,
                        fontSize = 13.sp
                    )
                }
            }

            // 7. News Vertical List
            if (filteredNews.isEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(40.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = Icons.Default.SearchOff,
                            contentDescription = null,
                            tint = TextGray,
                            modifier = Modifier.size(48.dp)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Koi khabar nahi mili - Admin ne abhi koi khabar publish nahi ki",
                            color = TextWhite,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Dusri game search karein ya filter change karein",
                            color = TextGray,
                            fontSize = 13.sp
                        )
                    }
                }
            } else {
                items(filteredNews) { item ->
                    NewsListItem(
                        newsItem = item,
                        onClick = {
                            NewsRepository.incrementView(item.id)
                            selectedNewsItem = item
                        },
                        onBookmarkToggle = { NewsRepository.toggleBookmark(item.id) }
                    )
                }
            }

            item {
                Spacer(modifier = Modifier.height(90.dp))
            }
        }

        // Bottom Sheet for Article Details
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
