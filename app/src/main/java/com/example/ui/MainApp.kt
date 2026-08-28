package com.example.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.AdminPanelSettings
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.LocalFireDepartment
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.screens.AdminScreen
import com.example.ui.screens.BookmarksScreen
import com.example.ui.screens.FreeGamesScreen
import com.example.ui.screens.HomeScreen
import com.example.ui.screens.ReviewsScreen
import com.example.ui.theme.BgOuter
import com.example.ui.theme.BgScaffold
import com.example.ui.theme.BorderColor
import com.example.ui.theme.CardBg
import com.example.ui.theme.NeonGreen
import com.example.ui.theme.TextGray

data class NavigationTab(
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
)

@Composable
fun MainApp() {
    var selectedTabIndex by rememberSaveable { mutableIntStateOf(0) }

    val tabs = listOf(
        NavigationTab("Home", Icons.Filled.Home, Icons.Outlined.Home),
        NavigationTab("Free", Icons.Filled.LocalFireDepartment, Icons.Outlined.LocalFireDepartment),
        NavigationTab("Reviews", Icons.Filled.Star, Icons.Outlined.StarOutline),
        NavigationTab("Saved", Icons.Filled.Bookmark, Icons.Outlined.BookmarkBorder),
        NavigationTab("Admin", Icons.Filled.AdminPanelSettings, Icons.Outlined.AdminPanelSettings)
    )

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = BgScaffold,
        contentWindowInsets = WindowInsets.navigationBars,
        bottomBar = {
            NavigationBar(
                containerColor = Color(0xFF0F141E),
                tonalElevation = 8.dp,
                modifier = Modifier.border(1.dp, BorderColor)
            ) {
                tabs.forEachIndexed { index, tab ->
                    val isSelected = selectedTabIndex == index
                    NavigationBarItem(
                        selected = isSelected,
                        onClick = { selectedTabIndex = index },
                        icon = {
                            Icon(
                                imageVector = if (isSelected) tab.selectedIcon else tab.unselectedIcon,
                                contentDescription = tab.title,
                                modifier = Modifier.size(22.dp)
                            )
                        },
                        label = {
                            Text(
                                text = tab.title,
                                fontSize = 10.sp,
                                fontWeight = if (isSelected) FontWeight.ExtraBold else FontWeight.Medium
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = BgOuter,
                            selectedTextColor = NeonGreen,
                            unselectedIconColor = TextGray,
                            unselectedTextColor = TextGray,
                            indicatorColor = NeonGreen
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (selectedTabIndex) {
                0 -> HomeScreen(onNavigateToCategory = { selectedTabIndex = 1 })
                1 -> FreeGamesScreen()
                2 -> ReviewsScreen()
                3 -> BookmarksScreen()
                4 -> AdminScreen()
            }
        }
    }
}
