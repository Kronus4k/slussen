USE ROLE DATA_ENGINEER;
USE WAREHOUSE TRANSFORM_WH;

CREATE TABLE IF NOT EXISTS ECOM_DB.SILVER.REF_CATEGORY_LABEL (
  category VARCHAR NOT NULL,
  category_label VARCHAR NOT NULL,
  CONSTRAINT pk_ref_category_label PRIMARY KEY (category)
);

MERGE INTO ECOM_DB.SILVER.REF_CATEGORY_LABEL t
USING (
  SELECT column1 AS category, column2 AS category_label
  FROM VALUES
    ('agro_industry_and_commerce', 'Agro-industry & commerce'),
    ('air_conditioning', 'Air conditioning'),
    ('art', 'Art'),
    ('arts_and_craftmanship', 'Arts & crafts'),
    ('audio', 'Audio'),
    ('auto', 'Auto'),
    ('baby', 'Baby'),
    ('bed_bath_table', 'Bed, bath & table'),
    ('books_general_interest', 'Books: general interest'),
    ('books_imported', 'Books: imported'),
    ('books_technical', 'Books: technical'),
    ('cds_dvds_musicals', 'CDs, DVDs & musicals'),
    ('christmas_supplies', 'Christmas supplies'),
    ('cine_photo', 'Cinema & photo'),
    ('computers', 'Computers'),
    ('computers_accessories', 'Computer accessories'),
    ('consoles_games', 'Consoles & games'),
    ('construction_tools_construction', 'Construction tools: building'),
    ('construction_tools_lights', 'Construction tools: lighting'),
    ('construction_tools_safety', 'Construction tools: safety'),
    ('cool_stuff', 'Cool stuff'),
    ('costruction_tools_garden', 'Construction tools: garden'),
    ('costruction_tools_tools', 'Construction tools: hand tools'),
    ('diapers_and_hygiene', 'Diapers & hygiene'),
    ('drinks', 'Drinks'),
    ('dvds_blu_ray', 'DVDs & Blu-ray'),
    ('electronics', 'Electronics'),
    ('fashio_female_clothing', 'Fashion: women''s clothing'),
    ('fashion_bags_accessories', 'Fashion: bags & accessories'),
    ('fashion_childrens_clothes', 'Fashion: children''s clothing'),
    ('fashion_male_clothing', 'Fashion: men''s clothing'),
    ('fashion_shoes', 'Fashion: shoes'),
    ('fashion_sport', 'Fashion: sportswear'),
    ('fashion_underwear_beach', 'Fashion: underwear & beachwear'),
    ('fixed_telephony', 'Fixed telephony'),
    ('flowers', 'Flowers'),
    ('food', 'Food'),
    ('food_drink', 'Food & drink'),
    ('furniture_bedroom', 'Furniture: bedroom'),
    ('furniture_decor', 'Furniture & decor'),
    ('furniture_living_room', 'Furniture: living room'),
    ('furniture_mattress_and_upholstery', 'Furniture: mattresses & upholstery'),
    ('garden_tools', 'Garden tools'),
    ('health_beauty', 'Health & beauty'),
    ('home_appliances', 'Home appliances'),
    ('home_appliances_2', 'Home appliances 2'),
    ('home_comfort_2', 'Home comfort 2'),
    ('home_confort', 'Home comfort'),
    ('home_construction', 'Home construction'),
    ('housewares', 'Housewares'),
    ('industry_commerce_and_business', 'Industry, commerce & business'),
    ('kitchen_dining_laundry_garden_furniture', 'Kitchen, dining, laundry & garden furniture'),
    ('la_cuisine', 'La cuisine'),
    ('luggage_accessories', 'Luggage & accessories'),
    ('market_place', 'Marketplace'),
    ('music', 'Music'),
    ('musical_instruments', 'Musical instruments'),
    ('office_furniture', 'Office furniture'),
    ('party_supplies', 'Party supplies'),
    ('pc_gamer', 'PC gaming'),
    ('perfumery', 'Perfumery'),
    ('pet_shop', 'Pet shop'),
    ('portable_kitchen_food_preparers', 'Portable kitchen & food preparers'),
    ('security_and_services', 'Security & services'),
    ('signaling_and_security', 'Signalling & security'),
    ('small_appliances', 'Small appliances'),
    ('small_appliances_home_oven_and_coffee', 'Small appliances: ovens & coffee'),
    ('sports_leisure', 'Sports & leisure'),
    ('stationery', 'Stationery'),
    ('tablets_printing_image', 'Tablets, printing & imaging'),
    ('telephony', 'Telephony'),
    ('toys', 'Toys'),
    ('unknown', 'Uncategorised'),
    ('watches_gifts', 'Watches & gifts')
) s
ON t.category = s.category
WHEN MATCHED AND t.category_label <> s.category_label
  THEN UPDATE SET category_label = s.category_label
WHEN NOT MATCHED
  THEN INSERT (category, category_label) VALUES (s.category, s.category_label);