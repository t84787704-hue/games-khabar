package com.example.ui.components

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedIconButton
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.model.NewsCategory
import com.example.model.NewsItem
import com.example.ui.theme.AlertRed
import com.example.ui.theme.BgOuter
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg
import com.example.ui.theme.CardBg2
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.NewsBlue
import com.example.ui.theme.ReviewPurple
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextWhite
import com.example.ui.theme.TrailerOrange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewsDetailBottomSheet(
    newsItem: NewsItem,
    sheetState: SheetState,
    onDismiss: () -> Unit,
    onBookmarkToggle: () -> Unit
) {
    val context = LocalContext.current
    val categoryColor = when (newsItem.category) {
        NewsCategory.FREE -> NeonGreen
        NewsCategory.NEWS -> NewsBlue
        NewsCategory.REVIEW -> ReviewPurple
        NewsCategory.TRAILER -> TrailerOrange
        NewsCategory.DISCOUNT -> AlertRed
        NewsCategory.LOW_MB -> NeonGreen
        else -> NewsBlue
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Color(0xFF0F141E),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 10.dp)
                    .width(44.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(BorderColor)
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Header Row: Category Badge and Close
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .background(categoryColor.copy(alpha = 0.2f), RoundedCornerShape(6.dp))
                        .border(1.dp, categoryColor, RoundedCornerShape(6.dp))
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = newsItem.category.badgeName,
                        color = categoryColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Black
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(32.dp)
                        .background(CardBg2, CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Band Karein",
                        tint = TextWhite,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Article Title in Roman Urdu
            Text(
                text = newsItem.title,
                color = TextWhite,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
                lineHeight = 28.sp
            )

            Spacer(modifier = Modifier.height(10.dp))

            // Author & Metadata
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Outlined.Person,
                    contentDescription = null,
                    tint = NeonGreen,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = "Games Khabar Team",
                    color = NeonGreen,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(text = "•", color = TextGray, fontSize = 12.sp)
                Text(
                    text = newsItem.timeAgo,
                    color = TextGray,
                    fontSize = 12.sp
                )
                Text(text = "•", color = TextGray, fontSize = 12.sp)
                Icon(
                    imageVector = Icons.Outlined.Visibility,
                    contentDescription = null,
                    tint = TextGray,
                    modifier = Modifier.size(13.dp)
                )
                Text(
                    text = "${newsItem.views} views",
                    color = TextGray,
                    fontSize = 12.sp
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Large Hero Image
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(210.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(CardBg2)
            ) {
                AsyncImage(
                    model = newsItem.imageUrl,
                    contentDescription = newsItem.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().height(210.dp)
                )

                if (newsItem.rating != null) {
                    Box(
                        modifier = Modifier
                            .padding(12.dp)
                            .align(Alignment.TopEnd)
                            .background(ReviewPurple, RoundedCornerShape(10.dp))
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = "RATING: ${newsItem.rating}/10",
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Black
                        )
                    }
                }
            }

            // YouTube Video Preview Box if trailer exists
            if (newsItem.youtubeId != null) {
                Spacer(modifier = Modifier.height(16.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(150.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(CardBg)
                        .border(1.dp, BorderColor, RoundedCornerShape(14.dp))
                        .clickable {
                            val webIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://www.youtube.com/watch?v=${newsItem.youtubeId}"))
                            try {
                                context.startActivity(webIntent)
                            } catch (_: Exception) {}
                        }
                ) {
                    AsyncImage(
                        model = "https://img.youtube.com/vi/${newsItem.youtubeId}/hqdefault.jpg",
                        contentDescription = "Trailer Video",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxWidth().height(150.dp)
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(150.dp)
                            .background(Color.Black.copy(alpha = 0.5f))
                    )
                    Box(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .size(48.dp)
                            .background(AlertRed, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.PlayArrow,
                            contentDescription = "Play Video",
                            tint = Color.White,
                            modifier = Modifier.size(28.dp)
                        )
                    }
                    Text(
                        text = "Official Trailer Play Karein",
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 8.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(18.dp))

            // Roman Urdu Full Description
            Text(
                text = newsItem.description,
                color = Color(0xFFD1D5DB),
                fontSize = 14.5.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Normal
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Action Buttons: Share + Bookmark
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 30.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Button(
                    onClick = {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(
                                Intent.EXTRA_TEXT,
                                "${newsItem.title}\n\nGames Khabar app se parhein: https://gameskhabar.page.link/app"
                            )
                            type = "text/plain"
                        }
                        val shareIntent = Intent.createChooser(sendIntent, "Khabar share karein")
                        context.startActivity(shareIntent)
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = NeonGreen,
                        contentColor = BgOuter
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = null,
                        tint = BgOuter,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Doston ko bhejo",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 14.sp
                    )
                }

                OutlinedIconButton(
                    onClick = onBookmarkToggle,
                    modifier = Modifier
                        .size(48.dp)
                        .background(CardBg2, RoundedCornerShape(12.dp)),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        imageVector = if (newsItem.isBookmarked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                        contentDescription = "Save",
                        tint = if (newsItem.isBookmarked) NeonGreen else TextWhite
                    )
                }
            }
        }
    }
}
