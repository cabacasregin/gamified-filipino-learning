-- =============================================================================
-- seed.sql
-- MATATAG-aligned starter content for the four launch units. This is
-- illustrative curriculum content (not an official DepEd transcript) meant
-- to give the app real, usable data out of the box. A teacher can add/edit
-- more via the CMS once curriculum_units/lessons/lesson_items are populated.
--
-- Each unit gets exactly one lesson containing all of that unit's items --
-- nothing in the brief calls for multiple lessons per unit yet, and one
-- lesson keeps this seed simple; split lessons later via the CMS as needed.
--
-- lesson_items.unit_id is NOT set explicitly below -- it is filled in
-- automatically by the sync_lesson_item_unit_id trigger (0001_init.sql)
-- from each row's lesson_id, so it can never drift.
--
-- Intended to run once against a fresh database (e.g. `supabase db reset`,
-- which re-applies all migrations then this file). Re-running against a
-- database that already has this content will duplicate lessons/items,
-- since only curriculum_units.slug is guarded with ON CONFLICT.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Unit 1: Alpabetong Filipino (Filipino Alphabet)
-- All 28 letters of the modern Filipino alphabet: A-Z plus Ñ and the digraph
-- Ng, each paired with a representative word a beginner would recognize.
-- ---------------------------------------------------------------------------
with unit_row as (
  insert into public.curriculum_units (title_en, title_fil, slug, description, icon_emoji, sort_order)
  values (
    'Filipino Alphabet', 'Alpabetong Filipino', 'alpabetong-filipino',
    'Learn the modern Filipino alphabet, from Aa to Zz plus Ñ and Ng.',
    '🔤', 1
  )
  on conflict (slug) do update set title_en = excluded.title_en
  returning id
),
lesson_row as (
  insert into public.lessons (unit_id, title, sort_order)
  select id, 'Ang Alpabetong Filipino', 1 from unit_row
  returning id
)
insert into public.lesson_items
  (lesson_id, english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order)
select lesson_row.id, t.english_text, t.filipino_text, t.phonetic_hint, t.accepted_variants, t.emoji, t.sort_order
from lesson_row, (values
  ('A - Dog',        'Aso',      'AH-so',            array['aso','asso','ah so'],            '🐶', 1),
  ('B - Pig',        'Baboy',    'bah-BOY',          array['baboy','ba boy'],                 '🐷', 2),
  ('C - Cake',       'Keyk',     'keyk',             array['keyk','cake','keik'],             '🎂', 3),
  ('D - Rat',        'Daga',     'dah-GAH',          array['daga','dagga'],                   '🐭', 4),
  ('E - Elephant',   'Elepante', 'eh-leh-PAHN-teh',  array['elepante','elephante'],           '🐘', 5),
  ('F - Fiesta',     'Fiesta',   'fee-EHS-tah',      array['fiesta','piyesta'],               '🎉', 6),
  ('G - Milk',       'Gatas',    'GAH-tahs',         array['gatas','ga tas'],                 '🥛', 7),
  ('H - Shrimp',     'Hipon',    'HEE-pon',          array['hipon','ipon'],                   '🍤', 8),
  ('I - Egg',        'Itlog',    'it-LOG',           array['itlog','it log'],                 '🥚', 9),
  ('J - Jeepney',    'Jeepney',  'jeep-nee',         array['jeepney','dyipni','jeep ney'],    '🚙', 10),
  ('K - Carabao',    'Kalabaw',  'kah-lah-BAO',      array['kalabaw','kalabao'],              '🐃', 11),
  ('L - Toy',        'Laruan',   'lah-ROO-ahn',      array['laruan','laro'],                  '🧸', 12),
  ('M - Mango',      'Mangga',   'mahng-GAH',        array['mangga','manga'],                 '🥭', 13),
  ('N - Coconut',    'Niyog',    'NEE-yog',          array['niyog','ni yog'],                 '🥥', 14),
  ('Ñ - Child (Sto. Niño)', 'Niño', 'NEEN-yo',       array['nino','niño'],                    '👶', 15),
  ('Ng - Teeth',     'Ngipin',   'NGEE-pin',         array['ngipin','ipin'],                  '🦷', 16),
  ('O - Clock',      'Orasan',   'oh-rah-SAHN',      array['orasan','oras'],                  '⏰', 17),
  ('P - Cat',        'Pusa',     'POO-sah',          array['pusa','pussa'],                   '🐱', 18),
  ('Q - Cheese',     'Queso',    'KEH-so',           array['queso','keso'],                   '🧀', 19),
  ('R - Radio',      'Radyo',    'RAHD-yo',          array['radyo','radio'],                  '📻', 20),
  ('S - Banana',     'Saging',   'sah-GING',         array['saging','sa ging'],               '🍌', 21),
  ('T - Water',      'Tubig',    'TOO-big',          array['tubig','too big'],                '💧', 22),
  ('U - Crow',       'Uwak',     'OO-wak',           array['uwak','oowak'],                   '🐦', 23),
  ('V - Violin',     'Biyolin',  'bee-yo-LEEN',      array['biyolin','violin'],               '🎻', 24),
  ('W - Flag',       'Watawat',  'wah-TAH-wat',      array['watawat','wata wat'],             '🚩', 25),
  ('X - Xylophone',  'Saylopon', 'SAI-lo-pon',       array['saylopon','xylophone'],           '🎹', 26),
  ('Y - Ice',        'Yelo',     'YEH-lo',           array['yelo','yello'],                   '🧊', 27),
  ('Z - Shoes',      'Sapatos',  'sah-PAH-tos',      array['sapatos','zapatos'],              '👞', 28)
) as t(english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order);

-- ---------------------------------------------------------------------------
-- Unit 2: Mga Numero (Numbers 1-20)
-- ---------------------------------------------------------------------------
with unit_row as (
  insert into public.curriculum_units (title_en, title_fil, slug, description, icon_emoji, sort_order)
  values (
    'Numbers', 'Mga Numero', 'mga-numero',
    'Count from isa to dalawampu (1 to 20) in Filipino.',
    '🔢', 2
  )
  on conflict (slug) do update set title_en = excluded.title_en
  returning id
),
lesson_row as (
  insert into public.lessons (unit_id, title, sort_order)
  select id, 'Pagbibilang 1-20', 1 from unit_row
  returning id
)
insert into public.lesson_items
  (lesson_id, english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order)
select lesson_row.id, t.english_text, t.filipino_text, t.phonetic_hint, t.accepted_variants, t.emoji, t.sort_order
from lesson_row, (values
  ('One',        'Isa',              'EE-sah',                 array['isa','isang','eesa'],                          '1️⃣',       1),
  ('Two',        'Dalawa',           'dah-lah-WAH',            array['dalawa','dalawang','dalwa'],                   '2️⃣',       2),
  ('Three',      'Tatlo',            'tat-LOH',                array['tatlo','tatlong'],                             '3️⃣',       3),
  ('Four',       'Apat',             'AH-pat',                 array['apat','apat na'],                              '4️⃣',       4),
  ('Five',       'Lima',             'lee-MAH',                array['lima','limang'],                               '5️⃣',       5),
  ('Six',        'Anim',             'AH-nim',                 array['anim','anim na'],                              '6️⃣',       6),
  ('Seven',      'Pito',             'pee-TOH',                array['pito','pitong'],                               '7️⃣',       7),
  ('Eight',      'Walo',             'wah-LOH',                array['walo','walong'],                               '8️⃣',       8),
  ('Nine',       'Siyam',            'SEE-yam',                array['siyam','siyam na'],                            '9️⃣',       9),
  ('Ten',        'Sampu',            'sam-POO',                array['sampu','sampung'],                             '🔟',       10),
  ('Eleven',     'Labing-isa',       'lah-bing-EE-sah',        array['labing isa','labing-isa','labingisa'],         '1️⃣1️⃣',    11),
  ('Twelve',     'Labindalawa',      'lah-bin-dah-lah-WAH',    array['labindalawa','labing dalawa'],                 '1️⃣2️⃣',    12),
  ('Thirteen',   'Labintatlo',       'lah-bin-tat-LOH',        array['labintatlo','labing tatlo'],                   '1️⃣3️⃣',    13),
  ('Fourteen',   'Labing-apat',      'lah-bing-AH-pat',        array['labing apat','labing-apat','labingapat'],      '1️⃣4️⃣',    14),
  ('Fifteen',    'Labinlima',        'lah-bin-lee-MAH',        array['labinlima','labing lima'],                     '1️⃣5️⃣',    15),
  ('Sixteen',    'Labing-anim',      'lah-bing-AH-nim',        array['labing anim','labing-anim','labinganim'],      '1️⃣6️⃣',    16),
  ('Seventeen',  'Labimpito',        'lah-bim-pee-TOH',        array['labimpito','labing pito'],                     '1️⃣7️⃣',    17),
  ('Eighteen',   'Labingwalo',       'lah-bing-wah-LOH',       array['labingwalo','labing walo'],                    '1️⃣8️⃣',    18),
  ('Nineteen',   'Labinsiyam',       'lah-bin-SEE-yam',        array['labinsiyam','labing siyam'],                   '1️⃣9️⃣',    19),
  ('Twenty',     'Dalawampu',        'dah-lah-wam-POO',        array['dalawampu','dalawampung'],                     '2️⃣0️⃣',    20)
) as t(english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order);

-- ---------------------------------------------------------------------------
-- Unit 3: Mga Hugis (Shapes)
-- ---------------------------------------------------------------------------
with unit_row as (
  insert into public.curriculum_units (title_en, title_fil, slug, description, icon_emoji, sort_order)
  values (
    'Shapes', 'Mga Hugis', 'mga-hugis',
    'Recognize and name basic shapes like bilog, parisukat, and tatsulok.',
    '🔺', 3
  )
  on conflict (slug) do update set title_en = excluded.title_en
  returning id
),
lesson_row as (
  insert into public.lessons (unit_id, title, sort_order)
  select id, 'Mga Pangunahing Hugis', 1 from unit_row
  returning id
)
insert into public.lesson_items
  (lesson_id, english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order)
select lesson_row.id, t.english_text, t.filipino_text, t.phonetic_hint, t.accepted_variants, t.emoji, t.sort_order
from lesson_row, (values
  ('Circle',    'Bilog',     'bee-LOG',        array['bilog','bee log'],           '🔵', 1),
  ('Square',    'Parisukat', 'pah-ree-SOO-kat',array['parisukat','pari sukat'],    '🟦', 2),
  ('Triangle',  'Tatsulok',  'tat-SOO-lok',    array['tatsulok','tat sulok'],      '🔺', 3),
  ('Rectangle', 'Parihaba',  'pah-ree-HAH-bah',array['parihaba','pari haba'],      '🟧', 4),
  ('Star',      'Bituin',    'bee-too-EEN',    array['bituin','bitwin'],           '⭐', 5),
  ('Oval',      'Obalo',     'oh-BAH-lo',      array['obalo','oval'],              '🥚', 6),
  ('Diamond',   'Diyamante', 'dee-yah-MAHN-teh',array['diyamante','diamante'],     '🔶', 7),
  ('Heart',     'Puso',      'POO-so',         array['puso','poo so'],            '❤️', 8)
) as t(english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order);

-- ---------------------------------------------------------------------------
-- Unit 4: Mga Kulay (Colors)
-- ---------------------------------------------------------------------------
with unit_row as (
  insert into public.curriculum_units (title_en, title_fil, slug, description, icon_emoji, sort_order)
  values (
    'Colors', 'Mga Kulay', 'mga-kulay',
    'Name the colors of the rainbow and everyday objects in Filipino.',
    '🎨', 4
  )
  on conflict (slug) do update set title_en = excluded.title_en
  returning id
),
lesson_row as (
  insert into public.lessons (unit_id, title, sort_order)
  select id, 'Mga Kulay ng Bahaghari', 1 from unit_row
  returning id
)
insert into public.lesson_items
  (lesson_id, english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order)
select lesson_row.id, t.english_text, t.filipino_text, t.phonetic_hint, t.accepted_variants, t.emoji, t.sort_order
from lesson_row, (values
  ('Red',    'Pula',           'POO-lah',            array['pula','poola'],                     '🔴', 1),
  ('Blue',   'Asul',           'ah-SOOL',            array['asul','bughaw'],                    '🔵', 2),
  ('Yellow', 'Dilaw',          'dee-LAO',            array['dilaw','di law'],                   '🟡', 3),
  ('Green',  'Berde',          'BEHR-deh',           array['berde','birde'],                    '🟢', 4),
  ('Black',  'Itim',           'ee-TEEM',            array['itim','it im'],                     '⚫', 5),
  ('White',  'Puti',           'poo-TEE',            array['puti','pooti'],                     '⚪', 6),
  ('Pink',   'Kulay-rosas',    'koo-lai ro-SAHS',    array['kulay rosas','rosas','pink'],       '🩷', 7),
  ('Brown',  'Kayumanggi',     'kah-yoo-mahng-GEE',  array['kayumanggi','brown','kulay tsokolate'], '🟤', 8),
  ('Orange', 'Kahel',          'kah-HEHL',           array['kahel','orange'],                   '🟠', 9),
  ('Violet', 'Lila',           'lee-LAH',            array['lila','violet'],                    '🟣', 10)
) as t(english_text, filipino_text, phonetic_hint, accepted_variants, emoji, sort_order);
