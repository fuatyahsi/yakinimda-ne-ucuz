Map<String, dynamic> _ingredient(
  String ingredientId,
  String amountTr,
  String amountEn, {
  bool optional = false,
}) {
  return {
    'ingredient_id': ingredientId,
    'amount_tr': amountTr,
    'amount_en': amountEn,
    'is_optional': optional,
  };
}

Map<String, dynamic> _step(
  String tr,
  String en,
  int durationMinutes,
) {
  return {
    'tr': tr,
    'en': en,
    'duration': durationMinutes,
  };
}

String _descriptionTr(String nameTr, String category) {
  switch (category) {
    case 'breakfast':
      return '$nameTr, güne sıcak ve doyurucu bir başlangıç sunar.';
    case 'soup':
      return '$nameTr, sofraya rahatlatıcı ve dengeli bir çorba getirir.';
    case 'main':
      return '$nameTr, ana öğünde tek başına doyurucu bir seçenek sunar.';
    case 'side':
      return '$nameTr, ana yemeğin yanında güçlü bir eşlikçi olur.';
    case 'appetizer':
      return '$nameTr, sofrayı açan paylaşımlık bir başlangıçtır.';
    case 'salad':
      return '$nameTr, ferah ve dengeli bir salata seçeneğidir.';
    case 'dessert':
      return '$nameTr, tatlı kapanış için yumuşak bir alternatif sunar.';
    case 'beverage':
      return '$nameTr, öğüne eşlik eden serinletici bir içecektir.';
    default:
      return '$nameTr, ev mutfağına uygun özgün bir tariftir.';
  }
}

String _descriptionEn(String nameEn, String category) {
  switch (category) {
    case 'breakfast':
      return '$nameEn offers a warm and filling start to the day.';
    case 'soup':
      return '$nameEn brings a comforting and balanced bowl to the table.';
    case 'main':
      return '$nameEn works as a satisfying centerpiece for the main meal.';
    case 'side':
      return '$nameEn is a dependable side dish for everyday meals.';
    case 'appetizer':
      return '$nameEn is a shareable starter for a fuller table.';
    case 'salad':
      return '$nameEn keeps the meal fresh and balanced.';
    case 'dessert':
      return '$nameEn offers a soft and memorable finish.';
    case 'beverage':
      return '$nameEn is a refreshing drink to round out the meal.';
    default:
      return '$nameEn is an original home-style recipe.';
  }
}

Map<String, dynamic> _recipe({
  required String id,
  required String nameTr,
  required String nameEn,
  required String imageEmoji,
  required String category,
  required String difficulty,
  required int prepTimeMinutes,
  required int cookTimeMinutes,
  required int servings,
  required List<String> tags,
  required List<Map<String, dynamic>> ingredients,
  required List<Map<String, dynamic>> steps,
}) {
  return {
    'id': id,
    'name_tr': nameTr,
    'name_en': nameEn,
    'description_tr': _descriptionTr(nameTr, category),
    'description_en': _descriptionEn(nameEn, category),
    'image_emoji': imageEmoji,
    'category': category,
    'difficulty': difficulty,
    'prep_time_minutes': prepTimeMinutes,
    'cook_time_minutes': cookTimeMinutes,
    'servings': servings,
    'tags': tags,
    'ingredients': ingredients,
    'steps_tr': [
      for (var index = 0; index < steps.length; index++)
        {
          'step_number': index + 1,
          'instruction': steps[index]['tr'],
          'duration_minutes': steps[index]['duration'],
        },
    ],
    'steps_en': [
      for (var index = 0; index < steps.length; index++)
        {
          'step_number': index + 1,
          'instruction': steps[index]['en'],
          'duration_minutes': steps[index]['duration'],
        },
    ],
  };
}

List<Map<String, dynamic>> buildCuratedRecipeCatalog() {
  return [
    _recipe(
      id: 'cilbir',
      nameTr: 'Çılbır',
      nameEn: 'Turkish Poached Eggs',
      imageEmoji: '🍳',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 8,
      servings: 2,
      tags: ['kahvalti', 'yumurta', 'yogurt'],
      ingredients: [
        _ingredient('egg', '2 adet', '2 pieces'),
        _ingredient('yogurt', '1 su bardağı', '1 cup'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('red_pepper_flakes', '1 çay kaşığı', '1 teaspoon',
            optional: true),
        _ingredient('bread', '2 dilim', '2 slices'),
      ],
      steps: [
        _step(
          'Yoğurt ve ezilmiş sarımsağı karıştırıp servis tabağına yay.',
          'Mix the yogurt with crushed garlic and spread it on the serving plate.',
          3,
        ),
        _step(
          'Yumurtaları poşe et, tereyağında pul biberi kısa süre çevirip üzerine gezdir.',
          'Poach the eggs and spoon over butter briefly warmed with pepper flakes.',
          5,
        ),
      ],
    ),
    _recipe(
      id: 'muhlama',
      nameTr: 'Muhlama',
      nameEn: 'Cornmeal Cheese Skillet',
      imageEmoji: '🫕',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 2,
      tags: ['kahvalti', 'peynir', 'karadeniz'],
      ingredients: [
        _ingredient('butter', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('cornmeal', '3 yemek kaşığı', '3 tablespoons'),
        _ingredient('water', '1 su bardağı', '1 cup'),
        _ingredient('cheese_kashar', '200 gram', '200 grams'),
        _ingredient('salt', '1 tutam', '1 pinch', optional: true),
        _ingredient('bread', '4 dilim', '4 slices'),
      ],
      steps: [
        _step(
          'Tereyağında mısır ununu kokusu çıkana kadar kavur, suyu ekleyip kıvam ver.',
          'Toast the cornmeal in butter, then add water and stir until thickened.',
          5,
        ),
        _step(
          'Kaşarı ekleyip eriyene kadar karıştırmadan beklet, ekmekle sıcak servis et.',
          'Add the cheese, let it melt into the skillet, and serve hot with bread.',
          5,
        ),
      ],
    ),
    _recipe(
      id: 'kaygana_ispanakli',
      nameTr: 'Ispanaklı Kaygana',
      nameEn: 'Spinach Kaygana',
      imageEmoji: '🥞',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 12,
      servings: 3,
      tags: ['kahvalti', 'ispanak', 'tava'],
      ingredients: [
        _ingredient('egg', '3 adet', '3 pieces'),
        _ingredient('milk', '1 su bardağı', '1 cup'),
        _ingredient('flour', '1 su bardağı', '1 cup'),
        _ingredient('spinach', '1 avuç', '1 handful'),
        _ingredient('scallion', '2 dal', '2 stalks', optional: true),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
      ],
      steps: [
        _step(
          'Yumurta, süt ve unu pürüzsüz çırpıp ince doğranmış ıspanakla birleştir.',
          'Whisk eggs, milk, and flour smooth, then fold in finely chopped spinach.',
          5,
        ),
        _step(
          'Karışımı tavaya döküp iki yüzünü de altın renk alana kadar pişir.',
          'Pour into the pan and cook both sides until lightly golden.',
          7,
        ),
      ],
    ),
    _recipe(
      id: 'avokadolu_yumurtali_tost',
      nameTr: 'Avokadolu Yumurtalı Tost',
      nameEn: 'Avocado Egg Toast',
      imageEmoji: '🥑',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 6,
      servings: 2,
      tags: ['kahvalti', 'avokado', 'tost'],
      ingredients: [
        _ingredient('whole_wheat_bread', '4 dilim', '4 slices'),
        _ingredient('avocado', '1 adet', '1 piece'),
        _ingredient('egg', '2 adet', '2 pieces'),
        _ingredient('lemon', '1/2 adet', '1/2 piece'),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
        _ingredient('olive_oil', '1 tatlı kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Ekmeği kızart, avokadoyu limonla ezip üzerine sür.',
          'Toast the bread and spread the avocado mashed with lemon on top.',
          4,
        ),
        _step(
          'Yumurtaları tavada pişirip tostların üzerine yerleştir, karabiber serp.',
          'Cook the eggs in a pan, place them on the toast, and finish with black pepper.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'labneli_biberli_tost',
      nameTr: 'Labneli Biberli Tost',
      nameEn: 'Labneh Pepper Toast',
      imageEmoji: '🥪',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 7,
      cookTimeMinutes: 5,
      servings: 2,
      tags: ['kahvalti', 'labne', 'biber'],
      ingredients: [
        _ingredient('rye_bread', '4 dilim', '4 slices'),
        _ingredient('labneh', '4 yemek kaşığı', '4 tablespoons'),
        _ingredient('capia_pepper', '1 adet', '1 piece'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('oregano', '1 çay kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Kapya biberi ince dilimleyip zeytinyağında kısa süre yumuşat.',
          'Slice the capia pepper thinly and soften it briefly in olive oil.',
          3,
        ),
        _step(
          'Ekmeğe labne sür, biberleri yerleştir ve istersen kekikle tamamla.',
          'Spread labneh on the bread, top with peppers, and finish with oregano if desired.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'yulafli_elma_kasesi',
      nameTr: 'Yulaflı Elma Kasesi',
      nameEn: 'Apple Oat Bowl',
      imageEmoji: '🥣',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 8,
      servings: 2,
      tags: ['kahvalti', 'yulaf', 'elma'],
      ingredients: [
        _ingredient('oats', '1 su bardağı', '1 cup'),
        _ingredient('milk', '2 su bardağı', '2 cups'),
        _ingredient('apple', '1 adet', '1 piece'),
        _ingredient('cinnamon', '1 çay kaşığı', '1 teaspoon'),
        _ingredient('honey', '1 yemek kaşığı', '1 tablespoon', optional: true),
        _ingredient('walnut', '2 yemek kaşığı', '2 tablespoons',
            optional: true),
      ],
      steps: [
        _step(
          'Yulafı sütle pişirip koyulaşınca tarçın ve doğranmış elmayı ekle.',
          'Cook the oats in milk and add cinnamon and chopped apple once thickened.',
          6,
        ),
        _step(
          'Kaseye alıp bal ve cevizle sıcak servis et.',
          'Transfer to bowls and serve warm with honey and walnuts.',
          2,
        ),
      ],
    ),
    _recipe(
      id: 'ricottali_incir_tost',
      nameTr: 'Ricottalı İncir Tost',
      nameEn: 'Ricotta Fig Toast',
      imageEmoji: '🍞',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 6,
      cookTimeMinutes: 4,
      servings: 2,
      tags: ['kahvalti', 'ricotta', 'incir'],
      ingredients: [
        _ingredient('whole_wheat_bread', '4 dilim', '4 slices'),
        _ingredient('ricotta', '4 yemek kaşığı', '4 tablespoons'),
        _ingredient('fig', '2 adet', '2 pieces'),
        _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true),
        _ingredient('pistachio', '1 yemek kaşığı', '1 tablespoon',
            optional: true),
      ],
      steps: [
        _step(
          'Ekmeği kızartıp ricottayı üzerine yay.',
          'Toast the bread and spread the ricotta over it.',
          2,
        ),
        _step(
          'İncir dilimleri, bal ve Antep fıstığı ile tamamla.',
          'Top with sliced figs, honey, and pistachios.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'mantarli_cheddar_tava_ekmek',
      nameTr: 'Mantarlı Cheddarlı Tava Ekmek',
      nameEn: 'Mushroom Cheddar Skillet Bread',
      imageEmoji: '🍄',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 10,
      servings: 2,
      tags: ['kahvalti', 'mantar', 'cheddar'],
      ingredients: [
        _ingredient('bread', '4 dilim', '4 slices'),
        _ingredient('mushroom', '150 gram', '150 grams'),
        _ingredient('cheddar', '80 gram', '80 grams'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Mantarı tereyağında sotele, karabiberle tatlandır.',
          'Sauté the mushrooms in butter and season with black pepper.',
          5,
        ),
        _step(
          'Ekmeği tavada ısıtıp cheddar ve mantarla birleştir, peynir eriyince servis et.',
          'Warm the bread in the pan, add cheddar and mushrooms, and serve once melted.',
          5,
        ),
      ],
    ),
    _recipe(
      id: 'pazili_peynirli_durme',
      nameTr: 'Pazılı Peynirli Dürme',
      nameEn: 'Chard and Cheese Wrap',
      imageEmoji: '🌯',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 8,
      servings: 2,
      tags: ['kahvalti', 'pazi', 'durum'],
      ingredients: [
        _ingredient('tortilla', '2 adet', '2 pieces'),
        _ingredient('chard', '1 avuç', '1 handful'),
        _ingredient('cheese_white', '100 gram', '100 grams'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('scallion', '2 dal', '2 stalks', optional: true),
      ],
      steps: [
        _step(
          'Pazı ve taze soğanı zeytinyağında soldurup peynirle karıştır.',
          'Wilt the chard and green onion in olive oil, then combine with cheese.',
          4,
        ),
        _step(
          'Karışımı tortillalara paylaştırıp dürüm yap ve tavada kısa süre çevir.',
          'Fill the tortillas, roll them up, and warm briefly in a skillet.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'kinoali_meyve_kasesi',
      nameTr: 'Kinoalı Meyve Kasesi',
      nameEn: 'Quinoa Fruit Bowl',
      imageEmoji: '🍓',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 15,
      servings: 2,
      tags: ['kahvalti', 'kinoa', 'meyve'],
      ingredients: [
        _ingredient('quinoa', '1/2 su bardağı', '1/2 cup'),
        _ingredient('milk', '1 su bardağı', '1 cup'),
        _ingredient('banana', '1 adet', '1 piece'),
        _ingredient('strawberry', '6 adet', '6 pieces'),
        _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Kinoayı sütle yumuşayana kadar pişir ve biraz ılınmaya bırak.',
          'Cook the quinoa in milk until tender, then let it cool slightly.',
          10,
        ),
        _step(
          'Muz ve çilekle karıştırıp istersen bal ekleyerek servis et.',
          'Mix with banana and strawberries and sweeten with honey if desired.',
          5,
        ),
      ],
    ),
    _recipe(
      id: 'kuskonmazli_yumurta_tava',
      nameTr: 'Kuşkonmazlı Yumurta Tava',
      nameEn: 'Asparagus Egg Skillet',
      imageEmoji: '🍳',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 6,
      cookTimeMinutes: 8,
      servings: 2,
      tags: ['kahvalti', 'kuskonmaz', 'yumurta'],
      ingredients: [
        _ingredient('asparagus', '6 dal', '6 stalks'),
        _ingredient('egg', '3 adet', '3 pieces'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('parmesan', '2 yemek kaşığı', '2 tablespoons',
            optional: true),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Kuşkonmazları tereyağında hafif yumuşayana kadar sotele.',
          'Sauté the asparagus in butter until just tender.',
          4,
        ),
        _step(
          'Üzerine yumurtaları kır, kapağını kapat ve parmesanla tamamla.',
          'Crack the eggs over the top, cover the pan, and finish with parmesan.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'mozzarellali_domatesli_pide_tost',
      nameTr: 'Mozzarellalı Domatesli Pide Tost',
      nameEn: 'Mozzarella Tomato Pita Toast',
      imageEmoji: '🧀',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 6,
      cookTimeMinutes: 7,
      servings: 2,
      tags: ['kahvalti', 'mozzarella', 'domates'],
      ingredients: [
        _ingredient('pita', '2 adet', '2 pieces'),
        _ingredient('mozzarella', '100 gram', '100 grams'),
        _ingredient('tomato', '1 adet', '1 piece'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('basil_dried', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Pideleri açıp üzerine domates dilimleri ve mozzarella yerleştir.',
          'Split the pita and layer it with sliced tomato and mozzarella.',
          3,
        ),
        _step(
          'Fırında veya tavada peynir eriyene kadar ısıt, fesleğenle bitir.',
          'Heat in the oven or pan until the cheese melts and finish with basil.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'tahinli_muzlu_yulaf',
      nameTr: 'Tahinli Muzlu Yulaf',
      nameEn: 'Tahini Banana Oats',
      imageEmoji: '🥣',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 4,
      cookTimeMinutes: 6,
      servings: 2,
      tags: ['kahvalti', 'tahin', 'muz'],
      ingredients: [
        _ingredient('oats', '1 su bardağı', '1 cup'),
        _ingredient('milk', '2 su bardağı', '2 cups'),
        _ingredient('banana', '1 adet', '1 piece'),
        _ingredient('tahini', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Yulafı sütle pişirip muzun yarısını içine ezerek karıştır.',
          'Cook the oats in milk and mash half the banana into the pot.',
          4,
        ),
        _step(
          'Tahin ve kalan muz dilimleriyle üstünü tamamlayıp servis et.',
          'Finish with tahini and the remaining banana slices before serving.',
          2,
        ),
      ],
    ),
    _recipe(
      id: 'kapya_biberli_omlet',
      nameTr: 'Kapya Biberli Omlet',
      nameEn: 'Capia Pepper Omelet',
      imageEmoji: '🍳',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 8,
      servings: 2,
      tags: ['kahvalti', 'omlet', 'biber'],
      ingredients: [
        _ingredient('egg', '4 adet', '4 pieces'),
        _ingredient('capia_pepper', '1 adet', '1 piece'),
        _ingredient('cheese_white', '60 gram', '60 grams', optional: true),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Kapya biberi küçük doğrayıp tereyağında birkaç dakika çevir.',
          'Dice the capia pepper and cook it in butter for a few minutes.',
          3,
        ),
        _step(
          'Çırpılmış yumurtayı ekleyip omleti pişir, istersen beyaz peynir serp.',
          'Add the beaten eggs, cook the omelet, and sprinkle over white cheese if desired.',
          5,
        ),
      ],
    ),
    _recipe(
      id: 'labneli_salatalikli_cavdar',
      nameTr: 'Labneli Salatalıklı Çavdar',
      nameEn: 'Rye Bread with Labneh and Cucumber',
      imageEmoji: '🥒',
      category: 'breakfast',
      difficulty: 'easy',
      prepTimeMinutes: 5,
      cookTimeMinutes: 0,
      servings: 2,
      tags: ['kahvalti', 'labne', 'salatalik'],
      ingredients: [
        _ingredient('rye_bread', '4 dilim', '4 slices'),
        _ingredient('labneh', '4 yemek kaşığı', '4 tablespoons'),
        _ingredient('cucumber', '1 adet', '1 piece'),
        _ingredient('dill', '1 tutam', '1 pinch', optional: true),
        _ingredient('olive_oil', '1 tatlı kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Çavdar ekmeğine labneyi sür ve salatalığı ince dilimle.',
          'Spread the labneh over the rye bread and slice the cucumber thinly.',
          3,
        ),
        _step(
          'Dereotu ve birkaç damla zeytinyağı ile tamamlayıp servis et.',
          'Top with dill and a few drops of olive oil before serving.',
          2,
        ),
      ],
    ),
    _recipe(
      id: 'dugun_corbasi',
      nameTr: 'Düğün Çorbası',
      nameEn: 'Wedding Soup',
      imageEmoji: '🍲',
      category: 'soup',
      difficulty: 'medium',
      prepTimeMinutes: 12,
      cookTimeMinutes: 30,
      servings: 4,
      tags: ['corba', 'kuzu', 'klasik'],
      ingredients: [
        _ingredient('lamb', '300 gram', '300 grams'),
        _ingredient('flour', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('egg', '1 adet', '1 piece'),
        _ingredient('lemon', '1 adet', '1 piece'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('water', '5 su bardağı', '5 cups'),
      ],
      steps: [
        _step(
          'Kuzu etini suyla yumuşayana kadar haşla ve suyunu süzmeden ayır.',
          'Boil the lamb in water until tender and keep the cooking broth.',
          20,
        ),
        _step(
          'Un, yumurta ve limonla terbiyeyi hazırlayıp et suyuna ekle, eti didikleyip tereyağıyla tamamla.',
          'Prepare the flour, egg, and lemon liaison, add it to the broth, then return the shredded lamb and finish with butter.',
          10,
        ),
      ],
    ),
    _recipe(
      id: 'yayla_corbasi',
      nameTr: 'Naneli Yayla Çorbası',
      nameEn: 'Minted Yogurt Rice Soup',
      imageEmoji: '🥣',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 20,
      servings: 4,
      tags: ['corba', 'yogurt', 'nane'],
      ingredients: [
        _ingredient('rice', '1/2 su bardağı', '1/2 cup'),
        _ingredient('yogurt', '1 su bardağı', '1 cup'),
        _ingredient('flour', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('egg', '1 adet', '1 piece'),
        _ingredient('mint_dried', '1 tatlı kaşığı', '1 teaspoon'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
      ],
      steps: [
        _step(
          'Pirinci suyla yumuşayıncaya kadar pişir.',
          'Cook the rice in water until soft.',
          12,
        ),
        _step(
          'Yoğurt, un ve yumurtayı çırpıp çorbaya ekle; naneli tereyağı ile bitir.',
          'Whisk yogurt, flour, and egg into the soup and finish with mint butter.',
          8,
        ),
      ],
    ),
    _recipe(
      id: 'feslegenli_domates_corbasi',
      nameTr: 'Fesleğenli Domates Çorbası',
      nameEn: 'Tomato Basil Soup',
      imageEmoji: '🍅',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 18,
      servings: 4,
      tags: ['corba', 'domates', 'feslegen'],
      ingredients: [
        _ingredient('tomato', '4 adet', '4 pieces'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('garlic', '2 diş', '2 cloves'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('basil_dried', '1 çay kaşığı', '1 teaspoon'),
        _ingredient('water', '4 su bardağı', '4 cups'),
      ],
      steps: [
        _step(
          'Soğan, sarımsak ve domatesi zeytinyağında birkaç dakika çevir.',
          'Cook the onion, garlic, and tomatoes in olive oil for a few minutes.',
          8,
        ),
        _step(
          'Su ekleyip kaynat, blenderdan geçir ve fesleğenle servis et.',
          'Add water, simmer, blend the soup, and serve with basil.',
          10,
        ),
      ],
    ),
    _recipe(
      id: 'tavuklu_sehriye_corbasi',
      nameTr: 'Tavuklu Şehriye Çorbası',
      nameEn: 'Chicken Vermicelli Soup',
      imageEmoji: '🍜',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 22,
      servings: 4,
      tags: ['corba', 'tavuk', 'sehriye'],
      ingredients: [
        _ingredient('chicken_breast', '250 gram', '250 grams'),
        _ingredient('vermicelli', '1/2 su bardağı', '1/2 cup'),
        _ingredient('carrot', '1 adet', '1 piece'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('parsley', '1 yemek kaşığı', '1 tablespoon',
            optional: true),
        _ingredient('water', '5 su bardağı', '5 cups'),
      ],
      steps: [
        _step(
          'Tavuk ve havucu suyla haşla, tavuğu didikle.',
          'Boil the chicken and carrot in water, then shred the chicken.',
          14,
        ),
        _step(
          'Şehriyeyi ekleyip yumuşat, tavukları geri koyup maydanozla servis et.',
          'Add the vermicelli, return the chicken to the pot, and finish with parsley.',
          8,
        ),
      ],
    ),
    _recipe(
      id: 'pirasali_patates_corbasi',
      nameTr: 'Pırasalı Patates Çorbası',
      nameEn: 'Leek Potato Soup',
      imageEmoji: '🥔',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 20,
      servings: 4,
      tags: ['corba', 'pirasa', 'patates'],
      ingredients: [
        _ingredient('leek', '1 adet', '1 piece'),
        _ingredient('potato', '2 adet', '2 pieces'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('milk', '1 su bardağı', '1 cup'),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
        _ingredient('water', '4 su bardağı', '4 cups'),
      ],
      steps: [
        _step(
          'Pırasa ve patatesi tereyağında kısa süre çevir.',
          'Cook the leek and potato briefly in butter.',
          5,
        ),
        _step(
          'Su ve sütü ekleyip yumuşayınca blenderdan geçir, karabiberle servis et.',
          'Add water and milk, simmer until tender, blend, and finish with black pepper.',
          15,
        ),
      ],
    ),
    _recipe(
      id: 'kabakli_nane_corbasi',
      nameTr: 'Kabaklı Nane Çorbası',
      nameEn: 'Zucchini Mint Soup',
      imageEmoji: '🥒',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 16,
      servings: 4,
      tags: ['corba', 'kabak', 'nane'],
      ingredients: [
        _ingredient('zucchini', '2 adet', '2 pieces'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('yogurt', '1/2 su bardağı', '1/2 cup'),
        _ingredient('mint_dried', '1 tatlı kaşığı', '1 teaspoon'),
        _ingredient('water', '4 su bardağı', '4 cups'),
      ],
      steps: [
        _step(
          'Soğan ve kabağı zeytinyağında çevirip suyu ekle.',
          'Cook the onion and zucchini in olive oil, then pour in the water.',
          6,
        ),
        _step(
          'Yumuşayınca blenderdan geçir, yoğurt ve nane ile tamamla.',
          'Blend until smooth and finish with yogurt and dried mint.',
          10,
        ),
      ],
    ),
    _recipe(
      id: 'nohutlu_arpa_corbasi',
      nameTr: 'Nohutlu Arpa Çorbası',
      nameEn: 'Chickpea Barley Soup',
      imageEmoji: '🍲',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 24,
      servings: 4,
      tags: ['corba', 'nohut', 'arpa'],
      ingredients: [
        _ingredient('chickpea', '1 su bardağı', '1 cup'),
        _ingredient('barley', '1/2 su bardağı', '1/2 cup'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('water', '5 su bardağı', '5 cups'),
      ],
      steps: [
        _step(
          'Soğanı zeytinyağında kavur, salçayı ekleyip karıştır.',
          'Cook the onion in olive oil, then stir in the tomato paste.',
          6,
        ),
        _step(
          'Nohut, arpa ve suyu ekleyip arpa yumuşayıncaya kadar pişir.',
          'Add the chickpeas, barley, and water and cook until the barley is tender.',
          18,
        ),
      ],
    ),
    _recipe(
      id: 'pancarli_yogurt_corbasi',
      nameTr: 'Pancarlı Yoğurt Çorbası',
      nameEn: 'Beet Yogurt Soup',
      imageEmoji: '🍠',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 18,
      servings: 4,
      tags: ['corba', 'pancar', 'yogurt'],
      ingredients: [
        _ingredient('beetroot', '2 adet', '2 pieces'),
        _ingredient('yogurt', '1 su bardağı', '1 cup'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('dill', '1 tutam', '1 pinch', optional: true),
        _ingredient('water', '4 su bardağı', '4 cups'),
      ],
      steps: [
        _step(
          'Pancarı küçük doğrayıp suyla yumuşayana kadar pişir.',
          'Dice the beetroot and simmer it in water until soft.',
          12,
        ),
        _step(
          'Yoğurt ve sarımsakla birlikte blenderdan geçir, dereotuyla servis et.',
          'Blend with yogurt and garlic, then serve with dill.',
          6,
        ),
      ],
    ),
    _recipe(
      id: 'balkabakli_zencefil_corbasi',
      nameTr: 'Balkabaklı Zencefil Çorbası',
      nameEn: 'Pumpkin Ginger Soup',
      imageEmoji: '🎃',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 20,
      servings: 4,
      tags: ['corba', 'balkabagi', 'zencefil'],
      ingredients: [
        _ingredient('pumpkin', '300 gram', '300 grams'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('ginger', '1 tatlı kaşığı', '1 teaspoon'),
        _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('cream', '1/2 su bardağı', '1/2 cup', optional: true),
        _ingredient('water', '4 su bardağı', '4 cups'),
      ],
      steps: [
        _step(
          'Soğan ve zencefili tereyağında çevirip balkabağını ekle.',
          'Cook the onion and ginger in butter, then add the pumpkin.',
          6,
        ),
        _step(
          'Suyu ekleyip yumuşat, blenderdan geçir ve istersen krema ile bitir.',
          'Add water, simmer until tender, blend, and finish with cream if desired.',
          14,
        ),
      ],
    ),
    _recipe(
      id: 'kerevizli_havuc_corbasi',
      nameTr: 'Kerevizli Havuç Çorbası',
      nameEn: 'Celery Carrot Soup',
      imageEmoji: '🥕',
      category: 'soup',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 18,
      servings: 4,
      tags: ['corba', 'kereviz', 'havuc'],
      ingredients: [
        _ingredient('celery', '1 küçük kök', '1 small root'),
        _ingredient('carrot', '2 adet', '2 pieces'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
        _ingredient('water', '4 su bardağı', '4 cups'),
      ],
      steps: [
        _step(
          'Sebzeleri zeytinyağında birkaç dakika çevir.',
          'Cook the vegetables in olive oil for a few minutes.',
          6,
        ),
        _step(
          'Suyu ekleyip yumuşayana kadar pişir, blenderdan geçir ve servis et.',
          'Add water, simmer until tender, blend smooth, and serve.',
          12,
        ),
      ],
    ),
    _recipe(
      id: 'humus',
      nameTr: 'Tahinli Humus',
      nameEn: 'Tahini Hummus',
      imageEmoji: '🫓',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 5,
      servings: 4,
      tags: ['meze', 'nohut', 'tahin'],
      ingredients: [
        _ingredient('chickpea', '2 su bardağı', '2 cups'),
        _ingredient('tahini', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('lemon', '1 adet', '1 piece'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('cumin', '1 çay kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Nohudu tahin, limon ve sarımsakla birlikte pürüzsüz olana kadar çek.',
          'Blend the chickpeas with tahini, lemon, and garlic until smooth.',
          4,
        ),
        _step(
          'Üzerine zeytinyağı ve kimyon gezdirip servis et.',
          'Finish with olive oil and cumin before serving.',
          1,
        ),
      ],
    ),
    _recipe(
      id: 'haydari',
      nameTr: 'Haydari',
      nameEn: 'Herbed Yogurt Dip',
      imageEmoji: '🥣',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 0,
      servings: 4,
      tags: ['meze', 'yogurt', 'dereotu'],
      ingredients: [
        _ingredient('yogurt', '1,5 su bardağı', '1.5 cups'),
        _ingredient('labneh', '3 yemek kaşığı', '3 tablespoons'),
        _ingredient('dill', '1 avuç', '1 handful'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('olive_oil', '1 tatlı kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Yoğurt, labne ve sarımsağı karıştır.',
          'Mix the yogurt, labneh, and garlic together.',
          4,
        ),
        _step(
          'Dereotunu ekleyip zeytinyağı ile soğuk servis et.',
          'Fold in the dill and serve chilled with a drizzle of olive oil.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'acili_ezme',
      nameTr: 'Acılı Ezme',
      nameEn: 'Spicy Tomato Pepper Ezme',
      imageEmoji: '🍅',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 12,
      cookTimeMinutes: 0,
      servings: 4,
      tags: ['meze', 'acili', 'domates'],
      ingredients: [
        _ingredient('tomato', '3 adet', '3 pieces'),
        _ingredient('onion', '1 küçük adet', '1 small piece'),
        _ingredient('pepper_green', '2 adet', '2 pieces'),
        _ingredient('parsley', '1/2 avuç', '1/2 handful'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('pomegranate_syrup', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('red_pepper_flakes', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Domates, soğan, biber ve maydanozu çok ince doğra.',
          'Finely chop the tomatoes, onion, peppers, and parsley.',
          8,
        ),
        _step(
          'Nar ekşisi, zeytinyağı ve pul biberle karıştırıp dinlendir.',
          'Mix with pomegranate molasses, olive oil, and pepper flakes, then let it rest.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'mercimek_koftesi',
      nameTr: 'Zeytinyağlı Mercimek Köftesi',
      nameEn: 'Olive Oil Red Lentil Patties',
      imageEmoji: '🧆',
      category: 'appetizer',
      difficulty: 'medium',
      prepTimeMinutes: 18,
      cookTimeMinutes: 20,
      servings: 6,
      tags: ['meze', 'mercimek', 'bulgur'],
      ingredients: [
        _ingredient('lentil_red', '1 su bardağı', '1 cup'),
        _ingredient('bulgur', '1 su bardağı', '1 cup'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('parsley', '1 avuç', '1 handful'),
        _ingredient('red_pepper_flakes', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Mercimeği haşla, bulguru içine ekleyip şişmeye bırak.',
          'Boil the lentils, then stir in the bulgur and let it absorb the liquid.',
          12,
        ),
        _step(
          'Soğanı salçayla kavurup karışıma ekle, maydanozla yoğurup şekil ver.',
          'Cook the onion with tomato paste, add it to the mixture, then knead with parsley and shape.',
          8,
        ),
      ],
    ),
    _recipe(
      id: 'labneli_pancar_dip',
      nameTr: 'Labneli Pancar Ezmesi',
      nameEn: 'Beet Labneh Dip',
      imageEmoji: '🫙',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 12,
      servings: 4,
      tags: ['meze', 'pancar', 'labne'],
      ingredients: [
        _ingredient('beetroot', '2 adet', '2 pieces'),
        _ingredient('labneh', '4 yemek kaşığı', '4 tablespoons'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('walnut', '2 yemek kaşığı', '2 tablespoons',
            optional: true),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
      ],
      steps: [
        _step(
          'Pancarı haşlayıp rendele ve sarımsakla karıştır.',
          'Boil and grate the beetroot, then mix it with garlic.',
          8,
        ),
        _step(
          'Labne ve ceviz ekleyip zeytinyağıyla servis et.',
          'Fold in the labneh and walnuts and serve with olive oil.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'mantar_dolmasi',
      nameTr: 'Peynirli Mantar Dolması',
      nameEn: 'Stuffed Mushrooms',
      imageEmoji: '🍄',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 4,
      tags: ['meze', 'mantar', 'firin'],
      ingredients: [
        _ingredient('mushroom', '12 adet', '12 pieces'),
        _ingredient('cheese_white', '80 gram', '80 grams'),
        _ingredient('parsley', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Mantarların içini çıkarıp peynir ve maydanozlu harçla doldur.',
          'Remove the mushroom stems and fill the caps with the cheese and parsley mixture.',
          7,
        ),
        _step(
          'Üzerlerine zeytinyağı gezdirip fırında yumuşayana kadar pişir.',
          'Drizzle with olive oil and bake until the mushrooms are tender.',
          8,
        ),
      ],
    ),
    _recipe(
      id: 'avokadolu_fasulye_salsa',
      nameTr: 'Avokadolu Fasulye Salsası',
      nameEn: 'Avocado Bean Salsa',
      imageEmoji: '🥑',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 0,
      servings: 4,
      tags: ['meze', 'avokado', 'fasulye'],
      ingredients: [
        _ingredient('black_bean', '1 su bardağı', '1 cup'),
        _ingredient('avocado', '1 adet', '1 piece'),
        _ingredient('tomato', '1 adet', '1 piece'),
        _ingredient('red_pepper', '1 adet', '1 piece'),
        _ingredient('lemon', '1 adet', '1 piece'),
        _ingredient('coriander', '1 çay kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Fasulye, küp doğranmış avokado, domates ve biberi karıştır.',
          'Combine the beans with diced avocado, tomato, and pepper.',
          6,
        ),
        _step(
          'Limon suyu ve kişnişle tatlandırıp soğuk servis et.',
          'Season with lemon juice and coriander and serve chilled.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'domatesli_bruschetta',
      nameTr: 'Domatesli Bruschetta',
      nameEn: 'Tomato Bruschetta',
      imageEmoji: '🍞',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 6,
      servings: 4,
      tags: ['meze', 'ekmek', 'domates'],
      ingredients: [
        _ingredient('bread', '6 dilim', '6 slices'),
        _ingredient('tomato', '2 adet', '2 pieces'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('basil_dried', '1 çay kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Ekmeği dilimleyip hafifçe kızart, sarımsakla ov.',
          'Toast the bread slices lightly and rub them with garlic.',
          4,
        ),
        _step(
          'Doğranmış domates, zeytinyağı ve fesleğeni üzerine paylaştır.',
          'Top with chopped tomato, olive oil, and basil.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'cevizli_kapya_mezesi',
      nameTr: 'Cevizli Kapya Mezesi',
      nameEn: 'Walnut Red Pepper Mezze',
      imageEmoji: '🌶️',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 12,
      servings: 4,
      tags: ['meze', 'kapya', 'ceviz'],
      ingredients: [
        _ingredient('capia_pepper', '2 adet', '2 pieces'),
        _ingredient('walnut', '1/2 su bardağı', '1/2 cup'),
        _ingredient('breadcrumbs', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('garlic', '1 diş', '1 clove'),
        _ingredient('pomegranate_syrup', '1 tatlı kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Kapya biberleri közleyip kabuklarını soy.',
          'Roast the capia peppers and peel off their skins.',
          8,
        ),
        _step(
          'Ceviz, sarımsak ve galeta unu ile çekip nar ekşisiyle tatlandır.',
          'Blend with walnuts, garlic, and breadcrumbs and season with pomegranate molasses.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'firin_mozzarella_mantar',
      nameTr: 'Fırın Mozzarella Mantarı',
      nameEn: 'Baked Mozzarella Mushrooms',
      imageEmoji: '🧀',
      category: 'appetizer',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 12,
      servings: 4,
      tags: ['meze', 'mantar', 'mozzarella'],
      ingredients: [
        _ingredient('mushroom', '200 gram', '200 grams'),
        _ingredient('mozzarella', '100 gram', '100 grams'),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('oregano', '1 çay kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Mantarları tepsiye alıp zeytinyağı ile karıştır.',
          'Place the mushrooms on a tray and toss with olive oil.',
          4,
        ),
        _step(
          'Mozzarella ve kekik ekleyip fırında peynir eriyene kadar pişir.',
          'Add mozzarella and oregano and bake until the cheese melts.',
          8,
        ),
      ],
    ),
    _recipe(
      id: 'gavurdagi_salatasi',
      nameTr: 'Cevizli Gavurdağı Salatası',
      nameEn: 'Walnut Gavurdagi Salad',
      imageEmoji: '🥗',
      category: 'salad',
      difficulty: 'easy',
      prepTimeMinutes: 12,
      cookTimeMinutes: 0,
      servings: 4,
      tags: ['salata', 'domates', 'ceviz'],
      ingredients: [
        _ingredient('tomato', '3 adet', '3 pieces'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('pepper_green', '2 adet', '2 pieces'),
        _ingredient('parsley', '1/2 avuç', '1/2 handful'),
        _ingredient('walnut', '1/2 su bardağı', '1/2 cup'),
        _ingredient('pomegranate_syrup', '2 yemek kaşığı', '2 tablespoons'),
      ],
      steps: [
        _step(
          'Tüm sebzeleri küçük küpler halinde doğra.',
          'Dice all the vegetables into small cubes.',
          8,
        ),
        _step(
          'Ceviz ve nar ekşisini ekleyip iyice karıştır.',
          'Add the walnuts and pomegranate molasses and toss well.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'piyaz',
      nameTr: 'Piyaz',
      nameEn: 'White Bean Salad',
      imageEmoji: '🫘',
      category: 'salad',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 0,
      servings: 4,
      tags: ['salata', 'fasulye', 'sogan'],
      ingredients: [
        _ingredient('white_bean', '2 su bardağı', '2 cups'),
        _ingredient('onion', '1 adet', '1 piece'),
        _ingredient('parsley', '1 avuç', '1 handful'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('vinegar', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('sumac', '1 çay kaşığı', '1 teaspoon', optional: true),
      ],
      steps: [
        _step(
          'Soğanı ince doğra ve fasulye ile bir kaba al.',
          'Thinly slice the onion and combine it with the beans.',
          4,
        ),
        _step(
          'Maydanoz, zeytinyağı, sirke ve sumak ekleyip karıştır.',
          'Add parsley, olive oil, vinegar, and sumac and toss to combine.',
          6,
        ),
      ],
    ),
    _recipe(
      id: 'roka_armut_salatasi',
      nameTr: 'Roka Armut Salatası',
      nameEn: 'Arugula Pear Salad',
      imageEmoji: '🍐',
      category: 'salad',
      difficulty: 'easy',
      prepTimeMinutes: 8,
      cookTimeMinutes: 0,
      servings: 2,
      tags: ['salata', 'roka', 'armut'],
      ingredients: [
        _ingredient('arugula', '1 büyük avuç', '1 large handful'),
        _ingredient('pear', '1 adet', '1 piece'),
        _ingredient('walnut', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('cheese_white', '60 gram', '60 grams', optional: true),
        _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
        _ingredient('balsamic_vinegar', '1 tatlı kaşığı', '1 teaspoon',
            optional: true),
      ],
      steps: [
        _step(
          'Rokayı yıka, armudu ince dilimle ve tabağa yerleştir.',
          'Wash the arugula, slice the pear thinly, and arrange them on a plate.',
          4,
        ),
        _step(
          'Ceviz, peynir ve sos malzemeleriyle tamamla.',
          'Finish with walnuts, cheese, and the dressing ingredients.',
          4,
        ),
      ],
    ),
    _recipe(
      id: 'koz_biberli_bulgur_salatasi',
      nameTr: 'Köz Biberli Bulgur Salatası',
      nameEn: 'Roasted Pepper Bulgur Salad',
      imageEmoji: '🥗',
      category: 'salad',
      difficulty: 'easy',
      prepTimeMinutes: 12,
      cookTimeMinutes: 15,
      servings: 4,
      tags: ['salata', 'bulgur', 'biber'],
      ingredients: [
        _ingredient('bulgur', '1 su bardağı', '1 cup'),
        _ingredient('capia_pepper', '2 adet', '2 pieces'),
        _ingredient('tomato', '1 adet', '1 piece'),
        _ingredient('scallion', '2 dal', '2 stalks'),
        _ingredient('parsley', '1/2 avuç', '1/2 handful'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('lemon', '1 adet', '1 piece'),
      ],
      steps: [
        _step(
          'Bulguru sıcak suda yumuşatıp süz, kapya biberleri közleyip doğra.',
          'Soften the bulgur in hot water, drain it, and chop the roasted peppers.',
          8,
        ),
        _step(
          'Domates, taze soğan ve maydanozu ekleyip limonlu zeytinyağıyla harmanla.',
          'Add the tomato, scallions, and parsley, then toss with lemon and olive oil.',
          7,
        ),
      ],
    ),
    _recipe(
      id: 'kinoali_avokado_salatasi',
      nameTr: 'Kinoalı Avokado Salatası',
      nameEn: 'Quinoa Avocado Salad',
      imageEmoji: '🥑',
      category: 'salad',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 3,
      tags: ['salata', 'kinoa', 'avokado'],
      ingredients: [
        _ingredient('quinoa', '1 su bardağı', '1 cup'),
        _ingredient('avocado', '1 adet', '1 piece'),
        _ingredient('cucumber', '1 adet', '1 piece'),
        _ingredient('tomato', '1 adet', '1 piece'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('lemon', '1 adet', '1 piece'),
      ],
      steps: [
        _step(
          'Kinoayı haşlayıp ılımaya bırak.',
          'Cook the quinoa and let it cool slightly.',
          10,
        ),
        _step(
          'Avokado, salatalık ve domatesle karıştırıp limonlu sosla tatlandır.',
          'Mix with avocado, cucumber, and tomato and dress with lemon.',
          5,
        ),
      ],
    ),
    _recipe(
      id: 'mercimekli_pancar_salatasi',
      nameTr: 'Mercimekli Pancar Salatası',
      nameEn: 'Lentil Beet Salad',
      imageEmoji: '🥗',
      category: 'salad',
      difficulty: 'easy',
      prepTimeMinutes: 10,
      cookTimeMinutes: 18,
      servings: 4,
      tags: ['salata', 'mercimek', 'pancar'],
      ingredients: [
        _ingredient('lentil_green', '1 su bardağı', '1 cup'),
        _ingredient('beetroot', '2 adet', '2 pieces'),
        _ingredient('parsley', '1/2 avuç', '1/2 handful'),
        _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
        _ingredient('lemon', '1 adet', '1 piece'),
      ],
      steps: [
        _step(
          'Mercimek ve pancarı ayrı ayrı haşla.',
          'Cook the lentils and beetroot separately until tender.',
          14,
        ),
        _step(
          'Doğrayıp maydanoz, zeytinyağı ve limonla harmanla.',
          'Chop and toss with parsley, olive oil, and lemon.',
          4,
        ),
      ],
    ),
    _recipe(
        id: 'portakalli_kirmizi_lahana',
        nameTr: 'Portakallı Kırmızı Lahana',
        nameEn: 'Red Cabbage Orange Salad',
        imageEmoji: '🍊',
        category: 'salad',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 0,
        servings: 4,
        tags: [
          'salata',
          'lahana',
          'portakal'
        ],
        ingredients: [
          _ingredient('red_cabbage', '2 su bardağı', '2 cups'),
          _ingredient('orange', '1 adet', '1 piece'),
          _ingredient('carrot', '1 adet', '1 piece'),
          _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('vinegar', '1 tatlı kaşığı', '1 teaspoon')
        ],
        steps: [
          _step(
              'Lahanayı ince kıy, havucu rendele ve portakalı dilimle.',
              'Shred the cabbage, grate the carrot, and segment the orange.',
              6),
          _step('Zeytinyağı ve sirke ile karıştırıp kısa süre dinlendir.',
              'Dress with olive oil and vinegar and let it rest briefly.', 4)
        ]),
    _recipe(
        id: 'ton_baligi_beyaz_fasulye_salata',
        nameTr: 'Ton Balıklı Beyaz Fasulye Salatası',
        nameEn: 'Tuna White Bean Salad',
        imageEmoji: '🐟',
        category: 'salad',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 0,
        servings: 3,
        tags: [
          'salata',
          'ton',
          'fasulye'
        ],
        ingredients: [
          _ingredient('tuna', '1 kutu', '1 can'),
          _ingredient('white_bean', '1,5 su bardağı', '1.5 cups'),
          _ingredient('onion', '1 küçük adet', '1 small piece'),
          _ingredient('parsley', '1/2 avuç', '1/2 handful'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('lemon', '1 adet', '1 piece')
        ],
        steps: [
          _step(
              'Fasulye, ton balığı ve ince doğranmış soğanı bir kapta birleştir.',
              'Combine the beans, tuna, and finely chopped onion in a bowl.',
              4),
          _step('Maydanoz ve limonlu zeytinyağı ile tamamla.',
              'Finish with parsley and a lemon-olive oil dressing.', 4)
        ]),
    _recipe(
        id: 'cilekli_ispanak_salatasi',
        nameTr: 'Çilekli Ispanak Salatası',
        nameEn: 'Strawberry Spinach Salad',
        imageEmoji: '🍓',
        category: 'salad',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 0,
        servings: 2,
        tags: [
          'salata',
          'cilek',
          'ispanak'
        ],
        ingredients: [
          _ingredient('spinach', '2 avuç', '2 handfuls'),
          _ingredient('strawberry', '8 adet', '8 pieces'),
          _ingredient('walnut', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('cheese_white', '50 gram', '50 grams', optional: true),
          _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('balsamic_vinegar', '1 tatlı kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step('Ispanağı yıkayıp çilekleri dilimle.',
              'Wash the spinach and slice the strawberries.', 4),
          _step('Ceviz, peynir ve sos malzemeleriyle harmanla.',
              'Toss with walnuts, cheese, and the dressing ingredients.', 4)
        ]),
    _recipe(
        id: 'brokolili_nohut_salatasi',
        nameTr: 'Brokolili Nohut Salatası',
        nameEn: 'Broccoli Chickpea Salad',
        imageEmoji: '🥦',
        category: 'salad',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 8,
        servings: 3,
        tags: [
          'salata',
          'brokoli',
          'nohut'
        ],
        ingredients: [
          _ingredient('broccoli', '1 küçük baş', '1 small head'),
          _ingredient('chickpea', '1 su bardağı', '1 cup'),
          _ingredient('red_pepper', '1 adet', '1 piece'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('lemon', '1 adet', '1 piece')
        ],
        steps: [
          _step('Brokoliyi kısa süre haşlayıp küçük parçalara ayır.',
              'Blanch the broccoli briefly and cut it into small florets.', 4),
          _step(
              'Nohut ve biberle karıştırıp limonlu zeytinyağı ile tatlandır.',
              'Combine with chickpeas and pepper and dress with lemon and olive oil.',
              4)
        ]),
    _recipe(
        id: 'kuskonmazli_patates_salatasi',
        nameTr: 'Kuşkonmazlı Patates Salatası',
        nameEn: 'Asparagus Potato Salad',
        imageEmoji: '🥔',
        category: 'salad',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 14,
        servings: 3,
        tags: [
          'salata',
          'kuskonmaz',
          'patates'
        ],
        ingredients: [
          _ingredient('potato', '3 adet', '3 pieces'),
          _ingredient('asparagus', '6 dal', '6 stalks'),
          _ingredient('dill', '1/2 avuç', '1/2 handful'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('mustard', '1 tatlı kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Patatesi haşla, kuşkonmazı kısa süre sıcak suda tut.',
              'Boil the potatoes and blanch the asparagus briefly.', 10),
          _step('Doğrayıp dereotu, zeytinyağı ve hardalla karıştır.',
              'Slice and toss with dill, olive oil, and mustard.', 4)
        ]),
    _recipe(
        id: 'tereyagli_sehriyeli_pilav',
        nameTr: 'Tereyağlı Şehriyeli Pilav',
        nameEn: 'Butter Vermicelli Rice',
        imageEmoji: '🍚',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 5,
        cookTimeMinutes: 18,
        servings: 4,
        tags: [
          'yan',
          'pilav',
          'sehriye'
        ],
        ingredients: [
          _ingredient('rice', '1,5 su bardağı', '1.5 cups'),
          _ingredient('vermicelli', '1/2 su bardağı', '1/2 cup'),
          _ingredient('butter', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('water', '3 su bardağı', '3 cups'),
          _ingredient('salt', '1 çay kaşığı', '1 teaspoon')
        ],
        steps: [
          _step('Tereyağında şehriyeyi renk alana kadar kavur.',
              'Toast the vermicelli in butter until golden.', 4),
          _step('Pirinç ve suyu ekleyip kapağı kapalı şekilde suyunu çektir.',
              'Add the rice and water and cook covered until absorbed.', 14)
        ]),
    _recipe(
        id: 'sarimsakli_patates_puresi',
        nameTr: 'Sarımsaklı Patates Püresi',
        nameEn: 'Garlic Mashed Potatoes',
        imageEmoji: '🥔',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 18,
        servings: 4,
        tags: [
          'yan',
          'patates',
          'sarimsak'
        ],
        ingredients: [
          _ingredient('potato', '4 adet', '4 pieces'),
          _ingredient('milk', '1/2 su bardağı', '1/2 cup'),
          _ingredient('butter', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('garlic', '2 diş', '2 cloves'),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step('Patates ve sarımsağı birlikte haşla.',
              'Boil the potatoes and garlic together until tender.', 14),
          _step('Süt ve tereyağı ile ezip pürüzsüz hale getir.',
              'Mash with milk and butter until smooth.', 4)
        ]),
    _recipe(
        id: 'firin_tatli_patates',
        nameTr: 'Fırın Tatlı Patates',
        nameEn: 'Roasted Sweet Potatoes',
        imageEmoji: '🍠',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 6,
        cookTimeMinutes: 22,
        servings: 4,
        tags: [
          'yan',
          'tatli-patates',
          'firin'
        ],
        ingredients: [
          _ingredient('sweet_potato', '3 adet', '3 pieces'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('paprika', '1 çay kaşığı', '1 teaspoon', optional: true),
          _ingredient('salt', '1 çay kaşığı', '1 teaspoon')
        ],
        steps: [
          _step(
              'Tatlı patatesleri kalın dilimleyip yağ ve baharatlarla karıştır.',
              'Slice the sweet potatoes thickly and coat them with oil and seasonings.',
              6),
          _step('Fırında dışı kızarıp içi yumuşayana kadar pişir.',
              'Roast until browned outside and tender inside.', 22)
        ]),
    _recipe(
        id: 'susamli_brokoli',
        nameTr: 'Susamlı Brokoli',
        nameEn: 'Sesame Broccoli',
        imageEmoji: '🥦',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 6,
        cookTimeMinutes: 10,
        servings: 3,
        tags: [
          'yan',
          'brokoli',
          'susam'
        ],
        ingredients: [
          _ingredient('broccoli', '1 küçük baş', '1 small head'),
          _ingredient('sesame_oil', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('sesame', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('soy_sauce', '1 tatlı kaşığı', '1 teaspoon',
              optional: true),
          _ingredient('garlic', '1 diş', '1 clove', optional: true)
        ],
        steps: [
          _step('Brokoliyi diri kalacak şekilde haşla veya buharda pişir.',
              'Steam or blanch the broccoli until just tender.', 5),
          _step(
              'Susam yağı, sarımsak ve susamla tavada kısa süre çevir.',
              'Toss briefly in a pan with sesame oil, garlic, and sesame seeds.',
              5)
        ]),
    _recipe(
        id: 'balsamik_havuc',
        nameTr: 'Balzamik Havuç',
        nameEn: 'Balsamic Carrots',
        imageEmoji: '🥕',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 6,
        cookTimeMinutes: 14,
        servings: 4,
        tags: [
          'yan',
          'havuc',
          'balzamik'
        ],
        ingredients: [
          _ingredient('carrot', '4 adet', '4 pieces'),
          _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('balsamic_vinegar', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Havuçları uzun parçalar halinde kesip yağla karıştır.',
              'Cut the carrots into long pieces and coat them with oil.', 4),
          _step('Tavada veya fırında pişirip balzamik ve balla parlat.',
              'Cook in a pan or oven and glaze with balsamic and honey.', 10)
        ]),
    _recipe(
        id: 'dereotlu_kuskus',
        nameTr: 'Dereotlu Kuskus',
        nameEn: 'Dill Couscous',
        imageEmoji: '🍚',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 5,
        cookTimeMinutes: 8,
        servings: 4,
        tags: [
          'yan',
          'kuskus',
          'dereotu'
        ],
        ingredients: [
          _ingredient('couscous', '1 su bardağı', '1 cup'),
          _ingredient('water', '1 su bardağı', '1 cup'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('dill', '1/2 avuç', '1/2 handful'),
          _ingredient('lemon', '1/2 adet', '1/2 piece', optional: true)
        ],
        steps: [
          _step('Kuskusu sıcak su ve tereyağı ile şişmeye bırak.',
              'Let the couscous absorb the hot water and butter.', 5),
          _step('Dereotu ve limonla havalandırıp servis et.',
              'Fluff with dill and lemon before serving.', 3)
        ]),
    _recipe(
        id: 'firin_bruksel_lahanasi',
        nameTr: 'Fırın Brüksel Lahanası',
        nameEn: 'Roasted Brussels Sprouts',
        imageEmoji: '🥬',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 6,
        cookTimeMinutes: 18,
        servings: 4,
        tags: [
          'yan',
          'bruksel',
          'firin'
        ],
        ingredients: [
          _ingredient('brussels_sprouts', '300 gram', '300 grams'),
          _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('garlic_powder', '1 çay kaşığı', '1 teaspoon',
              optional: true),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step(
              'Brüksel lahanalarını ikiye bölüp yağ ve baharatlarla kapla.',
              'Halve the Brussels sprouts and coat them with oil and seasonings.',
              4),
          _step('Fırında kenarları kızarana kadar pişir.',
              'Roast until the edges are nicely browned.', 14)
        ]),
    _recipe(
        id: 'kremali_karnabahar_graten',
        nameTr: 'Kremalı Karnabahar Graten',
        nameEn: 'Creamy Cauliflower Gratin',
        imageEmoji: '🧀',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        servings: 4,
        tags: [
          'yan',
          'karnabahar',
          'firin'
        ],
        ingredients: [
          _ingredient('cauliflower', '1 küçük baş', '1 small head'),
          _ingredient('cream', '1/2 su bardağı', '1/2 cup'),
          _ingredient('cheese_kashar', '80 gram', '80 grams'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step('Karnabaharı kısa süre haşlayıp fırın kabına al.',
              'Parboil the cauliflower and transfer it to a baking dish.', 8),
          _step('Krema ve kaşar ekleyip üstü kızarana kadar pişir.',
              'Add the cream and cheese and bake until golden on top.', 12)
        ]),
    _recipe(
        id: 'arpacik_soganli_bezelye',
        nameTr: 'Arpacık Soğanlı Bezelye',
        nameEn: 'Peas with Shallots',
        imageEmoji: '🫛',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 6,
        cookTimeMinutes: 12,
        servings: 4,
        tags: [
          'yan',
          'bezelye',
          'sogan'
        ],
        ingredients: [
          _ingredient('peas', '2 su bardağı', '2 cups'),
          _ingredient('shallot', '6 adet', '6 pieces'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('dill', '1 yemek kaşığı', '1 tablespoon', optional: true)
        ],
        steps: [
          _step('Arpacık soğanları tereyağında yumuşayana kadar çevir.',
              'Cook the shallots in butter until softened.', 5),
          _step(
              'Bezelyeleri ekleyip diri kalacak şekilde pişir, dereotu ile bitir.',
              'Add the peas and cook until just tender, then finish with dill.',
              7)
        ]),
    _recipe(
        id: 'zerdecalli_pirinc',
        nameTr: 'Zerdeçallı Pirinç',
        nameEn: 'Turmeric Rice',
        imageEmoji: '🍚',
        category: 'side',
        difficulty: 'easy',
        prepTimeMinutes: 5,
        cookTimeMinutes: 16,
        servings: 4,
        tags: [
          'yan',
          'pirinc',
          'zerdecal'
        ],
        ingredients: [
          _ingredient('rice', '1,5 su bardağı', '1.5 cups'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('turmeric', '1 çay kaşığı', '1 teaspoon'),
          _ingredient('water', '3 su bardağı', '3 cups'),
          _ingredient('salt', '1 çay kaşığı', '1 teaspoon')
        ],
        steps: [
          _step('Pirinci tereyağı ve zerdeçal ile birkaç dakika kavur.',
              'Toast the rice in butter with turmeric for a few minutes.', 4),
          _step(
              'Suyu ekleyip tane tane kalacak şekilde pişir.',
              'Add the water and cook until the grains are fluffy and separate.',
              12)
        ]),
    _recipe(
        id: 'imam_bayildi',
        nameTr: 'Zeytinyağlı İmam Bayıldı',
        nameEn: 'Olive Oil Imam Bayildi',
        imageEmoji: '🍆',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 15,
        cookTimeMinutes: 35,
        servings: 4,
        tags: [
          'aksam',
          'patlican',
          'zeytinyagli'
        ],
        ingredients: [
          _ingredient('eggplant', '3 adet', '3 pieces'),
          _ingredient('onion', '2 adet', '2 pieces'),
          _ingredient('garlic', '4 diş', '4 cloves'),
          _ingredient('tomato', '2 adet', '2 pieces'),
          _ingredient('olive_oil', '4 yemek kaşığı', '4 tablespoons')
        ],
        steps: [
          _step(
              'Patlıcanları yarıp hafifçe kızart veya fırınla.',
              'Split the eggplants and roast them until slightly softened.',
              12),
          _step(
              'Soğanlı domatesli harçla doldurup zeytinyağı ile pişir.',
              'Fill with the onion and tomato mixture and cook with olive oil until tender.',
              23)
        ]),
    _recipe(
        id: 'alinazik',
        nameTr: 'Alinazik',
        nameEn: 'Ali Nazik',
        imageEmoji: '🥘',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 18,
        cookTimeMinutes: 24,
        servings: 4,
        tags: [
          'aksam',
          'patlican',
          'kiyma'
        ],
        ingredients: [
          _ingredient('ground_beef', '300 gram', '300 grams'),
          _ingredient('eggplant', '2 adet', '2 pieces'),
          _ingredient('yogurt', '1 su bardağı', '1 cup'),
          _ingredient('garlic', '2 diş', '2 cloves'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon')
        ],
        steps: [
          _step('Patlıcanları közleyip yoğurt ve sarımsakla ez.',
              'Roast the eggplants and mash them with yogurt and garlic.', 10),
          _step(
              'Kıymayı tereyağında kavurup patlıcanlı tabanın üzerine yerleştir.',
              'Brown the ground beef in butter and spoon it over the eggplant base.',
              14)
        ]),
    _recipe(
        id: 'kilis_tava',
        nameTr: 'Kilis Tava',
        nameEn: 'Kilis Tray Kebab',
        imageEmoji: '🍖',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 12,
        cookTimeMinutes: 20,
        servings: 4,
        tags: [
          'aksam',
          'kiyma',
          'firin'
        ],
        ingredients: [
          _ingredient('ground_beef', '400 gram', '400 grams'),
          _ingredient('capia_pepper', '1 adet', '1 piece'),
          _ingredient('tomato', '2 adet', '2 pieces'),
          _ingredient('garlic', '2 diş', '2 cloves'),
          _ingredient('red_pepper_flakes', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step(
              'Kıymayı biber, sarımsak ve baharatlarla yoğurup tepsiye yayın.',
              'Mix the ground beef with pepper, garlic, and seasonings and spread on a tray.',
              8),
          _step('Üzerine domates dizip fırında kızarıncaya kadar pişir.',
              'Top with tomato slices and bake until browned.', 12)
        ]),
    _recipe(
        id: 'iskender_tavuk',
        nameTr: 'İskender Tavuk',
        nameEn: 'Chicken Iskender',
        imageEmoji: '🍗',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 12,
        cookTimeMinutes: 18,
        servings: 3,
        tags: [
          'aksam',
          'tavuk',
          'yogurt'
        ],
        ingredients: [
          _ingredient('chicken_breast', '400 gram', '400 grams'),
          _ingredient('yogurt', '1 su bardağı', '1 cup'),
          _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('pita', '2 adet', '2 pieces')
        ],
        steps: [
          _step('Tavuğu şerit doğrayıp tavada pişir, pideleri küp kesip ısıt.',
              'Cook the sliced chicken in a pan and warm the cubed pita.', 10),
          _step(
              'Pidelerin üzerine yoğurt, tavuk ve salçalı tereyağı gezdir.',
              'Layer yogurt, chicken, and tomato-butter sauce over the pita.',
              8)
        ]),
    _recipe(
        id: 'pideli_kofte',
        nameTr: 'Pideli Köfte',
        nameEn: 'Meatballs over Pita',
        imageEmoji: '🍽️',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        servings: 4,
        tags: [
          'aksam',
          'kofte',
          'pide'
        ],
        ingredients: [
          _ingredient('meatball', '400 gram', '400 grams'),
          _ingredient('pita', '2 adet', '2 pieces'),
          _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('yogurt', '1 su bardağı', '1 cup')
        ],
        steps: [
          _step(
              'Köfteleri tavada kızart, pideleri küçük parçalar halinde ısıt.',
              'Brown the meatballs in a skillet and warm the pita pieces.',
              10),
          _step(
              'Pidelerin üzerine yoğurt, köfte ve salçalı tereyağı ekle.',
              'Top the pita with yogurt, meatballs, and tomato-butter sauce.',
              10)
        ]),
    _recipe(
        id: 'kayseri_yaglamasi',
        nameTr: 'Kayseri Yağlaması',
        nameEn: 'Kayseri Layered Flatbread',
        imageEmoji: '🥙',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 18,
        cookTimeMinutes: 22,
        servings: 4,
        tags: [
          'aksam',
          'kiyma',
          'katmanli'
        ],
        ingredients: [
          _ingredient('tortilla', '4 adet', '4 pieces'),
          _ingredient('ground_beef', '300 gram', '300 grams'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('tomato', '2 adet', '2 pieces'),
          _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('yogurt', '1 su bardağı', '1 cup')
        ],
        steps: [
          _step(
              'Kıymayı soğan, domates ve salça ile sulu bir harç haline getir.',
              'Cook the ground beef with onion, tomato, and paste into a saucy filling.',
              12),
          _step('Tortillaları kat kat harçla dizip üzerine yoğurtla servis et.',
              'Layer the tortillas with the filling and serve with yogurt.', 10)
        ]),
    _recipe(
        id: 'etli_nohut',
        nameTr: 'Etli Nohut',
        nameEn: 'Chickpeas with Beef',
        imageEmoji: '🍲',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 35,
        servings: 4,
        tags: [
          'aksam',
          'nohut',
          'et'
        ],
        ingredients: [
          _ingredient('beef_cubes', '350 gram', '350 grams'),
          _ingredient('chickpea', '2 su bardağı', '2 cups'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('water', '4 su bardağı', '4 cups')
        ],
        steps: [
          _step('Eti soğanla mühürleyip salça ekle.',
              'Sear the beef with onion and stir in the tomato paste.', 10),
          _step(
              'Nohut ve suyu ekleyip et yumuşayana kadar pişir.',
              'Add the chickpeas and water and cook until the beef is tender.',
              25)
        ]),
    _recipe(
        id: 'zeytinyagli_enginar',
        nameTr: 'Zeytinyağlı Enginar',
        nameEn: 'Braised Artichokes',
        imageEmoji: '🌿',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 12,
        cookTimeMinutes: 22,
        servings: 4,
        tags: [
          'aksam',
          'enginar',
          'hafif'
        ],
        ingredients: [
          _ingredient('artichoke', '4 adet', '4 pieces'),
          _ingredient('peas', '1 su bardağı', '1 cup'),
          _ingredient('carrot', '1 adet', '1 piece'),
          _ingredient('olive_oil', '3 yemek kaşığı', '3 tablespoons'),
          _ingredient('lemon', '1 adet', '1 piece')
        ],
        steps: [
          _step('Enginarları tencereye dizip bezelye ve havucu ekle.',
              'Arrange the artichokes in a pot and add peas and carrot.', 8),
          _step(
              'Zeytinyağı, limon ve az su ile yumuşayana kadar pişir.',
              'Cook with olive oil, lemon, and a little water until tender.',
              14)
        ]),
    _recipe(
        id: 'bamya_yemegi',
        nameTr: 'Bamya Yemeği',
        nameEn: 'Okra Stew',
        imageEmoji: '🍲',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 24,
        servings: 4,
        tags: [
          'aksam',
          'bamya',
          'tencere'
        ],
        ingredients: [
          _ingredient('okra', '400 gram', '400 grams'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('tomato', '2 adet', '2 pieces'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('lemon', '1/2 adet', '1/2 piece')
        ],
        steps: [
          _step('Soğanı zeytinyağında yumuşatıp domatesi ekle.',
              'Soften the onion in olive oil and add the tomatoes.', 8),
          _step('Bamyayı ve limon suyunu ekleyip kısık ateşte pişir.',
              'Add the okra and lemon juice and simmer gently.', 16)
        ]),
    _recipe(
        id: 'taze_fasulye_tenceresi',
        nameTr: 'Taze Fasulye Tenceresi',
        nameEn: 'Green Bean Pot',
        imageEmoji: '🫛',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 26,
        servings: 4,
        tags: [
          'aksam',
          'fasulye',
          'zeytinyagli'
        ],
        ingredients: [
          _ingredient('green_beans', '500 gram', '500 grams'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('tomato', '2 adet', '2 pieces'),
          _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons')
        ],
        steps: [
          _step(
              'Soğanı ve salçayı zeytinyağında çevir, domatesi ekle.',
              'Cook the onion and tomato paste in olive oil, then add the tomatoes.',
              8),
          _step('Fasulyeleri ekleyip kendi suyuyla yumuşayana kadar pişir.',
              'Add the beans and cook until tender in their own juices.', 18)
        ]),
    _recipe(
        id: 'kofte_patates_tepsi',
        nameTr: 'Köfte Patates Tepsi',
        nameEn: 'Meatball Potato Tray Bake',
        imageEmoji: '🍖',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 30,
        servings: 4,
        tags: [
          'aksam',
          'kofte',
          'patates'
        ],
        ingredients: [
          _ingredient('meatball', '500 gram', '500 grams'),
          _ingredient('potato', '3 adet', '3 pieces'),
          _ingredient('tomato', '1 adet', '1 piece'),
          _ingredient('pepper_green', '2 adet', '2 pieces'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons')
        ],
        steps: [
          _step('Patatesleri dilimleyip köftelerle birlikte tepsiye diz.',
              'Arrange the sliced potatoes and meatballs on a tray.', 8),
          _step('Domates ve biber ekleyip fırında kızarıncaya kadar pişir.',
              'Add the tomato and peppers and bake until browned.', 22)
        ]),
    _recipe(
        id: 'tavuklu_arpa_sehriye',
        nameTr: 'Tavuklu Arpa Şehriye',
        nameEn: 'Chicken Orzo Skillet',
        imageEmoji: '🍗',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 18,
        servings: 3,
        tags: [
          'aksam',
          'tavuk',
          'sehriye'
        ],
        ingredients: [
          _ingredient('chicken_breast', '350 gram', '350 grams'),
          _ingredient('vermicelli', '1 su bardağı', '1 cup'),
          _ingredient('tomato', '1 adet', '1 piece'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('water', '2 su bardağı', '2 cups')
        ],
        steps: [
          _step('Tavuğu küp doğrayıp tereyağında mühürle.',
              'Sear the diced chicken in butter.', 6),
          _step(
              'Şehriye, domates ve suyu ekleyip birlikte pişir.',
              'Add the orzo, tomato, and water and cook everything together.',
              12)
        ]),
    _recipe(
        id: 'somonlu_kinoa_kasesi',
        nameTr: 'Somonlu Kinoa Kasesi',
        nameEn: 'Salmon Quinoa Bowl',
        imageEmoji: '🐟',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 18,
        servings: 2,
        tags: [
          'aksam',
          'somon',
          'kinoa'
        ],
        ingredients: [
          _ingredient('salmon', '2 fileto', '2 fillets'),
          _ingredient('quinoa', '1 su bardağı', '1 cup'),
          _ingredient('avocado', '1 adet', '1 piece', optional: true),
          _ingredient('cucumber', '1 adet', '1 piece'),
          _ingredient('lemon', '1 adet', '1 piece')
        ],
        steps: [
          _step('Kinoayı haşla ve kaselere paylaştır.',
              'Cook the quinoa and divide it between bowls.', 10),
          _step(
              'Somonu pişirip salatalık ve avokado ile birlikte üzerine yerleştir.',
              'Cook the salmon and place it on top with cucumber and avocado.',
              8)
        ]),
    _recipe(
        id: 'karidesli_soya_noodle',
        nameTr: 'Karidesli Soya Noodle',
        nameEn: 'Shrimp Soy Noodles',
        imageEmoji: '🍤',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 10,
        cookTimeMinutes: 12,
        servings: 3,
        tags: [
          'aksam',
          'karides',
          'noodle'
        ],
        ingredients: [
          _ingredient('rice_noodle', '1 paket', '1 pack'),
          _ingredient('shrimp', '300 gram', '300 grams'),
          _ingredient('soy_sauce', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('red_pepper', '1 adet', '1 piece'),
          _ingredient('garlic', '2 diş', '2 cloves'),
          _ingredient('sesame_oil', '1 yemek kaşığı', '1 tablespoon')
        ],
        steps: [
          _step('Noodleları hazırlayıp karidesi sarımsakla sotele.',
              'Prepare the noodles and sauté the shrimp with garlic.', 6),
          _step(
              'Biber, soya sosu ve susam yağı ile hepsini birlikte çevir.',
              'Toss everything together with pepper, soy sauce, and sesame oil.',
              6)
        ]),
    _recipe(
        id: 'tofulu_sebze_sote',
        nameTr: 'Tofulu Sebze Sote',
        nameEn: 'Tofu Vegetable Stir Fry',
        imageEmoji: '🥢',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 12,
        servings: 3,
        tags: [
          'aksam',
          'tofu',
          'sebze'
        ],
        ingredients: [
          _ingredient('tofu', '300 gram', '300 grams'),
          _ingredient('broccoli', '1 küçük baş', '1 small head'),
          _ingredient('carrot', '1 adet', '1 piece'),
          _ingredient('soy_sauce', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('sesame_oil', '1 yemek kaşığı', '1 tablespoon')
        ],
        steps: [
          _step('Tofuyu küp küp kesip tavada renk alana kadar pişir.',
              'Cube the tofu and cook it in a pan until golden.', 5),
          _step(
              'Sebzeleri ve sos malzemelerini ekleyip diri kalacak şekilde sotele.',
              'Add the vegetables and sauce ingredients and stir-fry until just tender.',
              7)
        ]),
    _recipe(
        id: 'mantarli_arpa_pilavi',
        nameTr: 'Mantarlı Arpa Pilavı',
        nameEn: 'Mushroom Barley Pilaf',
        imageEmoji: '🍄',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 20,
        servings: 3,
        tags: [
          'aksam',
          'mantar',
          'arpa'
        ],
        ingredients: [
          _ingredient('barley', '1 su bardağı', '1 cup'),
          _ingredient('mushroom', '200 gram', '200 grams'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('water', '2,5 su bardağı', '2.5 cups')
        ],
        steps: [
          _step('Soğan ve mantarı tereyağında sotele.',
              'Sauté the onion and mushrooms in butter.', 6),
          _step('Arpa ve suyu ekleyip tane tane pişir.',
              'Add the barley and water and cook until fluffy.', 14)
        ]),
    _recipe(
        id: 'kuzu_rezeneli_tava',
        nameTr: 'Kuzu Rezeneli Tava',
        nameEn: 'Lamb and Fennel Skillet',
        imageEmoji: '🍖',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 12,
        cookTimeMinutes: 18,
        servings: 3,
        tags: [
          'aksam',
          'kuzu',
          'rezene'
        ],
        ingredients: [
          _ingredient('lamb', '350 gram', '350 grams'),
          _ingredient('fennel', '1 adet', '1 piece'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step('Kuzu etini yüksek ateşte mühürle.',
              'Sear the lamb over high heat.', 6),
          _step('Rezene ve soğanı ekleyip et yumuşayana kadar çevir.',
              'Add the fennel and onion and cook until the lamb is tender.', 12)
        ]),
    _recipe(
        id: 'tavuklu_kuskonmaz_makarna',
        nameTr: 'Tavuklu Kuşkonmaz Makarna',
        nameEn: 'Chicken Asparagus Pasta',
        imageEmoji: '🍝',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 18,
        servings: 3,
        tags: [
          'aksam',
          'tavuk',
          'makarna'
        ],
        ingredients: [
          _ingredient('pasta', '1 paket', '1 pack'),
          _ingredient('chicken_breast', '300 gram', '300 grams'),
          _ingredient('asparagus', '6 dal', '6 stalks'),
          _ingredient('cream', '1/2 su bardağı', '1/2 cup'),
          _ingredient('parmesan', '2 yemek kaşığı', '2 tablespoons',
              optional: true)
        ],
        steps: [
          _step(
              'Makarnayı haşla, tavuğu ve kuşkonmazı tavada pişir.',
              'Boil the pasta and cook the chicken and asparagus in a pan.',
              10),
          _step('Krema ile birleştirip parmesanla servis et.',
              'Combine with cream and serve with parmesan.', 8)
        ]),
    _recipe(
        id: 'ton_balikli_patates_firin',
        nameTr: 'Ton Balıklı Patates Fırın',
        nameEn: 'Tuna Potato Bake',
        imageEmoji: '🥔',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 24,
        servings: 4,
        tags: [
          'aksam',
          'ton',
          'firin'
        ],
        ingredients: [
          _ingredient('potato', '4 adet', '4 pieces'),
          _ingredient('tuna', '1 kutu', '1 can'),
          _ingredient('cream', '1/2 su bardağı', '1/2 cup'),
          _ingredient('cheese_kashar', '80 gram', '80 grams'),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step(
              'Patatesleri ince dilimleyip fırın kabına diz.',
              'Slice the potatoes thinly and arrange them in a baking dish.',
              8),
          _step('Ton balığı, krema ve kaşarı ekleyip fırında pişir.',
              'Add the tuna, cream, and cheese and bake until tender.', 16)
        ]),
    _recipe(
        id: 'nohutlu_ispanak_yemegi',
        nameTr: 'Nohutlu Ispanak Yemeği',
        nameEn: 'Spinach Chickpea Stew',
        imageEmoji: '🥬',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 18,
        servings: 4,
        tags: [
          'aksam',
          'ispanak',
          'nohut'
        ],
        ingredients: [
          _ingredient('spinach', '300 gram', '300 grams'),
          _ingredient('chickpea', '1,5 su bardağı', '1.5 cups'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('tomato_paste', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons')
        ],
        steps: [
          _step('Soğanı ve salçayı zeytinyağında kavur.',
              'Cook the onion and tomato paste in olive oil.', 6),
          _step(
              'Nohut ve ıspanağı ekleyip kısa sürede toparlanana kadar pişir.',
              'Add the chickpeas and spinach and cook until just wilted and combined.',
              12)
        ]),
    _recipe(
        id: 'kapya_biber_dolmasi',
        nameTr: 'Kapya Biber Dolması',
        nameEn: 'Stuffed Capia Peppers',
        imageEmoji: '🌶️',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 15,
        cookTimeMinutes: 28,
        servings: 4,
        tags: [
          'aksam',
          'dolma',
          'biber'
        ],
        ingredients: [
          _ingredient('capia_pepper', '4 adet', '4 pieces'),
          _ingredient('rice', '1 su bardağı', '1 cup'),
          _ingredient('ground_beef', '200 gram', '200 grams'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('tomato', '1 adet', '1 piece'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons')
        ],
        steps: [
          _step(
              'Pirinci kıyma ve soğanla karıştırıp biberlerin içine doldur.',
              'Mix the rice with ground beef and onion and fill the peppers.',
              10),
          _step('Tencerede veya fırında yumuşayana kadar pişir.',
              'Cook in a pot or oven until the peppers are tender.', 18)
        ]),
    _recipe(
        id: 'sebzeli_kuskus_tava',
        nameTr: 'Sebzeli Kuskus Tava',
        nameEn: 'Vegetable Couscous Skillet',
        imageEmoji: '🍲',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 14,
        servings: 3,
        tags: [
          'aksam',
          'kuskus',
          'sebze'
        ],
        ingredients: [
          _ingredient('couscous', '1 su bardağı', '1 cup'),
          _ingredient('zucchini', '1 adet', '1 piece'),
          _ingredient('red_pepper', '1 adet', '1 piece'),
          _ingredient('carrot', '1 adet', '1 piece'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons')
        ],
        steps: [
          _step('Sebzeleri küçük doğrayıp tavada sotele.',
              'Dice the vegetables and sauté them in a skillet.', 8),
          _step(
              'Kuskusu sıcak suyla şişirip sebzelerle birleştir.',
              'Fluff the couscous with hot water and combine it with the vegetables.',
              6)
        ]),
    _recipe(
        id: 'biftekli_mantar_sote',
        nameTr: 'Biftekli Mantarlı Sote',
        nameEn: 'Steak Mushroom Saute',
        imageEmoji: '🥩',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 10,
        cookTimeMinutes: 14,
        servings: 3,
        tags: [
          'aksam',
          'biftek',
          'mantar'
        ],
        ingredients: [
          _ingredient('steak', '350 gram', '350 grams'),
          _ingredient('mushroom', '200 gram', '200 grams'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('garlic', '2 diş', '2 cloves'),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step('Bifteği şerit doğrayıp yüksek ateşte renk aldır.',
              'Slice the steak and sear it over high heat.', 6),
          _step('Mantar ve sarımsağı ekleyip kısa sürede sotele.',
              'Add the mushrooms and garlic and sauté briefly.', 8)
        ]),
    _recipe(
        id: 'hindi_quinoa_tava',
        nameTr: 'Hindi Kinoa Tava',
        nameEn: 'Turkey Quinoa Skillet',
        imageEmoji: '🍗',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 16,
        servings: 3,
        tags: [
          'aksam',
          'hindi',
          'kinoa'
        ],
        ingredients: [
          _ingredient('turkey', '350 gram', '350 grams'),
          _ingredient('quinoa', '1 su bardağı', '1 cup'),
          _ingredient('red_pepper', '1 adet', '1 piece'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('thyme', '1 çay kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Hindi etini tavada sotele, biberi ekle.',
              'Sauté the turkey in a skillet and add the pepper.', 8),
          _step('Haşlanmış kinoa ile birleştirip taze kekikle tamamla.',
              'Combine with cooked quinoa and finish with thyme.', 8)
        ]),
    _recipe(
        id: 'somon_dereotlu_firin',
        nameTr: 'Somon Dereotlu Fırın',
        nameEn: 'Baked Salmon with Dill',
        imageEmoji: '🐟',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 18,
        servings: 2,
        tags: [
          'aksam',
          'somon',
          'dereotu'
        ],
        ingredients: [
          _ingredient('salmon', '2 fileto', '2 fillets'),
          _ingredient('dill', '1 avuç', '1 handful'),
          _ingredient('lemon', '1 adet', '1 piece'),
          _ingredient('olive_oil', '1 yemek kaşığı', '1 tablespoon')
        ],
        steps: [
          _step('Somonu limon ve zeytinyağı ile fırın kabına al.',
              'Place the salmon in a baking dish with lemon and olive oil.', 4),
          _step('Dereotu ekleyip fırında nazikçe pişir.',
              'Add dill and bake gently until cooked through.', 14)
        ]),
    _recipe(
        id: 'kalamarli_domatesli_makarna',
        nameTr: 'Kalamarlı Domatesli Makarna',
        nameEn: 'Calamari Tomato Pasta',
        imageEmoji: '🦑',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 10,
        cookTimeMinutes: 15,
        servings: 3,
        tags: [
          'aksam',
          'kalamar',
          'makarna'
        ],
        ingredients: [
          _ingredient('spaghetti', '1 paket', '1 pack'),
          _ingredient('calamari', '250 gram', '250 grams'),
          _ingredient('tomato', '2 adet', '2 pieces'),
          _ingredient('garlic', '2 diş', '2 cloves'),
          _ingredient('olive_oil', '2 yemek kaşığı', '2 tablespoons')
        ],
        steps: [
          _step('Makarnayı haşla, kalamarı sarımsakla kısa süre çevir.',
              'Boil the pasta and briefly sauté the calamari with garlic.', 7),
          _step('Domates sosu ekleyip makarnayla birleştir.',
              'Add the tomato sauce and combine with the pasta.', 8)
        ]),
    _recipe(
        id: 'midyeli_pilav',
        nameTr: 'Midyeli Pilav',
        nameEn: 'Mussel Rice Pilaf',
        imageEmoji: '🦪',
        category: 'main',
        difficulty: 'medium',
        prepTimeMinutes: 12,
        cookTimeMinutes: 22,
        servings: 4,
        tags: [
          'aksam',
          'midye',
          'pilav'
        ],
        ingredients: [
          _ingredient('mussel', '300 gram', '300 grams'),
          _ingredient('rice', '1,5 su bardağı', '1.5 cups'),
          _ingredient('onion', '1 adet', '1 piece'),
          _ingredient('butter', '1 yemek kaşığı', '1 tablespoon'),
          _ingredient('cinnamon', '1 çay kaşığı', '1 teaspoon', optional: true),
          _ingredient('water', '3 su bardağı', '3 cups')
        ],
        steps: [
          _step('Soğanı tereyağında çevirip pirinci kavur.',
              'Cook the onion in butter and toast the rice.', 8),
          _step(
              'Midye ve suyu ekleyip tarçınla birlikte pişir.',
              'Add the mussels and water and cook with a touch of cinnamon.',
              14)
        ]),
    _recipe(
        id: 'mercimekli_kabak_graten',
        nameTr: 'Mercimekli Kabak Graten',
        nameEn: 'Zucchini Lentil Gratin',
        imageEmoji: '🥘',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 12,
        cookTimeMinutes: 20,
        servings: 4,
        tags: [
          'aksam',
          'kabak',
          'mercimek'
        ],
        ingredients: [
          _ingredient('zucchini', '2 adet', '2 pieces'),
          _ingredient('lentil_green', '1 su bardağı', '1 cup'),
          _ingredient('cream', '1/2 su bardağı', '1/2 cup'),
          _ingredient('cheese_kashar', '80 gram', '80 grams'),
          _ingredient('black_pepper', '1 çay kaşığı', '1 teaspoon',
              optional: true)
        ],
        steps: [
          _step(
              'Kabağı dilimleyip haşlanmış mercimekle fırın kabına yerleştir.',
              'Layer the sliced zucchini with cooked lentils in a baking dish.',
              8),
          _step('Krema ve kaşar ekleyip üstü kızarana kadar pişir.',
              'Add cream and cheese and bake until golden.', 12)
        ]),
    _recipe(
        id: 'pestolu_tavuk_makarna',
        nameTr: 'Pestolu Tavuk Makarna',
        nameEn: 'Pesto Chicken Pasta',
        imageEmoji: '🍝',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 16,
        servings: 3,
        tags: [
          'aksam',
          'pesto',
          'tavuk'
        ],
        ingredients: [
          _ingredient('pasta', '1 paket', '1 pack'),
          _ingredient('chicken_breast', '300 gram', '300 grams'),
          _ingredient('pesto', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('cream', '1/2 su bardağı', '1/2 cup'),
          _ingredient('parmesan', '2 yemek kaşığı', '2 tablespoons',
              optional: true)
        ],
        steps: [
          _step('Makarnayı haşla ve tavuğu tavada pişir.',
              'Boil the pasta and cook the chicken in a skillet.', 10),
          _step('Pesto ve krema ile birleştirip parmesanla servis et.',
              'Combine with pesto and cream and serve with parmesan.', 6)
        ]),
    _recipe(
        id: 'siyah_fasulyeli_tortilla',
        nameTr: 'Siyah Fasulyeli Tortilla',
        nameEn: 'Black Bean Tortilla Skillet',
        imageEmoji: '🌮',
        category: 'main',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 12,
        servings: 3,
        tags: [
          'aksam',
          'fasulye',
          'tortilla'
        ],
        ingredients: [
          _ingredient('tortilla', '3 adet', '3 pieces'),
          _ingredient('black_bean', '1,5 su bardağı', '1.5 cups'),
          _ingredient('cheddar', '100 gram', '100 grams'),
          _ingredient('tomato', '1 adet', '1 piece'),
          _ingredient('jalapeno', '1 adet', '1 piece', optional: true)
        ],
        steps: [
          _step('Fasulye ve domatesi kısa süre tavada çevir.',
              'Warm the beans and tomato briefly in a skillet.', 5),
          _step(
              'Tortilla ve cheddar ile katlayıp peynir eriyene kadar pişir.',
              'Fold into tortillas with cheddar and cook until the cheese melts.',
              7)
        ]),
    _recipe(
        id: 'naneli_ayran',
        nameTr: 'Naneli Ayran',
        nameEn: 'Mint Ayran',
        imageEmoji: '🥛',
        category: 'beverage',
        difficulty: 'easy',
        prepTimeMinutes: 4,
        cookTimeMinutes: 0,
        servings: 2,
        tags: [
          'icecek',
          'ayran',
          'nane'
        ],
        ingredients: [
          _ingredient('yogurt', '1 su bardağı', '1 cup'),
          _ingredient('water', '1 su bardağı', '1 cup'),
          _ingredient('mint_dried', '1 çay kaşığı', '1 teaspoon',
              optional: true),
          _ingredient('salt', '1 tutam', '1 pinch')
        ],
        steps: [
          _step('Yoğurt, su ve tuzu pürüzsüz olana kadar çırp.',
              'Whisk the yogurt, water, and salt until smooth.', 3),
          _step('Naneyi ekleyip soğuk servis et.',
              'Add the mint and serve chilled.', 1)
        ]),
    _recipe(
        id: 'cilekli_kefir',
        nameTr: 'Çilekli Kefir',
        nameEn: 'Strawberry Kefir Drink',
        imageEmoji: '🍓',
        category: 'beverage',
        difficulty: 'easy',
        prepTimeMinutes: 5,
        cookTimeMinutes: 0,
        servings: 2,
        tags: [
          'icecek',
          'kefir',
          'cilek'
        ],
        ingredients: [
          _ingredient('kefir', '2 su bardağı', '2 cups'),
          _ingredient('strawberry', '8 adet', '8 pieces'),
          _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Kefir ve çileği blenderdan geçir.',
              'Blend the kefir and strawberries until smooth.', 4),
          _step('İstersen bal ekleyip soğuk servis et.',
              'Sweeten with honey if desired and serve cold.', 1)
        ]),
    _recipe(
        id: 'seftalili_buzlu_cay',
        nameTr: 'Şeftalili Buzlu Çay',
        nameEn: 'Peach Iced Tea',
        imageEmoji: '🧋',
        category: 'beverage',
        difficulty: 'easy',
        prepTimeMinutes: 6,
        cookTimeMinutes: 6,
        servings: 2,
        tags: [
          'icecek',
          'cay',
          'seftali'
        ],
        ingredients: [
          _ingredient('tea', '2 tatlı kaşığı', '2 teaspoons'),
          _ingredient('peach', '1 adet', '1 piece'),
          _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true),
          _ingredient('water', '2 su bardağı', '2 cups')
        ],
        steps: [
          _step('Çayı demleyip soğumaya bırak.',
              'Brew the tea and let it cool.', 4),
          _step('Şeftali dilimleri ve istersen bal ile karıştırıp servis et.',
              'Mix with peach slices and honey if desired before serving.', 2)
        ]),
    _recipe(
        id: 'soguk_turk_kahvesi',
        nameTr: 'Soğuk Türk Kahvesi',
        nameEn: 'Iced Turkish Coffee',
        imageEmoji: '☕',
        category: 'beverage',
        difficulty: 'easy',
        prepTimeMinutes: 5,
        cookTimeMinutes: 4,
        servings: 2,
        tags: [
          'icecek',
          'kahve',
          'soguk'
        ],
        ingredients: [
          _ingredient('coffee', '2 tatlı kaşığı', '2 teaspoons'),
          _ingredient('milk', '1 su bardağı', '1 cup'),
          _ingredient('water', '1 su bardağı', '1 cup'),
          _ingredient('sugar', '1 tatlı kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Kahveyi suyla hazırlayıp tamamen soğut.',
              'Prepare the coffee with water and let it cool completely.', 4),
          _step('Süt ve şekerle karıştırıp soğuk servis et.',
              'Stir in milk and sugar and serve chilled.', 1)
        ]),
    _recipe(
        id: 'avokadolu_muzlu_smoothie',
        nameTr: 'Avokadolu Muzlu Smoothie',
        nameEn: 'Avocado Banana Smoothie',
        imageEmoji: '🥑',
        category: 'beverage',
        difficulty: 'easy',
        prepTimeMinutes: 4,
        cookTimeMinutes: 0,
        servings: 2,
        tags: [
          'icecek',
          'smoothie',
          'avokado'
        ],
        ingredients: [
          _ingredient('avocado', '1/2 adet', '1/2 piece'),
          _ingredient('banana', '1 adet', '1 piece'),
          _ingredient('milk', '1,5 su bardağı', '1.5 cups'),
          _ingredient('honey', '1 tatlı kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Tüm malzemeleri blendera al.',
              'Add all ingredients to a blender.', 2),
          _step('Pürüzsüz olana kadar çekip bekletmeden servis et.',
              'Blend until smooth and serve immediately.', 2)
        ]),
    _recipe(
        id: 'revani',
        nameTr: 'Limonlu Revani',
        nameEn: 'Lemon Revani',
        imageEmoji: '🍰',
        category: 'dessert',
        difficulty: 'medium',
        prepTimeMinutes: 15,
        cookTimeMinutes: 30,
        servings: 8,
        tags: [
          'tatli',
          'serbetli',
          'irmik'
        ],
        ingredients: [
          _ingredient('semolina', '1 su bardağı', '1 cup'),
          _ingredient('flour', '1 su bardağı', '1 cup'),
          _ingredient('sugar', '1 su bardağı', '1 cup'),
          _ingredient('yogurt', '1 su bardağı', '1 cup'),
          _ingredient('egg', '3 adet', '3 pieces'),
          _ingredient('baking_powder', '1 paket', '1 packet'),
          _ingredient('vanilla', '1 çay kaşığı', '1 teaspoon'),
          _ingredient('water', '2 su bardağı', '2 cups'),
          _ingredient('lemon', '1/2 adet', '1/2 piece')
        ],
        steps: [
          _step('Kek hamurunu hazırlayıp kalıba dök.',
              'Prepare the cake batter and pour it into the pan.', 10),
          _step('Pişen kekin üzerine limonlu şerbeti döküp dinlendir.',
              'Pour the lemon syrup over the baked cake and let it rest.', 20)
        ]),
    _recipe(
        id: 'sekerpare',
        nameTr: 'Şekerpare',
        nameEn: 'Sugar Cookies in Syrup',
        imageEmoji: '🍪',
        category: 'dessert',
        difficulty: 'medium',
        prepTimeMinutes: 18,
        cookTimeMinutes: 25,
        servings: 8,
        tags: [
          'tatli',
          'serbetli',
          'kurabiye'
        ],
        ingredients: [
          _ingredient('flour', '2 su bardağı', '2 cups'),
          _ingredient('semolina', '1/2 su bardağı', '1/2 cup'),
          _ingredient('butter', '125 gram', '125 grams'),
          _ingredient('egg', '1 adet', '1 piece'),
          _ingredient('baking_powder', '1 paket', '1 packet'),
          _ingredient('vanilla', '1 çay kaşığı', '1 teaspoon'),
          _ingredient('sugar', '2 su bardağı', '2 cups'),
          _ingredient('water', '2 su bardağı', '2 cups')
        ],
        steps: [
          _step('Hamuru yoğurup küçük parçalar halinde şekillendir.',
              'Knead the dough and shape it into small rounds.', 10),
          _step('Pişirdikten sonra sıcak kurabiyelere şerbeti dök.',
              'Bake them and pour the syrup over the hot cookies.', 15)
        ]),
    _recipe(
        id: 'irmik_helvasi',
        nameTr: 'Sütlü İrmik Helvası',
        nameEn: 'Milk Semolina Halva',
        imageEmoji: '🍮',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 18,
        servings: 6,
        tags: [
          'tatli',
          'irmik',
          'helva'
        ],
        ingredients: [
          _ingredient('semolina', '1 su bardağı', '1 cup'),
          _ingredient('butter', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('sugar', '1 su bardağı', '1 cup'),
          _ingredient('milk', '1 su bardağı', '1 cup'),
          _ingredient('water', '1 su bardağı', '1 cup'),
          _ingredient('pistachio', '2 yemek kaşığı', '2 tablespoons',
              optional: true)
        ],
        steps: [
          _step(
              'İrmiği tereyağında renk alana kadar kavur.',
              'Toast the semolina in butter until fragrant and lightly golden.',
              8),
          _step(
              'Sütlü şerbeti ekleyip çekene kadar pişir, fıstıkla servis et.',
              'Add the milk syrup, cook until absorbed, and serve with pistachios.',
              10)
        ]),
    _recipe(
        id: 'kabak_tatlisi',
        nameTr: 'Kabak Tatlısı',
        nameEn: 'Pumpkin Dessert',
        imageEmoji: '🎃',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 24,
        servings: 6,
        tags: [
          'tatli',
          'kabak',
          'ceviz'
        ],
        ingredients: [
          _ingredient('pumpkin', '500 gram', '500 grams'),
          _ingredient('sugar', '1 su bardağı', '1 cup'),
          _ingredient('walnut', '3 yemek kaşığı', '3 tablespoons',
              optional: true),
          _ingredient('cinnamon', '1 çay kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step('Balkabağını şekerle birlikte tencereye al.',
              'Place the pumpkin pieces in a pot with sugar.', 6),
          _step('Yumuşayana kadar pişirip ceviz ve tarçınla servis et.',
              'Cook until tender and serve with walnuts and cinnamon.', 18)
        ]),
    _recipe(
        id: 'tahinli_susamli_kurabiye',
        nameTr: 'Tahinli Susamlı Kurabiye',
        nameEn: 'Tahini Sesame Cookies',
        imageEmoji: '🍪',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 12,
        cookTimeMinutes: 15,
        servings: 8,
        tags: [
          'tatli',
          'tahin',
          'susam'
        ],
        ingredients: [
          _ingredient('flour', '2 su bardağı', '2 cups'),
          _ingredient('tahini', '3 yemek kaşığı', '3 tablespoons'),
          _ingredient('butter', '100 gram', '100 grams'),
          _ingredient('sugar', '1/2 su bardağı', '1/2 cup'),
          _ingredient('sesame', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('baking_powder', '1 çay kaşığı', '1 teaspoon')
        ],
        steps: [
          _step('Hamuru yoğurup susama bulayarak şekillendir.',
              'Prepare the dough, shape it, and coat with sesame.', 8),
          _step('Kurabiyeleri hafif renk alana kadar pişir.',
              'Bake the cookies until lightly golden.', 7)
        ]),
    _recipe(
        id: 'kakaolu_findikli_kek',
        nameTr: 'Kakaolu Fındıklı Kek',
        nameEn: 'Cocoa Hazelnut Cake',
        imageEmoji: '🍫',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 12,
        cookTimeMinutes: 30,
        servings: 8,
        tags: [
          'tatli',
          'kakao',
          'findik'
        ],
        ingredients: [
          _ingredient('flour', '2 su bardağı', '2 cups'),
          _ingredient('cocoa', '3 yemek kaşığı', '3 tablespoons'),
          _ingredient('sugar', '1 su bardağı', '1 cup'),
          _ingredient('egg', '3 adet', '3 pieces'),
          _ingredient('milk', '1 su bardağı', '1 cup'),
          _ingredient('butter', '100 gram', '100 grams'),
          _ingredient('hazelnut', '1/2 su bardağı', '1/2 cup'),
          _ingredient('baking_powder', '1 paket', '1 packet')
        ],
        steps: [
          _step('Kek hamurunu hazırlayıp fındıkları içine kat.',
              'Prepare the cake batter and fold in the hazelnuts.', 10),
          _step('Kalıpta pişirip dilimleyerek servis et.',
              'Bake in a pan and serve sliced.', 20)
        ]),
    _recipe(
        id: 'firin_elma_tarcin',
        nameTr: 'Fırın Elma Tarçın',
        nameEn: 'Baked Cinnamon Apples',
        imageEmoji: '🍎',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 18,
        servings: 4,
        tags: [
          'tatli',
          'elma',
          'tarcin'
        ],
        ingredients: [
          _ingredient('apple', '4 adet', '4 pieces'),
          _ingredient('cinnamon', '1 çay kaşığı', '1 teaspoon'),
          _ingredient('honey', '2 yemek kaşığı', '2 tablespoons',
              optional: true),
          _ingredient('walnut', '2 yemek kaşığı', '2 tablespoons',
              optional: true)
        ],
        steps: [
          _step('Elmaları ortadan ikiye kesip içlerini hafifçe oyun.',
              'Halve the apples and scoop out the centers slightly.', 5),
          _step(
              'Tarçın, bal ve cevizle doldurup fırında yumuşat.',
              'Fill with cinnamon, honey, and walnuts and bake until tender.',
              13)
        ]),
    _recipe(
        id: 'muhallebili_incir_kup',
        nameTr: 'Muhallebili İncir Kup',
        nameEn: 'Fig Custard Cups',
        imageEmoji: '🥛',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 10,
        cookTimeMinutes: 12,
        servings: 4,
        tags: [
          'tatli',
          'incir',
          'muhallebi'
        ],
        ingredients: [
          _ingredient('milk', '2 su bardağı', '2 cups'),
          _ingredient('starch', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('sugar', '4 yemek kaşığı', '4 tablespoons'),
          _ingredient('fig', '3 adet', '3 pieces'),
          _ingredient('vanilla', '1 çay kaşığı', '1 teaspoon')
        ],
        steps: [
          _step('Süt, nişasta ve şekeri koyulaşana kadar pişir.',
              'Cook the milk, starch, and sugar until thickened.', 8),
          _step('Kup bardaklara alıp incir ve vanilya ile tamamla.',
              'Portion into cups and finish with fig and vanilla.', 4)
        ]),
    _recipe(
        id: 'cikolatali_tahin_puding',
        nameTr: 'Çikolatalı Tahin Puding',
        nameEn: 'Chocolate Tahini Pudding',
        imageEmoji: '🍫',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 10,
        servings: 4,
        tags: [
          'tatli',
          'cikolata',
          'tahin'
        ],
        ingredients: [
          _ingredient('milk', '2 su bardağı', '2 cups'),
          _ingredient('starch', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('chocolate', '100 gram', '100 grams'),
          _ingredient('tahini', '2 yemek kaşığı', '2 tablespoons'),
          _ingredient('sugar', '3 yemek kaşığı', '3 tablespoons')
        ],
        steps: [
          _step('Süt, nişasta ve şekeri pişirerek puding tabanını hazırla.',
              'Cook the milk, starch, and sugar to make the pudding base.', 6),
          _step(
              'Çikolata ve tahini ekleyip eritin, soğutup servis edin.',
              'Add the chocolate and tahini, melt them in, then chill and serve.',
              4)
        ]),
    _recipe(
        id: 'muzlu_yulaf_kurabiye',
        nameTr: 'Muzlu Yulaf Kurabiye',
        nameEn: 'Banana Oat Cookies',
        imageEmoji: '🍪',
        category: 'dessert',
        difficulty: 'easy',
        prepTimeMinutes: 8,
        cookTimeMinutes: 15,
        servings: 8,
        tags: [
          'tatli',
          'muz',
          'yulaf'
        ],
        ingredients: [
          _ingredient('oats', '2 su bardağı', '2 cups'),
          _ingredient('banana', '2 adet', '2 pieces'),
          _ingredient('honey', '1 yemek kaşığı', '1 tablespoon',
              optional: true),
          _ingredient('walnut', '2 yemek kaşığı', '2 tablespoons',
              optional: true),
          _ingredient('cinnamon', '1 çay kaşığı', '1 teaspoon', optional: true)
        ],
        steps: [
          _step(
              'Muzu ezip yulaf ve diğer malzemelerle karıştır.',
              'Mash the banana and combine it with the oats and remaining ingredients.',
              5),
          _step('Kaşıkla tepsiye bırakıp fırında pişir.',
              'Spoon onto a tray and bake until set.', 10)
        ]),
  ];
}
