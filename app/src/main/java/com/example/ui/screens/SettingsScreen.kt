package com.example.ui.screens

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.BgScaffold
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg
import com.example.ui.theme.CardBg2
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.TextGray
import com.example.ui.theme.TextMuted
import com.example.ui.theme.TextWhite

// Platform Brand Colors
private val YouTubeRed = Color(0xFFFF0000)
private val InstagramPink = Color(0xFFE1306C)
private val TikTokCyan = Color(0xFF00F2FE)
private val FacebookBlue = Color(0xFF1877F2)

data class SocialChannel(
    val id: String,
    val name: String,
    val handle: String,
    val description: String,
    val url: String,
    val brandColor: Color,
    val icon: ImageVector,
    val actionText: String
)

@Composable
fun SettingsScreen(
    onNavigateBack: (() -> Unit)? = null
) {
    val context = LocalContext.current

    val socialChannels = listOf(
        SocialChannel(
            id = "youtube",
            name = "YouTube",
            handle = "@YourChannel",
            description = "Tournaments, gameplay clips & guides",
            url = "https://youtube.com/@YourChannel",
            brandColor = YouTubeRed,
            icon = Icons.Filled.PlayArrow,
            actionText = "Subscribe"
        ),
        SocialChannel(
            id = "instagram",
            name = "Instagram",
            handle = "@YourUsername",
            description = "Daily gaming reels, news & stories",
            url = "https://instagram.com/YourUsername",
            brandColor = InstagramPink,
            icon = Icons.Filled.CameraAlt,
            actionText = "Follow"
        ),
        SocialChannel(
            id = "tiktok",
            name = "TikTok",
            handle = "@YourUsername",
            description = "Viral BGMI moments & short gameplay",
            url = "https://tiktok.com/@YourUsername",
            brandColor = TikTokCyan,
            icon = Icons.Filled.MusicNote,
            actionText = "Watch"
        ),
        SocialChannel(
            id = "facebook",
            name = "Facebook",
            handle = "YourPage",
            description = "Community updates, groups & events",
            url = "https://facebook.com/YourPage",
            brandColor = FacebookBlue,
            icon = Icons.Filled.Public,
            actionText = "Connect"
        )
    )

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = BgScaffold
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            contentPadding = PaddingValues(vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Screen Header
            item {
                Column(modifier = Modifier.padding(bottom = 8.dp)) {
                    Text(
                        text = "Settings",
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontWeight = FontWeight.Black,
                            color = TextWhite,
                            letterSpacing = (-0.5).sp
                        )
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Gamers ID Network preferences & community links",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = TextGray
                        )
                    )
                }
            }

            // === FOLLOW US SECTION ===
            item {
                FollowUsSection(
                    channels = socialChannels,
                    onChannelClick = { channel ->
                        openSocialLink(context = context, url = channel.url, title = channel.name)
                    }
                )
            }

            // === GENERAL PREFERENCES SECTION ===
            item {
                Text(
                    text = "App Information",
                    style = MaterialTheme.typography.titleSmall.copy(
                        fontWeight = FontWeight.Bold,
                        color = TextMuted,
                        letterSpacing = 1.sp
                    ),
                    modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
                )
            }

            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = CardBg),
                    border = CardDefaults.outlinedCardBorder().copy(brush = androidx.compose.ui.graphics.SolidColor(BorderColor))
                ) {
                    Column(modifier = Modifier.padding(vertical = 4.dp)) {
                        SettingsRowItem(
                            icon = Icons.Filled.Security,
                            title = "Privacy Policy",
                            subtitle = "AdMob & Firebase data terms",
                            onClick = {
                                openSocialLink(
                                    context = context,
                                    url = "https://example.com/privacy-policy",
                                    title = "Privacy Policy"
                                )
                            }
                        )

                        HorizontalDivider(color = BorderColor, thickness = 1.dp)

                        SettingsRowItem(
                            icon = Icons.Filled.Info,
                            title = "About Gamers ID Network",
                            subtitle = "Version 1.2.0 (Build 4)",
                            onClick = {
                                Toast.makeText(
                                    context,
                                    "Gamers ID Network v1.2.0",
                                    Toast.LENGTH_SHORT
                                ).show()
                            }
                        )
                    }
                }
            }
        }
    }
}

/**
 * "Follow Us" Section Composable
 */
@Composable
fun FollowUsSection(
    channels: List<SocialChannel>,
    onChannelClick: (SocialChannel) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Section Title & Badge
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.Share,
                    contentDescription = null,
                    tint = NeonGreen,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Follow Us",
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontWeight = FontWeight.ExtraBold,
                        color = TextWhite
                    )
                )
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(NeonGreen.copy(alpha = 0.15f))
                    .padding(horizontal = 8.dp, vertical = 3.dp)
            ) {
                Text(
                    text = "OFFICIAL",
                    style = MaterialTheme.typography.labelSmall.copy(
                        color = NeonGreen,
                        fontWeight = FontWeight.Black,
                        fontSize = 10.sp
                    )
                )
            }
        }

        // Subtitle note
        Text(
            text = "Follow our official channels for tournaments, clips, and daily updates.",
            style = MaterialTheme.typography.bodySmall.copy(
                color = TextGray,
                lineHeight = 16.sp
            )
        )

        // Social Cards List
        channels.forEach { channel ->
            SocialChannelCard(
                channel = channel,
                onClick = { onChannelClick(channel) }
            )
        }

        // Informational Note
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(CardBg2)
                .border(1.dp, BorderColor, RoundedCornerShape(12.dp))
                .padding(12.dp)
        ) {
            Text(
                text = "No subscription or payment required. Following is 100% free and optional.",
                style = MaterialTheme.typography.bodySmall.copy(
                    color = TextMuted,
                    fontSize = 11.5.sp
                )
            )
        }
    }
}

/**
 * Individual Social Media Channel Card with Platform Icon and Follow Button
 */
@Composable
fun SocialChannelCard(
    channel: SocialChannel,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .testTag("follow_card_${channel.id}"),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        border = CardDefaults.outlinedCardBorder().copy(brush = androidx.compose.ui.graphics.SolidColor(BorderColor))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Platform Icon + Title + Description
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(channel.brandColor.copy(alpha = 0.15f))
                        .border(1.dp, channel.brandColor.copy(alpha = 0.3f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = channel.icon,
                        contentDescription = "${channel.name} Icon",
                        tint = channel.brandColor,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Spacer(modifier = Modifier.width(14.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = channel.name,
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                color = TextWhite,
                                fontSize = 15.sp
                            )
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = channel.handle,
                            style = MaterialTheme.typography.bodySmall.copy(
                                color = TextMuted,
                                fontSize = 12.sp
                            )
                        )
                    }
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = channel.description,
                        style = MaterialTheme.typography.bodySmall.copy(
                            color = TextGray,
                            fontSize = 11.5.sp
                        ),
                        maxLines = 1
                    )
                }
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Follow / Action Button
            Button(
                onClick = onClick,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = channel.brandColor.copy(alpha = 0.18f),
                    contentColor = channel.brandColor
                ),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                modifier = Modifier
                    .height(36.dp)
                    .testTag("follow_button_${channel.id}")
            ) {
                Text(
                    text = channel.actionText,
                    style = MaterialTheme.typography.labelMedium.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    imageVector = Icons.Filled.OpenInNew,
                    contentDescription = null,
                    modifier = Modifier.size(13.dp),
                    tint = channel.brandColor
                )
            }
        }
    }
}

/**
 * Standard Settings Navigation Row
 */
@Composable
fun SettingsRowItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = NeonGreen,
            modifier = Modifier.size(22.dp)
        )
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontWeight = FontWeight.SemiBold,
                    color = TextWhite,
                    fontSize = 14.sp
                )
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall.copy(
                    color = TextGray,
                    fontSize = 12.sp
                )
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForwardIos,
            contentDescription = null,
            tint = TextMuted,
            modifier = Modifier.size(14.dp)
        )
    }
}

/**
 * Safely opens a social media link or website with fallback.
 * Uses ACTION_VIEW intent with try-catch to ensure graceful degradation.
 */
fun openSocialLink(context: Context, url: String, title: String) {
    try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    } catch (e: Exception) {
        try {
            // Fallback: force browser intent if app handling fails
            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(browserIntent)
        } catch (_: Exception) {
            Toast.makeText(
                context,
                "Unable to open $title link. Please visit: $url",
                Toast.LENGTH_LONG
            ).show()
        }
    }
}
