package com.example.ui.screens

import android.content.Intent
import android.net.Uri
import android.widget.Toast
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.NewsRepository
import com.example.model.NewsCategory
import com.example.model.NewsItem
import com.example.ui.theme.BgOuter
import com.example.ui.theme.BgScaffold
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg
import com.example.ui.theme.CardBg2
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextWhite

@Composable
fun AdminScreen(
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var category by remember { mutableStateOf(NewsCategory.NEWS) }
    var imageUrl by remember { mutableStateOf("https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1000&q=80") }
    var youtubeId by remember { mutableStateOf("") }
    var originalPrice by remember { mutableStateOf("") }
    var rating by remember { mutableStateOf("") }
    var timeLeft by remember { mutableStateOf("") }
    var isFree by remember { mutableStateOf(false) }
    var downloadSize by remember { mutableStateOf("") }
    var isDropdownExpanded by remember { mutableStateOf(false) }
    var isPublishedSuccess by remember { mutableStateOf(false) }

    val selectableCategories = listOf(
        NewsCategory.NEWS,
        NewsCategory.FREE,
        NewsCategory.REVIEW,
        NewsCategory.TRAILER,
        NewsCategory.DISCOUNT,
        NewsCategory.LOW_MB
    )

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(BgScaffold)
            .padding(16.dp)
    ) {
        item {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(vertical = 10.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.AdminPanelSettings,
                    contentDescription = null,
                    tint = NeonGreen,
                    modifier = Modifier.size(26.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Column {
                    Text(
                        text = "Admin Publishing Panel",
                        color = TextWhite,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Text(
                        text = "Roman Urdu me post karein - App me foran show hoga",
                        color = TextGray,
                        fontSize = 11.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))
        }

        if (isPublishedSuccess) {
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(NeonGreen.copy(alpha = 0.15f))
                        .border(1.dp, NeonGreen, RoundedCornerShape(12.dp))
                        .padding(14.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = NeonGreen,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "Khabar kamyabi se publish ho gayi aur Live list me add ho chuki hai!",
                        color = TextWhite,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                Spacer(modifier = Modifier.height(14.dp))
            }
        }

        item {
            // Category Dropdown
            Text(
                text = "Category Select Karein",
                color = TextGray,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(CardBg2)
                    .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
                    .clickable { isDropdownExpanded = true }
                    .padding(horizontal = 14.dp, vertical = 14.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "${category.displayName} (${category.badgeName})",
                        color = TextWhite,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Icon(
                        imageVector = Icons.Default.ArrowDropDown,
                        contentDescription = null,
                        tint = TextWhite
                    )
                }

                DropdownMenu(
                    expanded = isDropdownExpanded,
                    onDismissRequest = { isDropdownExpanded = false },
                    modifier = Modifier.background(CardBg)
                ) {
                    selectableCategories.forEach { cat ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    text = "${cat.displayName} (${cat.badgeName})",
                                    color = if (cat == category) NeonGreen else TextWhite
                                )
                            },
                            onClick = {
                                category = cat
                                if (cat == NewsCategory.FREE) isFree = true
                                isDropdownExpanded = false
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(14.dp))
        }

        item {
            AdminTextField(
                value = title,
                onValueChange = { title = it },
                label = "Title (Roman Urdu)",
                placeholder = "e.g. Free Fire MAX 2026 Update me Naya Character Aya"
            )
            Spacer(modifier = Modifier.height(12.dp))
        }

        item {
            AdminTextField(
                value = imageUrl,
                onValueChange = { imageUrl = it },
                label = "Image URL (HTTPS)",
                placeholder = "https://images.unsplash.com/..."
            )
            Spacer(modifier = Modifier.height(12.dp))
        }

        item {
            AdminTextField(
                value = youtubeId,
                onValueChange = { youtubeId = it },
                label = "YouTube Trailer Video ID (Optional)",
                placeholder = "e.g. dQw4w9WgXcQ"
            )
            Spacer(modifier = Modifier.height(12.dp))
        }

        item {
            AdminTextField(
                value = description,
                onValueChange = { description = it },
                label = "Description (Roman Urdu)",
                placeholder = "Gaming news ki puri detail yahan likhein (2-3 paragraphs)...",
                maxLines = 5,
                singleLine = false
            )
            Spacer(modifier = Modifier.height(12.dp))
        }

        // Additional optional fields depending on category
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (category == NewsCategory.REVIEW) {
                    Box(modifier = Modifier.weight(1f)) {
                        AdminTextField(
                            value = rating,
                            onValueChange = { rating = it },
                            label = "Rating (out of 10)",
                            placeholder = "e.g. 9.2"
                        )
                    }
                }
                if (category == NewsCategory.FREE || category == NewsCategory.DISCOUNT) {
                    Box(modifier = Modifier.weight(1f)) {
                        AdminTextField(
                            value = originalPrice,
                            onValueChange = { originalPrice = it },
                            label = "Original Price",
                            placeholder = "e.g. $59.99"
                        )
                    }
                    Box(modifier = Modifier.weight(1f)) {
                        AdminTextField(
                            value = timeLeft,
                            onValueChange = { timeLeft = it },
                            label = "Time Left Countdown",
                            placeholder = "e.g. 18:42:11 baki"
                        )
                    }
                }
                if (category == NewsCategory.LOW_MB) {
                    Box(modifier = Modifier.weight(1f)) {
                        AdminTextField(
                            value = downloadSize,
                            onValueChange = { downloadSize = it },
                            label = "Download MB Size",
                            placeholder = "e.g. 45 MB"
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }

        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(CardBg2)
                    .padding(horizontal = 14.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Kya ye game 100% Free hai?",
                    color = TextWhite,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
                Switch(
                    checked = isFree,
                    onCheckedChange = { isFree = it },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = BgOuter,
                        checkedTrackColor = NeonGreen
                    )
                )
            }
            Spacer(modifier = Modifier.height(20.dp))
        }

        item {
            Button(
                onClick = {
                    if (title.isBlank() || description.isBlank()) {
                        Toast.makeText(context, "Title aur Description likhna zaroori hai!", Toast.LENGTH_SHORT).show()
                        return@Button
                    }

                    val newItem = NewsItem(
                        title = title.trim(),
                        description = description.trim(),
                        category = category,
                        imageUrl = if (imageUrl.isNotBlank()) imageUrl.trim() else "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80",
                        youtubeId = if (youtubeId.isNotBlank()) youtubeId.trim() else null,
                        timeAgo = "Abhi abhi",
                        views = 1,
                        rating = rating.toDoubleOrNull(),
                        originalPrice = if (originalPrice.isNotBlank()) originalPrice.trim() else null,
                        isFree = isFree,
                        timeLeft = if (timeLeft.isNotBlank()) timeLeft.trim() else null,
                        downloadSize = if (downloadSize.isNotBlank()) downloadSize.trim() else null
                    )

                    NewsRepository.addNews(newItem)
                    isPublishedSuccess = true
                    title = ""
                    description = ""
                    youtubeId = ""
                    originalPrice = ""
                    rating = ""
                    timeLeft = ""
                    downloadSize = ""

                    Toast.makeText(context, "Khabar Publish Ho Gayi! 🔥", Toast.LENGTH_LONG).show()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = NeonGreen,
                    contentColor = BgOuter
                )
            ) {
                Icon(
                    imageVector = Icons.Default.Send,
                    contentDescription = null,
                    tint = BgOuter,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Publish Khabar (Live)",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Black
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }

        // Play Store 2025/2026 Privacy & Compliance Section
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(CardBg)
                    .border(1.dp, BorderColor, RoundedCornerShape(14.dp))
                    .padding(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.PrivacyTip,
                        contentDescription = null,
                        tint = NeonGreen,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Play Store Data Safety & Privacy",
                        color = TextWhite,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "Games Khabar app complies with Play Store 2025/2026 requirements:\n• Personal data collected: NONE\n• Target SDK: 34+ (Android 14/15 ready)\n• 16KB Page Size compatible\n• Permissions: Only android.permission.INTERNET",
                    color = TextGray,
                    fontSize = 11.5.sp,
                    lineHeight = 17.sp
                )

                Spacer(modifier = Modifier.height(10.dp))

                Text(
                    text = "Privacy Policy Link: https://gameskhabar.page.link/privacy",
                    color = NeonGreen,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.clickable {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://gameskhabar.page.link/privacy"))
                        try {
                            context.startActivity(browserIntent)
                        } catch (_: Exception) {}
                    }
                )
            }

            Spacer(modifier = Modifier.height(90.dp))
        }
    }
}

@Composable
fun AdminTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String,
    maxLines: Int = 1,
    singleLine: Boolean = true
) {
    Column {
        Text(
            text = label,
            color = TextGray,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(6.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = {
                Text(
                    text = placeholder,
                    color = Color(0xFF6B7280),
                    fontSize = 13.sp
                )
            },
            maxLines = maxLines,
            singleLine = singleLine,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = CardBg2,
                unfocusedContainerColor = CardBg2,
                focusedBorderColor = NeonGreen,
                unfocusedBorderColor = BorderColor,
                focusedTextColor = TextWhite,
                unfocusedTextColor = TextWhite
            )
        )
    }
}
