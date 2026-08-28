package com.example.data

import com.example.model.NewsCategory
import com.example.model.NewsItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

object NewsRepository {
    private val initialNews = listOf(
        NewsItem(
            id = "hero_1",
            title = "PUBG Mobile 3.5 Update me Naya Snow Map - Frost Festival Bohat OP Hai",
            description = """PUBG Mobile ka naya 3.5 update officially roll out ho chuka hai! Is bar Tencent ne naya winter theme introduce kiya hai jisme Snow Village aur Ice Dragon powers shamil hain.

Players ab snowmobile chala sakte hain aur dragon summon karke enemies par direct frost attack kar sakte hain. Tecno aur Infinix low-end phones ke liye bhi 60fps support optimize kiya gaya hai taake frame drop aur lag na ho.

Missions complete karne par free glacier theme skins aur M416 upgrade materials mil rahe hain. Apne squad ke sath abhi game update karein aur chicken dinner hasil karein!""".trimIndent(),
            category = NewsCategory.NEWS,
            imageUrl = "https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80",
            youtubeId = "dQw4w9WgXcQ",
            timeAgo = "5 ghante pehle",
            views = 8420,
            isBookmarked = false
        ),
        NewsItem(
            id = "free_1",
            title = "Death Stranding Epic Games Store par 100% FREE ho gayi! Jaldi claim karo",
            description = """Hideo Kojima ki iconic blockbuster game 'Death Stranding' is waqt Epic Games Store par bilkul free download ke liye available hai.

Pehle is game ki regular price $59.99 (lagbhag 17,000 PKR) thi, magar ab aglay 24 ghante ke liye ye bilkul 0 PKR me mil rahi hai.

Ek bar Epic account me add karli toh hamesha ke liye aapki library me save ho jayegi. PC gamers bilkul miss na karein!""".trimIndent(),
            category = NewsCategory.FREE,
            imageUrl = "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1000&q=80",
            timeAgo = "3 ghante pehle",
            views = 14200,
            originalPrice = "$59.99",
            isFree = true,
            timeLeft = "18:42:11 baki",
            storeName = "Epic Games Store"
        ),
        NewsItem(
            id = "free_2",
            title = "GTA Vice City Definitive Edition Steam par 80% Discount me mil rahi hai",
            description = """Nostalgia wapis aa gaya! Rockstar Games ne GTA Trilogy Definitive Edition par zabardast weekend sale announce ki hai.

Tommy Vercetti ke iconic missions ab modern controls, high resolution textures aur improved lighting ke sath play karein. Low-end budget PC par bhi ye version smoothly run karta hai.""".trimIndent(),
            category = NewsCategory.DISCOUNT,
            imageUrl = "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1000&q=80",
            timeAgo = "7 ghante pehle",
            views = 6300,
            originalPrice = "$39.99",
            isFree = false,
            timeLeft = "02 din baki",
            storeName = "Steam"
        ),
        NewsItem(
            id = "review_1",
            title = "Black Myth Wukong Review: Kya ye game sach me saal ki sabse best action game hai?",
            description = """Black Myth Wukong ne action RPG genre me naye standards set kar diye hain. Unreal Engine 5 par banaye gaye visuals aur Chinese mythology ke boss fights hairan kar dene wale hain.

Combat mechanics fast-paced hain, Monkey King ki martial arts moves aur magical transformations extremely satisfying feel hoti hain.

Pros:
• Outstanding graphics aur detailed boss designs
• Fluid combat combos aur dodge timing

Cons:
• Heavy hardware requirement (High-end PC ya PS5 zaroori)

Score: 9.4 / 10 - Har hardcore action gaming fan ke liye must-play!""".trimIndent(),
            category = NewsCategory.REVIEW,
            imageUrl = "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1000&q=80",
            timeAgo = "1 din pehle",
            views = 19500,
            rating = 9.4
        ),
        NewsItem(
            id = "trailer_1",
            title = "GTA 6 Official Trailer 2 ki release date leak ho gayi - Vice City wapis!",
            description = """Rockstar Games ke verified source ne confirm kiya hai ke GTA 6 ka second official trailer aglay hafte YouTube aur Rockstar Newswire par live hoga.

Is naye trailer me protagonists Jason aur Lucia ki partnership, Leonida state ke dynamic nightlife clubs, aur upgraded car customization physics dikhayi jayegi.""".trimIndent(),
            category = NewsCategory.TRAILER,
            imageUrl = "https://images.unsplash.com/photo-1612287233207-6f81c964177d?auto=format&fit=crop&w=1000&q=80",
            youtubeId = "QdBZY2fkU-0",
            timeAgo = "2 din pehle",
            views = 32000
        ),
        NewsItem(
            id = "lowmb_1",
            title = "Top 5 Games Under 50MB jo bina internet Infinix aur Tecno phones pe chalti hain",
            description = """Agar aapke phone me storage kam hai ya internet package khatam ho gaya hai, toh ye 5 offline low MB games aapke liye perfect hain:

1. Shadow Skate (18MB) - Smooth action platformer
2. Mini Militia Classic (45MB) - Local WiFi multiplayer shootout
3. Dr. Driving (12MB) - Precision driving challenge
4. Vector Lite (48MB) - Parkour runner
5. Traffic Rider Mini (42MB) - Fast bike racing

Ye tamam games 2GB RAM wale phones par bhi bina kisi lag ke 60 FPS par run karti hain.""".trimIndent(),
            category = NewsCategory.LOW_MB,
            imageUrl = "https://images.unsplash.com/photo-1551103782-8ab07afd45c1?auto=format&fit=crop&w=1000&q=80",
            timeAgo = "4 din pehle",
            views = 11400,
            downloadSize = "32 MB"
        ),
        NewsItem(
            id = "free_3",
            title = "Tomb Raider Trilogy Epic Games Store par weekend special me FREE",
            description = """Lara Croft ke teeno blockbuster games (Tomb Raider, Rise of the Tomb Raider, Shadow of the Tomb Raider) limited time ke liye free download ho rahi hain.

Survival adventures, puzzle solving aur action combat ka ultimate pack ek sath bilkul muft claim karein.""".trimIndent(),
            category = NewsCategory.FREE,
            imageUrl = "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1000&q=80",
            timeAgo = "6 ghante pehle",
            views = 9800,
            originalPrice = "$49.99",
            isFree = true,
            timeLeft = "14:10:05 baki",
            storeName = "Epic Games Store"
        ),
        NewsItem(
            id = "review_2",
            title = "Free Fire MAX 2026 Update Review: Kya PUBG se behtar ban gaya?",
            description = """Garena ne Free Fire MAX me naye realistic lighting shaders aur gun sound effects add kiye hain.

Is update ke bad entry-level Android devices par matchmaking fast ho gayi hai aur ping stability improve hui hai.

Score: 8.8 / 10 - Fast-paced casual battle royale ke liye best option.""".trimIndent(),
            category = NewsCategory.REVIEW,
            imageUrl = "https://images.unsplash.com/photo-1560253023-3ec5d502959f?auto=format&fit=crop&w=1000&q=80",
            timeAgo = "2 din pehle",
            views = 15300,
            rating = 8.8
        )
    )

    private val _newsList = MutableStateFlow<List<NewsItem>>(initialNews)
    val newsList: StateFlow<List<NewsItem>> = _newsList.asStateFlow()

    fun incrementView(id: String) {
        _newsList.update { list ->
            list.map { item ->
                if (item.id == id) item.copy(views = item.views + 1) else item
            }
        }
    }

    fun toggleBookmark(id: String) {
        _newsList.update { list ->
            list.map { item ->
                if (item.id == id) item.copy(isBookmarked = !item.isBookmarked) else item
            }
        }
    }

    fun addNews(item: NewsItem) {
        _newsList.update { current ->
            listOf(item) + current
        }
    }

    fun deleteNews(id: String) {
        _newsList.update { current ->
            current.filterNot { it.id == id }
        }
    }
}
