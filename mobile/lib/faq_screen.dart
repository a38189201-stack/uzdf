import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_widgets.dart';
import 'app_state.dart';

class FaqScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const FaqScreen({super.key, this.initialSearchQuery});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
      _searchCtrl.text = widget.initialSearchQuery!;
    }
  }

  final Map<String, List<Map<String, String>>> _faqData = {
    'ru': [
      {
        'category': '🛸 Общие вопросы',
        'q': 'Что такое UZDF?',
        'a': 'UZDF (Uzbekistan Drone Federation) — это Федерация дронов Узбекистана и единая цифровая платформа для пилотов БПЛА (дронов), помогающая летать безопасно, изучать правила воздушного пространства, проходить обучение и приобретать сертифицированное оборудование.'
      },
      {
        'category': '🛸 Общие вопросы',
        'q': 'Как начать пользоваться платформой?',
        'a': 'Зарегистрируйтесь в приложении или на сайте UZDF с помощью Email. После этого вам станут доступны интерактивная карта зон и обучающие курсы.'
      },
      {
        'category': '🗺 Карта полетных зон',
        'q': 'Что означают цвета зон на карте?',
        'a': 'Красная зона (🔴 RED): Полеты категорически запрещены. Желтая зона (🟡 YELLOW): Полеты ограничены по высоте (обычно до 50м) или требуют согласования. Зеленая зона (🟢 GREEN): Свободные полеты в соответствии с общими правилами БПЛА.'
      },
      {
        'category': '🗺 Карта полетных зон',
        'q': 'Как узнать точную разрешенную высоту?',
        'a': 'Кликните на интересующую зону на карте, чтобы открыть детальную карточку с информацией о названии зоны и максимальной разрешенной высоте полета.'
      },
      {
        'category': '❤️ Курсы и Жизни',
        'q': 'Как устроена система попыток (❤️)?',
        'a': 'Каждому пилоту дается 3 попытки (жизни). При совершении хотя бы одной ошибки в тесте или при фиксации нарушений (скриншоты/запись экрана) сгорает 1 жизнь. Раз в 24 часа автоматически восстанавливается +1 жизнь (максимум до 3х).'
      },
      {
        'category': '❤️ Курсы и Жизни',
        'q': 'За что блокируется доступ к обучению?',
        'a': 'В целях защиты учебных материалов съемка скриншотов или запись экрана в приложении UZDF запрещены. При фиксации 5 нарушений доступ к курсу автоматически блокируется на 24 часа.'
      },
      {
        'category': '❤️ Курсы и Жизни',
        'q': 'Как получить цифровой сертификат?',
        'a': 'Успешно завершите все уроки курса и сдайте финальный экзамен (порог сдачи — не менее 95% правильных ответов). Сертификат с уникальным UUID появится в вашем профиле UZDF.'
      },
      {
        'category': '🛒 Магазин и Заказы',
        'q': 'Как купить дрон или комплектующие?',
        'a': 'Перейдите в раздел «Магазин», выберите товар и нажмите кнопку оформления. Ваш заказ будет сохранен в базе UZDF.'
      },
      {
        'category': '🛒 Магазин и Заказы',
        'q': 'Как указать адрес доставки?',
        'a': 'После оформления перейдите в профиль -> «Мои заказы», выберите ваш заказ и заполните форму доставки (Адрес, Город, Телефон).'
      },
    ],
    'uz': [
      {
        'category': '🛸 Umumiy savollar',
        'q': 'UZDF nima?',
        'a': 'UZDF (Uzbekistan Drone Federation) — O\'zbekiston dronlar federatsiyasi va BUA (dron) uchuvchilari uchun yagona raqamli platforma bo\'lib, xavfsiz parvoz qilish, havo hududi qoidalarini o\'rganish, ta\'lim olish va sertifikatlangan uskunalarni sotib olishga yordam beradi.'
      },
      {
        'category': '🛸 Umumiy savollar',
        'q': 'Platformadan foydalanishni qanday boshlash kerak?',
        'a': 'Email orqali UZDF ilovasida yoki saytida ro\'yxatdan o\'ting. Shundan so\'ng interaktiv xarita va o\'quv kurslari sizga taqdim etiladi.'
      },
      {
        'category': '🗺 Parvoz zonalari xaritasi',
        'q': 'Xaritadagi zonalarning ranglari nimani anglatadi?',
        'a': 'Qizil zona (🔴 RED): Parvozlar qat\'iyan taqiqlanadi. Sariq zona (🟡 YELLOW): Parvozlar balandligi cheklangan (odatda 50 metrgacha) yoki kelishuv talab etiladi. Yashil zona (🟢 GREEN): BUA umumiy qoidalariga muvofiq erkin parvozlar.'
      },
      {
        'category': '🗺 Parvoz zonalari xaritasi',
        'q': 'Ruxsat etilgan aniq balandlikni qanday bilish mumkin?',
        'a': 'Qiziqtirgan zonani ustiga bosing, shunda zona nomi va maksimal ruxsat etilgan parvoz balandligi ko\'rsatilgan ma\'lumotlar oynasi ochiladi.'
      },
      {
        'category': '❤️ Kurslar va urinishlar',
        'q': 'Urinishlar (❤️) tizimi qanday ishlaydi?',
        'a': 'Har bir uchuvchiga 3 ta urinish (hayot) beriladi. Testda bitta xatoga yo\'l qo\'yilganda yoki qoida buzilishi (skrinshot/ekran yozuvi) aniqlanganda 1 ta hayot kamayadi. Har 24 soatda avtomatik ravishda +1 urinish tiklanadi (maksimal 3 tagacha).'
      },
      {
        'category': '❤️ Kurslar va urinishlar',
        'q': 'O\'qish imkoniyati nima sababdan bloklanadi?',
        'a': 'O\'quv materiallarini himoya qilish maqsadida UZDF ilovasida skrinshot olish yoki ekranni yozib olish taqiqlanadi. 5 marta qoida buzilishi qayd etilsa, kursga kirish 24 soatga avtomatik bloklanadi.'
      },
      {
        'category': '❤️ Kurslar va urinishlar',
        'q': 'Raqamli sertifikatni qanday olish mumkin?',
        'a': 'Kursning barcha darslarini yakunlang va yakuniy imtihonni topshiring (kamida 95% to\'g\'ri javob). Noyob UUID bilan sertifikat profilingizda paydo bo\'ladi.'
      },
      {
        'category': '🛒 Do\'kon va Buyurtmalar',
        'q': 'Dron yoki butlovchi qismlarni qanday sotib olish mumkin?',
        'a': '"Do\'kon" bo\'limiga o\'ting, mahsulotni tanlang va buyurtma berish tugmasini bosing. Buyurtmangiz saqlanib qoladi.'
      },
      {
        'category': '🛒 Do\'kon va Buyurtmalar',
        'q': 'Yetkazib berish manzili qanday ko\'rsatiladi?',
        'a': 'Buyurtma berganingizdan so\'ng profil -> "Mening buyurtmalarim" bo\'limiga o\'ting, buyurtmangizni tanlang va yetkazib berish formasini to\'ldiring (Manzil, Shahar, Telefon).'
      },
    ],
    'en': [
      {
        'category': '🛸 General Questions',
        'q': 'What is UZDF?',
        'a': 'UZDF (Uzbekistan Drone Federation) is the Drone Federation of Uzbekistan and a unified digital platform for UAV (drone) pilots, helping to fly safely, study airspace regulations, undergo training, and purchase certified equipment.'
      },
      {
        'category': '🛸 General Questions',
        'q': 'How to start using the platform?',
        'a': 'Register on the UZDF app or website using your Email. After that, the interactive airspace map and training courses will become available to you.'
      },
      {
        'category': '🗺 Flight Zones Map',
        'q': 'What do the zone colors on the map mean?',
        'a': 'Red zone (🔴 RED): Flights are strictly prohibited. Yellow zone (🟡 YELLOW): Flights are altitude-limited (usually up to 50m) or require approval. Green zone (🟢 GREEN): Free flights in compliance with general UAV regulations.'
      },
      {
        'category': '🗺 Flight Zones Map',
        'q': 'How to find the exact allowed altitude?',
        'a': 'Click on the zone of interest on the map to open a detailed card with the zone name and maximum allowed flight altitude.'
      },
      {
        'category': '❤️ Courses & Lives',
        'q': 'How does the attempts (❤️) system work?',
        'a': 'Each pilot is given 3 attempts (lives). Making a single mistake in a quiz or committing a security violation (screenshots/screen recording) burns 1 life. Every 24 hours, +1 life is restored automatically (up to a maximum of 3).'
      },
      {
        'category': '❤️ Courses & Lives',
        'q': 'What causes access to training to be blocked?',
        'a': 'To protect educational materials, screenshots and screen recording are prohibited in the UZDF app. Upon reaching 5 violations, access to the course is automatically blocked for 24 hours.'
      },
      {
        'category': '❤️ Courses & Lives',
        'q': 'How to obtain a digital certificate?',
        'a': 'Successfully complete all course steps and pass the final exam (passing score is at least 95%). A certificate with a unique UUID will appear in your UZDF profile.'
      },
      {
        'category': '🛒 Shop & Orders',
        'q': 'How to buy a drone or components?',
        'a': 'Go to the "Shop" section, select a product, and click the checkout button. Your order will be saved.'
      },
      {
        'category': '🛒 Shop & Orders',
        'q': 'How to specify the delivery address?',
        'a': 'After checking out, go to Profile -> "My Orders", select your order, and fill out the delivery form (Address, City, Phone).'
      },
    ],
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    final lang = state.currentLanguage.value;
    final isDark = state.isDarkMode.value;

    final items = _faqData[lang] ?? _faqData['en'] ?? [];
    final filtered = items.where((item) {
      final q = item['q']?.toLowerCase() ?? '';
      final a = item['a']?.toLowerCase() ?? '';
      final c = item['category']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return q.contains(query) || a.contains(query) || c.contains(query);
    }).toList();

    // Group items by category
    final Map<String, List<Map<String, String>>> groups = {};
    for (var item in filtered) {
      final cat = item['category'] ?? 'FAQ';
      groups.putIfAbsent(cat, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: GlassAppBar(
        title: Text(
          state.translate('profile_faq'),
          style: const TextStyle(fontWeight: FontWeight.w400, letterSpacing: -0.5),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
                decoration: getGlassInputDecoration(
                  hintText: lang == 'ru'
                      ? 'Поиск по ключевым словам...'
                      : lang == 'uz'
                          ? 'Kalit so\'zlar bo\'yicha qidiruv...'
                          : 'Search by keywords...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _searchCtrl.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  context: context,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            lang == 'ru'
                                ? 'Ничего не найдено'
                                : lang == 'uz'
                                    ? 'Hech narsa topilmadi'
                                    : 'No results found',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final catName = groups.keys.elementAt(index);
                        final catItems = groups[catName]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                              child: Text(
                                catName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...catItems.map((item) {
                              return GlassContainer(
                                margin: const EdgeInsets.only(bottom: 8),
                                borderRadius: 16,
                                padding: EdgeInsets.zero,
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Text(
                                      item['q'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    iconColor: const Color(0xFF007AFF),
                                    collapsedIconColor: Colors.grey,
                                    childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                    expandedAlignment: Alignment.topLeft,
                                    onExpansionChanged: (expanded) {
                                      HapticFeedback.lightImpact();
                                    },
                                    children: [
                                      Text(
                                        item['a'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.5,
                                          color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1C1C1E).withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
