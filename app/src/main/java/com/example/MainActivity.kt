package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.ui.MainApp
import com.example.ui.theme.GamesKhabarTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Play Store requirement: Full edge-to-edge system bars
        enableEdgeToEdge()
        setContent {
            GamesKhabarTheme {
                MainApp()
            }
        }
    }
}

