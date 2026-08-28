package com.example.ui.components

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.outlined.AccessTime
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.example.model.NewsCategory
import com.example.model.NewsItem
import com.example.ui.theme.AlertRed
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg
import com.example.ui.theme.CardBg2
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.NewsBlue
import com.example.ui.theme.ReviewPurple
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextWhite
import com.example.ui.theme.TrailerOrange

@Composable
fun NewsListItem(
    newsItem: NewsItem,
    onClick: () -> Unit,
    onBookmarkToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val categoryColor = when (newsItem.category) {
        NewsCategory.FREE -> NeonGreen
        NewsCategory.NEWS -> NewsBlue
        NewsCategory.REVIEW -> ReviewPurple
        NewsCategory.TRAILER -> TrailerOrange
        NewsCategory.DISCOUNT -> AlertRed
        NewsCategory.LOW_MB -> NeonGreen
        else -> NewsBlue
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .border(1.dp, BorderColor, RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Left Thumbnail Image
        Box(
            modifier = Modifier
                .size(86.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(CardBg2)
        ) {
            AsyncImage(
                model = newsItem.imageUrl,
                contentDescription = newsItem.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.size(86.dp)
            )

            if (newsItem.downloadSize != null) {
                Box(
                    modifier = Modifier
                        .padding(4.dp)
                        .align(Alignment.BottomStart)
                        .background(Color.Black.copy(alpha = 0.8f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 4.dp, vertical = 1.dp)
                ) {
                    Text(
                        text = newsItem.downloadSize,
                        color = NeonGreen,
                        fontSize = 8.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Right Content
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Category Tag
                Box(
                    modifier = Modifier
                        .background(categoryColor.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                        .border(1.dp, categoryColor.copy(alpha = 0.4f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = newsItem.category.badgeName,
                        color = categoryColor,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Black
                    )
                }

                IconButton(
                    onClick = onBookmarkToggle,
                    modifier = Modifier.size(24.dp)
                ) {
                    Icon(
                        imageVector = if (newsItem.isBookmarked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                        contentDescription = "Bookmark",
                        tint = if (newsItem.isBookmarked) NeonGreen else TextGray,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = newsItem.title,
                color = TextWhite,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 18.sp
            )

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Outlined.AccessTime,
                    contentDescription = null,
                    tint = TextGray,
                    modifier = Modifier.size(11.dp)
                )
                Spacer(modifier = Modifier.width(3.dp))
                Text(
                    text = newsItem.timeAgo,
                    color = TextGray,
                    fontSize = 10.sp
                )

                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "•", color = TextGray, fontSize = 10.sp)
                Spacer(modifier = Modifier.width(8.dp))

                Icon(
                    imageVector = Icons.Outlined.Visibility,
                    contentDescription = null,
                    tint = TextGray,
                    modifier = Modifier.size(11.dp)
                )
                Spacer(modifier = Modifier.width(3.dp))
                Text(
                    text = "${String.format("%.1f", newsItem.views / 1000.0)}k",
                    color = TextGray,
                    fontSize = 10.sp
                )

                if (newsItem.rating != null) {
                    Spacer(modifier = Modifier.weight(1f))
                    Box(
                        modifier = Modifier
                            .background(ReviewPurple, RoundedCornerShape(6.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "${newsItem.rating}/10",
                            color = Color.White,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Black
                        )
                    }
                }
            }
        }
    }
}
