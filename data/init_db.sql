-- South Indian Food Database Schema + Seed Data
-- Run once: sqlite3 food.db < data/init_db.sql

CREATE TABLE IF NOT EXISTS breakfast (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    notes      TEXT,
    ingredient TEXT
);

CREATE TABLE IF NOT EXISTS curries (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    notes      TEXT,
    ingredient TEXT
);

CREATE TABLE IF NOT EXISTS snacks (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    notes      TEXT,
    ingredient TEXT
);

CREATE TABLE IF NOT EXISTS desserts (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    notes      TEXT,
    ingredient TEXT
);

CREATE TABLE IF NOT EXISTS condiments (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
);

-- Breakfast
INSERT INTO breakfast (name, notes, ingredient) VALUES
  ('Idli',           'Soft fluffy rice-lentil cakes',          'rice batter'),
  ('Dosa',           'Thin crispy fermented rice-lentil crepe', 'rice batter'),
  ('Pesarattu',      'Green moong dal dosa',                   'moong dal'),
  ('Upma',           'Semolina cooked with veggies',           'semolina'),
  ('Ven Pongal',     'Rice and moong dal with pepper and ghee','moong dal'),
  ('Punugulu',       'Crispy idli-batter balls',               'rice batter'),
  ('Medu Vada',      'Deep-fried urad dal doughnuts',          'urad dal'),
  ('Dibba Roti',     'Thick urad dal rice pancake',            'urad dal'),
  ('Pesarattu Upma', 'Pesarattu stuffed with upma',            'rice batter'),
  ('Sarva Pindi',    'Spicy rice flour pancake with peanuts',  'rice flour'),
  ('Bobbatlu',       'Sweet stuffed paratha',                  'wheat flour');

-- Curries
INSERT INTO curries (name, notes, ingredient) VALUES
  ('Gutti Vankaya',    'Stuffed baby brinjal in peanut-sesame gravy', 'brinjal'),
  ('Bendakaya Pulusu', 'Okra in tamarind gravy',                      'tamarind'),
  ('Tomato Pappu',     'Tomato lentil dal',                           'lentils'),
  ('Gongura Pappu',    'Sorrel leaves lentil dal',                    'lentils'),
  ('Majjiga Pulusu',   'Buttermilk stew with veggies',                'buttermilk'),
  ('Dosakaya Pulusu',  'Cucumber in tamarind gravy',                  'tamarind'),
  ('Kodi Kura',        'Spicy Andhra chicken curry',                  'chicken'),
  ('Natu Kodi Pulusu', 'Country chicken in tamarind gravy',           'chicken'),
  ('Gongura Mamsam',   'Gongura mutton or chicken',                   'mutton'),
  ('Chepala Pulusu',   'Fish in tamarind gravy',                      'fish'),
  ('Mutton Kura',      'Spicy mutton gravy',                          'mutton'),
  ('Bagara Baingan',   'Eggplant in sesame-peanut gravy',             'brinjal');

-- Snacks
INSERT INTO snacks (name, notes, ingredient) VALUES
  ('Punugulu',     'Crispy idli-batter deep-fried balls',    'rice batter'),
  ('Mirchi Bajji', 'Stuffed green chillies in besan batter', 'besan'),
  ('Masala Vada',  'Spicy urad dal vada',                    'urad dal'),
  ('Vankaya Bajji','Brinjal dipped in besan batter',         'besan'),
  ('Chakodi',      'Rice flour spiral snack',                'rice flour'),
  ('Palakayalu',   'Tiny crunchy rice flour balls',          'rice flour'),
  ('Murukku',      'Spicy rice flour murukku',               'rice flour'),
  ('Boondi Mix',   'Spiced boondi with peanuts and sev',     'besan'),
  ('Sarva Pindi',  'Rice flour pancake with chana dal',      'rice flour'),
  ('Uggani',       'Puffed rice with onions and tomatoes',   'puffed rice');

-- Desserts
INSERT INTO desserts (name, notes, ingredient) VALUES
  ('Pootharekulu',    'Rice paper with ghee and sugar',           'rice flour'),
  ('Ariselu',         'Deep-fried rice flour jaggery discs',      'rice flour'),
  ('Sunnundalu',      'Roasted urad dal laddu',                   'urad dal'),
  ('Bobbatlu',        'Chana dal-jaggery stuffed paratha',        'chana dal'),
  ('Kakinada Kaja',   'Crispy layered fried dough in syrup',      'wheat flour'),
  ('Bandar Laddu',    'Besan laddu with jaggery and cashews',     'besan'),
  ('Palakova',        'Reduced milk sweetened with sugar',        'milk'),
  ('Kajjikayalu',     'Fried pastries stuffed with coconut',      'wheat flour'),
  ('Gavvalu',         'Rice shells in jaggery syrup',             'rice flour'),
  ('Qubani Meetha',   'Stewed dried apricots with cream',         'milk'),
  ('Double ka Meetha','Fried bread in sweetened milk',            'milk'),
  ('Boorelu',         'Chana dal-jaggery stuffed fried balls',    'chana dal'),
  ('Rava Laddu',      'Roasted semolina with ghee and nuts',      'semolina');

-- Ingredients
CREATE TABLE IF NOT EXISTS ingredients (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

INSERT INTO ingredients (name) VALUES
  ('besan'),
  ('brinjal'),
  ('buttermilk'),
  ('chana dal'),
  ('chicken'),
  ('fish'),
  ('jaggery'),
  ('lentils'),
  ('milk'),
  ('moong dal'),
  ('mutton'),
  ('puffed rice'),
  ('rice batter'),
  ('rice flour'),
  ('semolina'),
  ('tamarind'),
  ('urad dal'),
  ('wheat flour');

-- Condiments
INSERT INTO condiments (name) VALUES
  ('Rasam'),
  ('Sambar'),
  ('Coconut Chutney'),
  ('Ginger Chutney'),
  ('Tamarind Chutney'),
  ('Yogurt');
