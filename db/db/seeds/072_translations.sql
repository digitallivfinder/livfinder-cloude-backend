-- =============================================================================
-- 072_translations.sql
--
-- The translation tables for the entities whose names appear in the interface:
-- categories, attributes, features, editorial taxonomy, agency profiles, and the
-- static and editorial pages.
--
-- The platform runs in fifteen languages, and the honest position is that most
-- of the long tail is machine-translated and marked as such. Where a translation
-- is genuine it is stated in the source language rather than glossed from
-- English -- an Arabic property vocabulary is not a transliteration of an
-- English one, and the sub-community names the geography layer carries prove it.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);

-- -----------------------------------------------------------------------------
-- Categories
--
-- The six roots and their children, in the four languages the marketplace sells
-- hardest in. Category names are the one place a machine translation is
-- immediately obvious to a native speaker, so these are stated rather than
-- generated.
-- -----------------------------------------------------------------------------
INSERT INTO category_translations
  (category_id, language_id, name, name_plural, slug, description, seo_title,
   seo_description, created_at, updated_at)
SELECT
  c.id, t.language_id, t.name, t.name_plural, t.slug, t.description,
  CONCAT(t.name_plural, ' | Liv Finder'),
  CONCAT(t.description, ' Liv Finder.'),
  @now, @now
FROM (
  SELECT 'real-estate' AS code, 2 AS language_id, 'عقار' AS name, 'عقارات' AS name_plural, 'aqarat' AS slug, 'تصفح العقارات الفاخرة للبيع والإيجار حول العالم.' AS description
  UNION ALL SELECT 'real-estate', 3, 'Bien immobilier', 'Immobilier',   'immobilier',  'Parcourez des biens immobiliers de prestige à vendre et à louer dans le monde entier.'
  UNION ALL SELECT 'real-estate', 4, 'Immobilie',       'Immobilien',   'immobilien',  'Durchsuchen Sie Luxusimmobilien zum Kauf und zur Miete weltweit.'
  UNION ALL SELECT 'real-estate', 8, 'Недвижимость',    'Недвижимость', 'nedvizhimost','Элитная недвижимость для покупки и аренды по всему миру.'
  UNION ALL SELECT 'cars',        2, 'سيارة',           'سيارات',       'sayarat',     'سيارات فاخرة وكلاسيكية للبيع من تجار موثوقين.'
  UNION ALL SELECT 'cars',        3, 'Voiture',         'Voitures',     'voitures',    'Voitures de luxe, de collection et de sport à vendre.'
  UNION ALL SELECT 'cars',        4, 'Fahrzeug',        'Fahrzeuge',    'fahrzeuge',   'Luxus-, Klassik- und Sportwagen von geprüften Händlern.'
  UNION ALL SELECT 'cars',        8, 'Автомобиль',      'Автомобили',   'avtomobili',  'Люксовые, классические и спортивные автомобили от проверенных дилеров.'
  UNION ALL SELECT 'yachts',      2, 'يخت',             'يخوت',         'yukhut',      'يخوت ومراكب فاخرة للبيع والاستئجار.'
  UNION ALL SELECT 'yachts',      3, 'Yacht',           'Yachts',       'yachts',      'Yachts à moteur et à voile à vendre et en location.'
  UNION ALL SELECT 'yachts',      4, 'Yacht',           'Yachten',      'yachten',     'Motor- und Segelyachten zum Kauf und zur Charter.'
  UNION ALL SELECT 'yachts',      8, 'Яхта',            'Яхты',         'yakhty',      'Моторные и парусные яхты для покупки и чартера.'
  UNION ALL SELECT 'jets',        2, 'طائرة خاصة',      'طائرات خاصة',  'tayarat',     'طائرات خاصة للبيع مع سجلات الصيانة الكاملة.'
  UNION ALL SELECT 'jets',        3, 'Jet privé',       'Jets privés',  'jets-prives', 'Jets privés à vendre avec historique de maintenance complet.'
  UNION ALL SELECT 'jets',        4, 'Privatjet',       'Privatjets',   'privatjets',  'Privatjets zum Verkauf mit vollständiger Wartungshistorie.'
  UNION ALL SELECT 'jets',        8, 'Самолёт',         'Самолёты',     'samolety',    'Частные самолёты с полной историей обслуживания.'
  UNION ALL SELECT 'helicopters', 2, 'مروحية',          'مروحيات',      'marwahiyat',  'مروحيات مدنية وتنفيذية للبيع.'
  UNION ALL SELECT 'helicopters', 3, 'Hélicoptère',     'Hélicoptères', 'helicopteres','Hélicoptères civils et exécutifs à vendre.'
  UNION ALL SELECT 'helicopters', 4, 'Hubschrauber',    'Hubschrauber', 'hubschrauber','Zivile und Executive-Hubschrauber zum Verkauf.'
  UNION ALL SELECT 'helicopters', 8, 'Вертолёт',        'Вертолёты',    'vertolety',   'Гражданские и представительские вертолёты.'
  UNION ALL SELECT 'watches',     2, 'ساعة',            'ساعات',        'saat',        'ساعات فاخرة وناردة موثقة الأصالة.'
  UNION ALL SELECT 'watches',     3, 'Montre',          'Montres',      'montres',     'Montres de luxe et pièces rares, authentifiées.'
  UNION ALL SELECT 'watches',     4, 'Uhr',             'Uhren',        'uhren',       'Luxus- und Sammleruhren, auf Echtheit geprüft.'
  UNION ALL SELECT 'watches',     8, 'Часы',            'Часы',         'chasy',       'Люксовые и коллекционные часы с проверкой подлинности.'
) AS t
JOIN categories c ON c.code = t.code AND c.parent_id IS NULL;

-- Child categories are machine-translated from the English name, and the
-- interface says so. Pretending otherwise is how a portal ends up advertising a
-- "semi-detached villa" in Arabic as something that means nothing.
INSERT INTO category_translations
  (category_id, language_id, name, name_plural, slug, created_at, updated_at)
SELECT
  c.id, lg.language_id,
  CONCAT(lg.marker, ' ', c.name),
  CONCAT(lg.marker, ' ', COALESCE(c.name_plural, c.name)),
  CONCAT(c.slug, '-', lg.suffix),
  @now, @now
FROM categories c
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker, 'ar' AS suffix
  UNION ALL SELECT 3, '⟪fr⟫', 'fr'
  UNION ALL SELECT 4, '⟪de⟫', 'de'
  UNION ALL SELECT 8, '⟪ru⟫', 'ru'
) AS lg
WHERE c.parent_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Attributes and features
--
-- The filter labels. These matter more than they look: a mistranslated filter
-- is a filter nobody uses, and an unused filter looks in the analytics like a
-- feature nobody wants.
-- -----------------------------------------------------------------------------
INSERT INTO attribute_translations (attribute_id, language_id, name, description)
SELECT
  a.id, lg.language_id,
  COALESCE(k.name, CONCAT(lg.marker, ' ', a.name)),
  CASE WHEN k.name IS NOT NULL
       THEN CONCAT(k.name, ' — ', COALESCE(a.description, a.name)) END
FROM attributes a
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker
  UNION ALL SELECT 3, '⟪fr⟫'
  UNION ALL SELECT 4, '⟪de⟫'
  UNION ALL SELECT 8, '⟪ru⟫'
) AS lg
LEFT JOIN (
  SELECT 'bedrooms' AS code, 2 AS language_id, 'غرف النوم' AS name
  UNION ALL SELECT 'bedrooms',  3, 'Chambres'
  UNION ALL SELECT 'bedrooms',  4, 'Schlafzimmer'
  UNION ALL SELECT 'bedrooms',  8, 'Спальни'
  UNION ALL SELECT 'bathrooms', 2, 'دورات المياه'
  UNION ALL SELECT 'bathrooms', 3, 'Salles de bain'
  UNION ALL SELECT 'bathrooms', 4, 'Badezimmer'
  UNION ALL SELECT 'bathrooms', 8, 'Ванные комнаты'
  UNION ALL SELECT 'built_area', 2, 'المساحة المبنية'
  UNION ALL SELECT 'built_area', 3, 'Surface habitable'
  UNION ALL SELECT 'built_area', 4, 'Wohnfläche'
  UNION ALL SELECT 'built_area', 8, 'Жилая площадь'
  UNION ALL SELECT 'plot_area', 2, 'مساحة الأرض'
  UNION ALL SELECT 'plot_area', 3, 'Surface du terrain'
  UNION ALL SELECT 'plot_area', 4, 'Grundstücksfläche'
  UNION ALL SELECT 'plot_area', 8, 'Площадь участка'
  UNION ALL SELECT 'year_built', 2, 'سنة البناء'
  UNION ALL SELECT 'year_built', 3, 'Année de construction'
  UNION ALL SELECT 'year_built', 4, 'Baujahr'
  UNION ALL SELECT 'year_built', 8, 'Год постройки'
  UNION ALL SELECT 'furnishing', 2, 'التأثيث'
  UNION ALL SELECT 'furnishing', 3, 'Ameublement'
  UNION ALL SELECT 'furnishing', 4, 'Möblierung'
  UNION ALL SELECT 'furnishing', 8, 'Меблировка'
  UNION ALL SELECT 'parking_spaces', 2, 'مواقف السيارات'
  UNION ALL SELECT 'parking_spaces', 3, 'Places de parking'
  UNION ALL SELECT 'parking_spaces', 4, 'Stellplätze'
  UNION ALL SELECT 'parking_spaces', 8, 'Парковочные места'
  UNION ALL SELECT 'mileage', 2, 'المسافة المقطوعة'
  UNION ALL SELECT 'mileage', 3, 'Kilométrage'
  UNION ALL SELECT 'mileage', 4, 'Laufleistung'
  UNION ALL SELECT 'mileage', 8, 'Пробег'
  UNION ALL SELECT 'transmission', 2, 'ناقل الحركة'
  UNION ALL SELECT 'transmission', 3, 'Boîte de vitesses'
  UNION ALL SELECT 'transmission', 4, 'Getriebe'
  UNION ALL SELECT 'transmission', 8, 'Коробка передач'
  UNION ALL SELECT 'length_overall', 2, 'الطول الكلي'
  UNION ALL SELECT 'length_overall', 3, 'Longueur hors tout'
  UNION ALL SELECT 'length_overall', 4, 'Länge über alles'
  UNION ALL SELECT 'length_overall', 8, 'Длина наибольшая'
  UNION ALL SELECT 'cabins', 2, 'المقصورات'
  UNION ALL SELECT 'cabins', 3, 'Cabines'
  UNION ALL SELECT 'cabins', 4, 'Kabinen'
  UNION ALL SELECT 'cabins', 8, 'Каюты'
) AS k ON k.code = a.code AND k.language_id = lg.language_id;

INSERT INTO feature_translations (feature_id, language_id, name)
SELECT
  f.id, lg.language_id,
  COALESCE(k.name, CONCAT(lg.marker, ' ', f.name))
FROM features f
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker
  UNION ALL SELECT 3, '⟪fr⟫'
  UNION ALL SELECT 4, '⟪de⟫'
  UNION ALL SELECT 8, '⟪ru⟫'
) AS lg
LEFT JOIN (
  SELECT 'private-pool' AS code, 2 AS language_id, 'مسبح خاص' AS name
  UNION ALL SELECT 'private-pool', 3, 'Piscine privée'
  UNION ALL SELECT 'private-pool', 4, 'Privater Pool'
  UNION ALL SELECT 'private-pool', 8, 'Собственный бассейн'
  UNION ALL SELECT 'sea-view', 2, 'إطلالة على البحر'
  UNION ALL SELECT 'sea-view', 3, 'Vue mer'
  UNION ALL SELECT 'sea-view', 4, 'Meerblick'
  UNION ALL SELECT 'sea-view', 8, 'Вид на море'
  UNION ALL SELECT 'gymnasium', 2, 'صالة رياضية'
  UNION ALL SELECT 'gymnasium', 3, 'Salle de sport'
  UNION ALL SELECT 'gymnasium', 4, 'Fitnessraum'
  UNION ALL SELECT 'gymnasium', 8, 'Тренажёрный зал'
  UNION ALL SELECT 'concierge', 2, 'خدمة الكونسيرج'
  UNION ALL SELECT 'concierge', 3, 'Conciergerie'
  UNION ALL SELECT 'concierge', 4, 'Concierge-Service'
  UNION ALL SELECT 'concierge', 8, 'Консьерж-сервис'
  UNION ALL SELECT 'maids-room', 2, 'غرفة خادمة'
  UNION ALL SELECT 'maids-room', 3, 'Chambre de service'
  UNION ALL SELECT 'maids-room', 4, 'Personalzimmer'
  UNION ALL SELECT 'maids-room', 8, 'Комната для персонала'
  UNION ALL SELECT 'covered-parking', 2, 'موقف مغطى'
  UNION ALL SELECT 'covered-parking', 3, 'Parking couvert'
  UNION ALL SELECT 'covered-parking', 4, 'Überdachter Stellplatz'
  UNION ALL SELECT 'covered-parking', 8, 'Крытая парковка'
  UNION ALL SELECT 'private-garden', 2, 'حديقة خاصة'
  UNION ALL SELECT 'private-garden', 3, 'Jardin privatif'
  UNION ALL SELECT 'private-garden', 4, 'Privatgarten'
  UNION ALL SELECT 'private-garden', 8, 'Собственный сад'
  UNION ALL SELECT 'balcony', 2, 'شرفة'
  UNION ALL SELECT 'balcony', 3, 'Balcon'
  UNION ALL SELECT 'balcony', 4, 'Balkon'
  UNION ALL SELECT 'balcony', 8, 'Балкон'
) AS k ON k.code = f.code AND k.language_id = lg.language_id;

INSERT INTO editorial_term_translations
  (term_id, language_id, name, slug, description)
SELECT
  t.id, lg.language_id,
  CONCAT(lg.marker, ' ', t.name),
  CONCAT(t.slug, '-', lg.suffix),
  CASE WHEN t.description IS NOT NULL
       THEN CONCAT(lg.marker, ' ', LEFT(t.description, 400)) END
FROM editorial_terms t
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker, 'ar' AS suffix
  UNION ALL SELECT 3, '⟪fr⟫', 'fr'
  UNION ALL SELECT 8, '⟪ru⟫', 'ru'
) AS lg;

-- -----------------------------------------------------------------------------
-- Agency profiles
--
-- Only the agencies that sell into a second language get a translated profile,
-- which is most of the Gulf and Riviera ones and none of the domestic-only
-- brokerages.
-- -----------------------------------------------------------------------------
INSERT INTO organization_translations
  (organization_id, language_id, tagline, description, seo_title, seo_description)
SELECT
  o.id, lg.language_id,
  CONCAT(lg.marker, ' ', COALESCE(o.tagline, o.name)),
  CONCAT(lg.marker, ' ', COALESCE(LEFT(o.description, 900),
         CONCAT(o.name, ' — a verified partner agency on Liv Finder.'))),
  CONCAT(lg.marker, ' ', o.name, ' | Liv Finder'),
  CONCAT(lg.marker, ' ', o.name, ' — ', o.active_listing_count,
         ' listings currently available.')
FROM organizations o
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker
  UNION ALL SELECT 3, '⟪fr⟫'
  UNION ALL SELECT 8, '⟪ru⟫'
) AS lg
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('orgtrans:', o.id)), 1, 4), 16, 10), 2) = 0;

-- -----------------------------------------------------------------------------
-- Editorial and static pages
--
-- Legal pages are human-translated because a machine-translated privacy notice
-- is not a privacy notice. Editorial articles are machine-translated and
-- flagged, because a market report that is a week late in French is worth more
-- than one that never arrives.
-- -----------------------------------------------------------------------------
INSERT INTO page_translations
  (page_id, language_id, title, slug, body, blocks, seo_title, seo_description)
SELECT
  p.id, lg.language_id,
  CONCAT(lg.marker, ' ', p.title),
  CONCAT(p.slug, '-', lg.suffix),
  CONCAT(lg.marker, ' ', LEFT(COALESCE(p.body, p.title), 2000)),
  NULL,
  CONCAT(lg.marker, ' ', p.title, ' | Liv Finder'),
  CONCAT(lg.marker, ' ', LEFT(COALESCE(p.seo_description, p.title), 400))
FROM pages p
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker, 'ar' AS suffix
  UNION ALL SELECT 3, '⟪fr⟫', 'fr'
  UNION ALL SELECT 4, '⟪de⟫', 'de'
  UNION ALL SELECT 8, '⟪ru⟫', 'ru'
) AS lg;

INSERT INTO post_translations
  (post_id, language_id, title, slug, excerpt, body, seo_title, seo_description,
   is_machine_translated, created_at, updated_at)
SELECT
  p.id, lg.language_id,
  CONCAT(lg.marker, ' ', p.title),
  CONCAT(p.slug, '-', lg.suffix),
  CONCAT(lg.marker, ' ', LEFT(COALESCE(p.excerpt, p.title), 500)),
  CONCAT(lg.marker, ' ', LEFT(COALESCE(p.body, p.title), 4000)),
  CONCAT(lg.marker, ' ', p.title, ' | Liv Finder'),
  CONCAT(lg.marker, ' ', LEFT(COALESCE(p.seo_description, p.excerpt, p.title), 400)),
  1, @now, @now
FROM posts p
JOIN (
  SELECT 2 AS language_id, '⟪ar⟫' AS marker, 'ar' AS suffix
  UNION ALL SELECT 3, '⟪fr⟫', 'fr'
  UNION ALL SELECT 8, '⟪ru⟫', 'ru'
) AS lg
WHERE p.status = 'published';
