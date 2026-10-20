import os, json, re

# Load all 7 translation files
langs = ['en', 'ur', 'ro', 'hi', 'ar', 'zh', 'bn']
trans_data = {}
for l in langs:
    with open(f'assets/translations/{l}.json', 'r', encoding='utf-8') as f:
        trans_data[l] = json.load(f)

# Define new translation keys across all 7 languages for the top 10 files
new_keys = {
    # Common actions & dialogs
    'confirm_winner_trophy': {
        'en': 'Confirm Winner 🏆',
        'ur': 'فاتح کی تصدیق کریں 🏆',
        'ro': 'Winner Confirm Karein 🏆',
        'hi': 'विजेتا की पुष्टि करें 🏆',
        'ar': 'تأكيد الفائز 🏆',
        'zh': '确认获胜者 🏆',
        'bn': 'বিজয়ী নিশ্চিত করুন 🏆'
    },
    'verify_match_winner': {
        'en': 'Verify Match Winner',
        'ur': 'میچ کے فاتح کی تصدیق کریں',
        'ro': 'Match Winner Verify Karein',
        'hi': 'मैच विजेता सत्यापित करें',
        'ar': 'التحقق من الفائز بالمباراة',
        'zh': '验证比赛获胜者',
        'bn': 'ম্যাচ বিজয়ী যাচাই করুন'
    },
    'match_draw_label': {
        'en': 'Draw (Match Tied)',
        'ur': 'برابر (میچ ٹائی)',
        'ro': 'Draw (Match Barabar)',
        'hi': 'ड्रा (मैच बराबरी)',
        'ar': 'تعادل (مباراة متعادلة)',
        'zh': '平局（比赛打平）',
        'bn': 'ড্র (ম্যাচ টাই)'
    },
    'msg_match_verified_leaderboard': {
        'en': 'Match verified & winner recorded to leaderboard!',
        'ur': 'میچ کی تصدیق ہو گئی اور فاتح لیڈر بورڈ پر درج ہو گیا!',
        'ro': 'Match verify ho gaya aur winner leaderboard par record ho gaya!',
        'hi': 'मैच सत्यापित और विजेता लीडरबोर्ड पर दर्ज!',
        'ar': 'تم التحقق من المباراة وتسجيل الفائز في قائمة المتصدرين!',
        'zh': '比赛已验证，获胜者已记录在排行榜上！',
        'bn': 'ম্যাচ যাচাই করা হয়েছে এবং বিজয়ী লিডারবোর্ডে রেকর্ড করা হয়েছে!'
    },
    'reject_match_proof': {
        'en': 'Reject Match / Proof',
        'ur': 'میچ / ثبوت مسترد کریں',
        'ro': 'Match / Proof Reject Karein',
        'hi': 'मैच / प्रमाण अस्वीकार करें',
        'ar': 'رفض المباراة / الإثبات',
        'zh': '拒绝比赛/证明',
        'bn': 'ম্যাচ / প্রমাণ প্রত্যাখ্যান করুন'
    },
    'request_new_proof': {
        'en': 'Request New Proof',
        'ur': 'نیا ثبوت طلب کریں',
        'ro': 'Naya Proof Request Karein',
        'hi': 'नया प्रमाण मांगें',
        'ar': 'طلب إثبات جديد',
        'zh': '请求新证明',
        'bn': 'নতুন প্রমাণ অনুরোধ করুন'
    },
    'msg_match_proof_rejected': {
        'en': 'Match proof rejected and team notified!',
        'ur': 'میچ کا ثبوت مسترد کر دیا گیا اور ٹیم کو اطلاع بھیج دی گئی!',
        'ro': 'Match proof reject ho gaya aur team ko notify kar diya!',
        'hi': 'मैच प्रमाण अस्वीकार कर दिया गया और टीम को सूचित किया गया!',
        'ar': 'تم رفض إثبات المباراة وإخطار الفريق!',
        'zh': '比赛证明被拒绝并已通知队伍！',
        'bn': 'ম্যাচের প্রমাণ প্রত্যাখ্যান করা হয়েছে এবং দলকে জানানো হয়েছে!'
    },
    'msg_new_proof_requested': {
        'en': 'Request sent to team to upload new proof!',
        'ur': 'ٹیم کو نیا ثبوت اپلوڈ کرنے کی درخواست بھیج دی گئی!',
        'ro': 'Team ko naya proof upload karne ki request bhej di gayi!',
        'hi': 'टीम को नया प्रमाण अपलोड करने का अनुरोध भेजा गया!',
        'ar': 'تم إرسال طلب للفريق لتحميل إثبات جديد!',
        'zh': '已向队伍发送上传新证明的请求！',
        'bn': 'নতুন প্রমাণ আপলোড করতে দলের কাছে অনুরোধ পাঠানো হয়েছে!'
    },
    'resolve_dispute': {
        'en': 'Resolve Dispute',
        'ur': 'تنازعہ حل کریں',
        'ro': 'Dispute Hal Karein',
        'hi': 'विवाद सुलझाएं',
        'ar': 'حل النزاع',
        'zh': '解决争议',
        'bn': 'বিরোধ নিষ্পত্তি করুন'
    },
    'msg_dispute_resolved': {
        'en': 'Dispute report marked as resolved!',
        'ur': 'تنازعہ حل ہو گیا!',
        'ro': 'Dispute resolve ho gaya!',
        'hi': 'विवाद सुलझा लिया गया!',
        'ar': 'تم تحديد تقرير النزاع كتم حله!',
        'zh': '争议报告已标记为已解决！',
        'bn': 'বিরোধ রিপোর্ট সমাধান হিসাবে চিহ্নিত!'
    },
    'room_and_chat': {
        'en': 'Room & Chat',
        'ur': 'روم اور چیٹ',
        'ro': 'Room Aur Chat',
        'hi': 'कमरा और चैट',
        'ar': 'الغرفة والدردشة',
        'zh': '房间与聊天',
        'bn': 'রুম এবং চ্যাট'
    },
    'verify_winner': {
        'en': 'Verify Winner',
        'ur': 'فاتح کی تصدیق کریں',
        'ro': 'Winner Verify Karein',
        'hi': 'विजेता सत्यापित करें',
        'ar': 'التحقق من الفائز',
        'zh': '验证获胜者',
        'bn': 'বিজয়ী যাচাই করুন'
    },
    # Squad Finder & Squad Cards
    'please_login_to_squad': {
        'en': 'Please log in to use squad features!',
        'ur': 'اسکواڈ فیچرز استعمال کرنے کے لیے براہ کرم لاگ ان کریں!',
        'ro': 'Squad features use karne ke liye login karein!',
        'hi': 'स्क्वाड सुविधाओं का उपयोग करने के लिए कृपया लॉगिन करें!',
        'ar': 'يرجى تسجيل الدخول لاستخدام ميزات الفريق!',
        'zh': '请登录以使用队伍功能！',
        'bn': 'স্কোয়াড বৈশিষ্ট্য ব্যবহার করতে লগ ইন করুন!'
    },
    'active_squad_already_exists': {
        'en': 'You already have an active squad request!',
        'ur': 'آپ کا فعال اسکواڈ پہلے سے موجود ہے!',
        'ro': 'Aapka active squad pehle se hai!',
        'hi': 'आपके पास पहले से ही एक सक्रिय दस्ता है!',
        'ar': 'لديك بالفعل طلب فريق نشط!',
        'zh': '您已有一个活跃的队伍请求！',
        'bn': 'আপনার ইতিমধ্যে একটি সক্রিয় স্কোয়াড রয়েছে!'
    },
    'squad_created_success': {
        'en': 'Squad created successfully!',
        'ur': 'اسکواڈ کامیابی سے بن گیا!',
        'ro': 'Squad kamyabi se create ho gaya!',
        'hi': 'दस्ता सफलतापूर्वक बनाया गया!',
        'ar': 'تم إنشاء الفريق بنجاح!',
        'zh': '队伍创建成功！',
        'bn': 'স্কোয়াড সফলভাবে তৈরি করা হয়েছে!'
    },
    'game_mode_label': {
        'en': 'GAME MODE',
        'ur': 'گیم موڈ',
        'ro': 'GAME MODE',
        'hi': 'गेम मोड',
        'ar': 'وضع اللعبة',
        'zh': '游戏模式',
        'bn': 'গেম মোড'
    },
    'min_tier_required': {
        'en': 'MIN TIER REQUIRED',
        'ur': 'کم از کم درکار ٹائر',
        'ro': 'MIN TIER REQUIRED',
        'hi': 'न्यूनतम टियर आवश्यक',
        'ar': 'الحد الأدنى من المستوى المطلوب',
        'zh': '所需的最低段位',
        'bn': 'ন্যূনতম স্তর প্রয়োজন'
    },
    'mic_mandatory': {
        'en': 'Mic Mandatory',
        'ur': 'مائیک لازمی ہے',
        'ro': 'Mic Zaroori Hai',
        'hi': 'माइक अनिवार्य',
        'ar': 'الميكروفون إلزامي',
        'zh': '必须开麦',
        'bn': 'মাইক বাধ্যতামূলক'
    },
    'communication_label': {
        'en': 'COMMUNICATION',
        'ur': 'بات چیت / مائیک',
        'ro': 'COMMUNICATION',
        'hi': 'संचार',
        'ar': 'التواصل',
        'zh': '交流方式',
        'bn': 'যোগাযোগ'
    },
    'in_game_char_uid': {
        'en': 'IN-GAME CHARACTER UID',
        'ur': 'ان گیم کریکٹر UID',
        'ro': 'IN-GAME CHARACTER UID',
        'hi': 'इन-गेम कैरेक्टर UID',
        'ar': 'معرف الشخصية داخل اللعبة',
        'zh': '游戏内角色UID',
        'bn': 'ইন-গেম ক্যারেক্টার UID'
    },
    'squad_msg_role_needed': {
        'en': 'SQUAD MESSAGE / ROLE NEEDED',
        'ur': 'اسکواڈ کا پیغام / درکار کردار',
        'ro': 'SQUAD MESSAGE / ROLE NEEDED',
        'hi': 'दस्ता संदेश / आवश्यक भूमिका',
        'ar': 'رسالة الفريق / الدور المطلوب',
        'zh': '队伍消息/所需角色',
        'bn': 'স্কোয়াড বার্তা / প্রয়োজনীয় ভূমিকা'
    },
    'post_requirement_now': {
        'en': 'Post Requirement Now',
        'ur': 'ضرورت ابھی پوسٹ کریں',
        'ro': 'Requirement Abhi Post Karein',
        'hi': 'अभी आवश्यकता पोस्ट करें',
        'ar': 'انشر المتطلبات الآن',
        'zh': '立即发布需求',
        'bn': 'এখনই প্রয়োজনীয়তা পোস্ট করুন'
    },
    'btn_reset': {
        'en': 'RESET',
        'ur': 'دوبارہ ترتیب دیں',
        'ro': 'RESET',
        'hi': 'रीसेट',
        'ar': 'إعادة ضبط',
        'zh': '重置',
        'bn': 'রিসেট'
    },
    'squad_lfg_posted': {
        'en': 'Squad LFG posted! Visible immediately.',
        'ur': 'اسکواڈ ریکویسٹ پوسٹ ہو گئی! فوری نظر آئے گی۔',
        'ro': 'Squad LFG post ho gayi! Foran visible hogi.',
        'hi': 'दस्ता LFG पोस्ट किया गया! तुरंत दिखाई देगा।',
        'ar': 'تم نشر طلب الفريق! مرئي فوراً.',
        'zh': '组队请求已发布！立即可见。',
        'bn': 'স্কোয়াড LFG পোস্ট করা হয়েছে! অবিলম্বে দৃশ্যমান।'
    },
    # Squad Chat & Actions
    'leave_squad_q': {
        'en': 'Leave Squad?',
        'ur': 'اسکواڈ چھوڑیں؟',
        'ro': 'Squad Chhorein?',
        'hi': 'दस्ता छोड़ें?',
        'ar': 'مغادرة الفريق؟',
        'zh': '离开队伍？',
        'bn': 'স্কোয়াড ত্যাগ করবেন?'
    },
    'btn_leave': {
        'en': 'LEAVE',
        'ur': 'چھوڑیں',
        'ro': 'LEAVE',
        'hi': 'छोड़ें',
        'ar': 'مغادرة',
        'zh': '离开',
        'bn': 'ত্যাগ'
    },
    'you_left_squad': {
        'en': 'You left the squad',
        'ur': 'آپ اسکواڈ سے نکل گئے',
        'ro': 'Aap squad se nikal gaye',
        'hi': 'आप दस्ता छोड़ चुके हैं',
        'ar': 'لقد غادرت الفريق',
        'zh': '您已离开队伍',
        'bn': 'আপনি স্কোয়াড ত্যাগ করেছেন'
    },
    'end_squad_q': {
        'en': 'End Squad?',
        'ur': 'اسکواڈ ختم کریں؟',
        'ro': 'Squad Khatam Karein?',
        'hi': 'दस्ता समाप्त करें?',
        'ar': 'إنهاء الفريق؟',
        'zh': '解散队伍？',
        'bn': 'স্কোয়াড শেষ করবেন?'
    },
    'btn_end_squad': {
        'en': 'END SQUAD',
        'ur': 'اسکواڈ ختم کریں',
        'ro': 'END SQUAD',
        'hi': 'दस्ता समाप्त करें',
        'ar': 'إنهاء الفريق',
        'zh': '解散队伍',
        'bn': 'স্কোয়াড শেষ করুন'
    },
    'squad_ended': {
        'en': 'Squad ended',
        'ur': 'اسکواڈ ختم ہو گیا',
        'ro': 'Squad khatam ho gaya',
        'hi': 'दस्ता समाप्त हो गया',
        'ar': 'تم إنهاء الفريق',
        'zh': '队伍已解散',
        'bn': 'স্কোয়াড শেষ হয়েছে'
    },
    'win_proof_submitted_waiting': {
        'en': 'Win proof submitted! Waiting for host approval.',
        'ur': 'جیت کا ثبوت بھیج دیا گیا! ہوسٹ کی منظوری کا انتظار کریں۔',
        'ro': 'Win proof submit ho gaya! Host approval ka intezar karein.',
        'hi': 'जीत का प्रमाण जमा किया गया! होस्ट की मंजूरी का इंतजार करें।',
        'ar': 'تم إرسال إثبات الفوز! بانتظار موافقة المضيف.',
        'zh': '获胜证明已提交！等待房主批准。',
        'bn': 'জয়ের প্রমাণ জমা দেওয়া হয়েছে! হোস্টের অনুমোদনের জন্য অপেক্ষা করা হচ্ছে।'
    },
    # Match Room & Custom Rooms
    'report_loss_defeat': {
        'en': 'Report Loss / Defeat',
        'ur': 'شکست رپورٹ کریں',
        'ro': 'Shikast Report Karein',
        'hi': 'हार की रिपोर्ट करें',
        'ar': 'الإبلاغ عن الخسارة / الهزيمة',
        'zh': '报告战败',
        'bn': 'পরাজয় রিপোর্ট করুন'
    },
    'we_won_claim': {
        'en': 'WE WON! (Claim Victory)',
        'ur': 'ہم جیت گئے! (جیت کا دعویٰ)',
        'ro': 'WE WON! (Jeet Ka Dawa)',
        'hi': 'हम जीत गए! (जीत का दावा)',
        'ar': 'لقد فزنا! (طلب الفوز)',
        'zh': '我们赢了！（声明胜利）',
        'bn': 'আমরা জিতেছি! (জয়ের দাবি)'
    },
    'cancel_challenge_q': {
        'en': 'Cancel Challenge?',
        'ur': 'چیلنج منسوخ کریں؟',
        'ro': 'Challenge Cancel Karein?',
        'hi': 'चुनौती रद्द करें?',
        'ar': 'إلغاء التحدي؟',
        'zh': '取消挑战？',
        'bn': 'চ্যালেঞ্জ বাতিল করবেন?'
    },
    'btn_yes_cancel': {
        'en': 'Yes, Cancel',
        'ur': 'ہاں، منسوخ کریں',
        'ro': 'Haan, Cancel Karein',
        'hi': 'हाँ, रद्द करें',
        'ar': 'نعم، إلغاء',
        'zh': '是的，取消',
        'bn': 'হ্যাঁ, বাতিল করুন'
    },
    'btn_no_back': {
        'en': 'No, Go Back',
        'ur': 'نہیں، واپس جائیں',
        'ro': 'Nahi, Wapis',
        'hi': 'नहीं, वापस जाएं',
        'ar': 'لا، العودة',
        'zh': '不，返回',
        'bn': 'না, ফিরে যান'
    },
    'btn_accept_challenge_caps': {
        'en': 'ACCEPT CHALLENGE ✅',
        'ur': 'چیلنج قبول کریں ✅',
        'ro': 'ACCEPT CHALLENGE ✅',
        'hi': 'चुनौती स्वीकार करें ✅',
        'ar': 'قبول التحدي ✅',
        'zh': '接受挑战 ✅',
        'bn': 'চ্যালেঞ্জ গ্রহণ করুন ✅'
    },
    'disputed_match_alert': {
        'en': 'DISPUTED MATCH ⚠️',
        'ur': 'تنازعہ زدہ میچ ⚠️',
        'ro': 'DISPUTED MATCH ⚠️',
        'hi': 'विवादित मैच ⚠️',
        'ar': 'مباراة متنازع عليها ⚠️',
        'zh': '有争议的比赛 ⚠️',
        'bn': 'বিতর্কিত ম্যাচ ⚠️'
    },
    'dispute_admin_review_notice': {
        'en': 'Proofs from both teams sent to admin for final review.',
        'ur': 'دونوں ٹیموں کے ثبوت ایڈمن کو حتمی فیصلے کے لیے بھیج دیے گئے ہیں۔',
        'ro': 'Dono teams ke proofs admin ko final review ke liye bhej diye gaye hain.',
        'hi': 'अंतिम निर्णय के लिए दोनों टीमों के प्रमाण व्यवस्थापक को भेज दिए गए हैं।',
        'ar': 'تم إرسال أدلة الفريقين إلى المشرف للقرار النهائي.',
        'zh': '双方队伍的证据已提交给管理员进行最终审核。',
        'bn': 'উভয় দলের প্রমাণ চূড়ান্ত সিদ্ধান্তের জন্য অ্যাডমিনের কাছে পাঠানো হয়েছে।'
    },
    'host_custom_room': {
        'en': 'Host Custom Room',
        'ur': 'کسٹم روم بنائیں',
        'ro': 'Custom Room Host Karein',
        'hi': 'कस्टम रूम होस्ट करें',
        'ar': 'استضافة غرفة مخصصة',
        'zh': '创建自定义房间',
        'bn': 'কাস্টম রুম হোস্ট করুন'
    },
    'room_published_success': {
        'en': 'Room published successfully!',
        'ur': 'روم کامیابی سے شائع ہو گیا!',
        'ro': 'Room kamyabi se publish ho gaya!',
        'hi': 'कमरा सफलतापूर्वक प्रकाशित हुआ!',
        'ar': 'تم نشر الغرفة بنجاح!',
        'zh': '房间发布成功！',
        'bn': 'রুম সফলভাবে প্রকাশিত হয়েছে!'
    },
    'clear_chat_q': {
        'en': 'Clear Chat?',
        'ur': 'چیٹ صاف کریں؟',
        'ro': 'Chat Clear Karein?',
        'hi': 'चैट साफ़ करें?',
        'ar': 'مسح الدردشة؟',
        'zh': '清空聊天？',
        'bn': 'চ্যাট পরিষ্কার করবেন?'
    },
    'btn_clear_chat_caps': {
        'en': 'CLEAR CHAT',
        'ur': 'چیٹ صاف کریں',
        'ro': 'CLEAR CHAT',
        'hi': 'चैट साफ़ करें',
        'ar': 'مسح الدردشة',
        'zh': '清空聊天',
        'bn': 'চ্যাট পরিষ্কার করুন'
    },
    'chat_cleared_success': {
        'en': 'Chat cleared successfully!',
        'ur': 'چیٹ کامیابی سے صاف کر دی گئی!',
        'ro': 'Chat clear ho gayi!',
        'hi': 'चैट सफलतापूर्वक साफ़ हो गई!',
        'ar': 'تم مسح الدردشة بنجاح!',
        'zh': '聊天记录已成功清空！',
        'bn': 'চ্যাট সফলভাবে পরিষ্কার করা হয়েছে!'
    },
}

# Merge into all 7 json files
for k, translations in new_keys.items():
    for l in langs:
        trans_data[l][k] = translations[l]

for l in langs:
    with open(f'assets/translations/{l}.json', 'w', encoding='utf-8') as f:
        json.dump(trans_data[l], f, ensure_ascii=False, indent=2)

print(f'Successfully updated all 7 translation files. Current key count: {len(trans_data[\"en\"])}')
