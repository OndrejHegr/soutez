SET NAMES utf8;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

CREATE DATABASE IF NOT EXISTS soutez CHARACTER SET utf8;
USE soutez;

DROP TABLE IF EXISTS application;
DROP TABLE IF EXISTS club;
DROP TABLE IF EXISTS contest;
DROP TABLE IF EXISTS contest_age;
DROP TABLE IF EXISTS contest_level;
DROP TABLE IF EXISTS contest_offers;
DROP TABLE IF EXISTS contest_rules;
DROP TABLE IF EXISTS contest_style;
DROP TABLE IF EXISTS contest_team_size;
DROP TABLE IF EXISTS dancer;
DROP TABLE IF EXISTS music_files;
DROP TABLE IF EXISTS performance;
DROP TABLE IF EXISTS performance_member;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS team;
DROP TABLE IF EXISTS team_member;

CREATE TABLE application (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  contest_id int(11) NOT NULL COMMENT 'Reference na soutěž',
  leader_id int(11) NOT NULL COMMENT 'Reference na vedoucího',
  club_id int(11) NOT NULL COMMENT 'Reference na klub',
  created timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Datum a čas vytvoření záznamu',
  PRIMARY KEY (id),
  KEY leader_id (leader_id),
  KEY club_id (club_id),
  KEY contest_id (contest_id),
  CONSTRAINT application_ibfk_1 FOREIGN KEY (leader_id) REFERENCES person (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT application_ibfk_2 FOREIGN KEY (club_id) REFERENCES club (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT application_ibfk_3 FOREIGN KEY (contest_id) REFERENCES contest (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE club (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  name varchar(255) NOT NULL COMMENT 'Název klubu',
  city varchar(100) DEFAULT NULL COMMENT 'Město, kde klub sídlí',
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE contest (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  organizer_id int(11) NOT NULL,
  title varchar(255) NOT NULL,
  description text DEFAULT NULL,
  venue_name varchar(255) DEFAULT NULL,
  venue_street varchar(255) DEFAULT NULL,
  venue_city varchar(100) DEFAULT NULL,
  venue_zip varchar(20) DEFAULT NULL,
  venue_country varchar(100) DEFAULT NULL,
  venue_date date NOT NULL,
  start_time time DEFAULT NULL,
  deadline date NOT NULL,
  age_selection enum('SELECT_CATEGORY','ENTER_DANCERS') NOT NULL DEFAULT 'SELECT_CATEGORY',
  age_calculation enum('AT_EVENT_DATE','CALENDAR_YEAR') NOT NULL DEFAULT 'AT_EVENT_DATE',
  use_team_sizes TINYINT(1) NOT NULL,
  min_dancers int(11) DEFAULT 1,
  min_duration_sec int(11) DEFAULT 60,
  max_duration_sec int(11) DEFAULT 300,
  base_fee_czk int(11) DEFAULT 0,
  created datetime NOT NULL DEFAULT current_timestamp(),
  updated datetime ON UPDATE current_timestamp(),
  PRIMARY KEY (id),
  KEY idx_contest_organizer (organizer_id),
  KEY idx_contest_dates (venue_date,deadline),
  CONSTRAINT contest_ibfk_1 FOREIGN KEY (organizer_id) REFERENCES person (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_durations CHECK (max_duration_sec is null or min_duration_sec is null or max_duration_sec >= min_duration_sec)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE contest_age (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  contest_id int(11) NOT NULL,
  title varchar(100) NOT NULL,
  age_from int(11) DEFAULT NULL,
  age_to int(11) DEFAULT NULL,
  PRIMARY KEY (id),
  KEY contest_id (contest_id),
  CONSTRAINT contest_age_ibfk_1 FOREIGN KEY (contest_id) REFERENCES contest (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE contest_level (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  contest_id  INT NOT NULL,
  title       VARCHAR(100) NOT NULL,
  sort_order  INT NOT NULL DEFAULT 100,  -- menší číslo = výš v seznamu
  created  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated datetime ON UPDATE current_timestamp(),
  CONSTRAINT fk_level_contest FOREIGN KEY (contest_id) REFERENCES contest(id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT uq_level UNIQUE (contest_id, title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE contest_style (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  contest_id int(11) NOT NULL,
  title varchar(100) NOT NULL,
  music_required tinyint(1) DEFAULT 0,
  PRIMARY KEY (id),
  KEY contest_id (contest_id),
  CONSTRAINT contest_style_ibfk_1 FOREIGN KEY (contest_id) REFERENCES contest (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


-- MAPA povolených kombinací (věk + styl [+ volitelně level])
CREATE TABLE contest_offers (
  id         INT NOT NULL AUTO_INCREMENT,
  contest_id INT NOT NULL,
  age_id     INT NOT NULL,
  style_id   INT NOT NULL,
  level_id   INT NULL,
  PRIMARY KEY (id),
  -- jedna kombinace na soutěž smí existovat jen jednou
  UNIQUE KEY uq_offer (contest_id, age_id, style_id, level_id),
  CONSTRAINT fk_offer_contest FOREIGN KEY (contest_id) REFERENCES contest(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_offer_age     FOREIGN KEY (age_id)     REFERENCES contest_age(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_offer_style   FOREIGN KEY (style_id)   REFERENCES contest_style(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_offer_level   FOREIGN KEY (level_id)   REFERENCES contest_level(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE contest_rules (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  contest_id        INT NOT NULL,
  age_id            INT NULL,   -- -> contest_age.id
  style_id          INT NULL,   -- -> contest_style.id
  level_id          INT NULL,   -- -> contest_level.id (nepoužiješ-li úrovně, necháš NULL)
  fee_czk           DECIMAL(10,2) NULL,    -- startovné override
  min_duration_sec  INT NULL,              -- délka override (min)
  max_duration_sec  INT NULL,              -- délka override (max)
  music_required    TINYINT(1) NULL,       -- override požadavku na hudbu (NULL = neřeší)
  manual_priority   INT NULL,              -- volitelná manuální priorita
  created        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated datetime ON UPDATE current_timestamp(),
  CONSTRAINT fk_rules_contest FOREIGN KEY (contest_id) REFERENCES contest(id)  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rules_age     FOREIGN KEY (age_id)     REFERENCES contest_age(id)  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rules_style   FOREIGN KEY (style_id)   REFERENCES contest_style(id)  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rules_level   FOREIGN KEY (level_id)   REFERENCES contest_level(id)  ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE contest_team_size (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  contest_id       INT NOT NULL,
  title            VARCHAR(100) NOT NULL,
  min_members      INT NOT NULL,
  max_members      INT NULL,               -- NULL = bez horního limitu
  -- volitelně: délkové limity podle velikosti týmu
  min_duration_sec INT NULL,
  max_duration_sec INT NULL,
  created          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated datetime ON UPDATE current_timestamp(),
  CONSTRAINT fk_size_contest FOREIGN KEY (contest_id) REFERENCES contest(id)  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_members_range CHECK (max_members IS NULL OR max_members >= min_members),
  CONSTRAINT chk_duration_range CHECK (max_duration_sec IS NULL OR min_duration_sec IS NULL OR max_duration_sec >= min_duration_sec)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- užitečný index pro vyhledání velikosti dle počtu lidí
CREATE INDEX idx_size_bounds ON contest_team_size (contest_id, min_members, max_members);


CREATE TABLE dancer (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  leader_id int(11) NOT NULL,
  firstname varchar(100) NOT NULL,
  surname varchar(100) NOT NULL,
  birthdate date NOT NULL,
  PRIMARY KEY (id),
  KEY leader_id (leader_id),
  CONSTRAINT dancer_ibfk_1 FOREIGN KEY (leader_id) REFERENCES person (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE music_files (
  id INT(11) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  original_name VARCHAR(255) NOT NULL,     -- původní název souboru
  extension VARCHAR(10) NOT NULL,           -- přípona souboru (mp3, wav, ...)
  duration_sec INT(11) UNSIGNED NOT NULL,   -- délka skladby v sekundách
  active tinyint(1) DEFAULT 1,
  created datetime NOT NULL DEFAULT current_timestamp(),
  updated datetime ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE `performance` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `contest_id` int(11) NOT NULL COMMENT 'Reference na soutěž',
  `application_id` int(11) NOT NULL COMMENT 'Reference na přihlášku',
  `title` varchar(255) NOT NULL COMMENT 'Název vystoupení',
  `dancers_count` int(11) NOT NULL COMMENT 'Počet soutěžících',
  `duration_sec` int(11) NOT NULL COMMENT 'Délka vystoupení',
  `age_id` int(11) NOT NULL COMMENT 'Věková kategorie',
  `style_id` int(11) NOT NULL COMMENT 'Taneční kategorie',
  `level_id` int(11) DEFAULT NULL COMMENT 'Výkonnostní kategorie',
  `size_id` int(11) DEFAULT NULL COMMENT 'Velikost týmu (automaticky počítané pole)',
  `fee_czk` int(11) NOT NULL COMMENT 'Výše startovného',
  `status` enum('registered','withdrawn','presented') NOT NULL DEFAULT 'registered' COMMENT 'Stav vystoupení',
  `created` datetime NOT NULL DEFAULT current_timestamp() COMMENT 'Datum a  čas vytvoření záznamu',
  `updated` datetime DEFAULT NULL ON UPDATE current_timestamp() COMMENT 'Datum a  čas poslední změny záznamu',
  PRIMARY KEY (`id`),
  KEY `contest_id` (`contest_id`),
  KEY `idx_perf_app` (`application_id`),
  KEY `fk_perf_age` (`age_id`),
  KEY `fk_perf_style` (`style_id`),
  KEY `fk_perf_level` (`level_id`),
  KEY `fk_perf_size` (`size_id`),
  CONSTRAINT `performance_ibfk_1` FOREIGN KEY (`contest_id`) REFERENCES `contest` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `performance_ibfk_2` FOREIGN KEY (`age_id`) REFERENCES `contest_age` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `performance_ibfk_3` FOREIGN KEY (`application_id`) REFERENCES `application` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `performance_ibfk_4` FOREIGN KEY (`level_id`) REFERENCES `contest_level` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `performance_ibfk_5` FOREIGN KEY (`size_id`) REFERENCES `contest_team_size` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `performance_ibfk_6` FOREIGN KEY (`style_id`) REFERENCES `contest_style` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE performance_member (
  performance_id INT NOT NULL,
  dancer_id      INT NOT NULL,

  PRIMARY KEY (performance_id, dancer_id),

  CONSTRAINT fk_pm_perf  FOREIGN KEY (performance_id) REFERENCES performance(id)  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pm_dance FOREIGN KEY (dancer_id)      REFERENCES dancer(id)       ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- užitečný index pro dotazy „v jakých výkonech tančí tento tanečník“
CREATE INDEX idx_pm_dancer ON performance_member (dancer_id);


CREATE TABLE person (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  title varchar(100) NOT NULL COMMENT 'Jméno nebo zobrazovaný text',
  email varchar(255) NOT NULL COMMENT 'Přihlašovací email',
  password_hash varchar(255) NOT NULL COMMENT 'Heslo',
  club_id int(11) DEFAULT NULL COMMENT 'Reference na klub (použije se v přihlášce)',
  is_organizer tinyint(1) DEFAULT 0 COMMENT 'Příznak licence pořadatele soutěže',
  PRIMARY KEY (id),
  UNIQUE KEY email (email),
  KEY club_id (club_id),
  CONSTRAINT person_ibfk_1 FOREIGN KEY (club_id) REFERENCES club (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE team (
  id int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID záznamu',
  leader_id int(11) NOT NULL,
  name varchar(255) NOT NULL,
  PRIMARY KEY (id),
  KEY leader_id (leader_id),
  CONSTRAINT team_ibfk_1 FOREIGN KEY (leader_id) REFERENCES person (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE team_member (
  team_id int(11) NOT NULL,
  dancer_id int(11) NOT NULL,
  active tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (team_id,dancer_id),
  KEY dancer_id (dancer_id),
  CONSTRAINT team_member_ibfk_1 FOREIGN KEY (team_id) REFERENCES team (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT team_member_ibfk_2 FOREIGN KEY (dancer_id) REFERENCES dancer (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO person (id, title, email, password_hash, club_id, is_organizer) VALUES
(1,	'Ondřej',	'admin@nasoutez.eu',	'$2y$10$E.cJLCHgwRW4zRmKW/BNzu3rVywAKXp2MUcbJmLxOHqPEK9mbbhZu',	NULL,	1);

INSERT INTO club (id, name, city) VALUES
(1,	'Chlupáči',	'Radim'),
(2,	'Astra',	'Praha'),
(3,	'PS Hroch',	'Pardubice');

-- ++++++++++++++++++++++++++++++

START TRANSACTION;

-- Vedoucí a klub
SET @leader_id := (SELECT id FROM person WHERE email = 'admin@nasoutez.eu' LIMIT 1);


-- Týmy: založ jen pokud neexistují pro daného leadera
INSERT INTO team (leader_id, name)
SELECT @leader_id, 'Děti'
WHERE NOT EXISTS (SELECT 1 FROM team WHERE leader_id=@leader_id AND name='Děti');

INSERT INTO team (leader_id, name)
SELECT @leader_id, 'Junioři'
WHERE NOT EXISTS (SELECT 1 FROM team WHERE leader_id=@leader_id AND name='Junioři');

INSERT INTO team (leader_id, name)
SELECT @leader_id, 'Dospělí'
WHERE NOT EXISTS (SELECT 1 FROM team WHERE leader_id=@leader_id AND name='Dospělí');

SET @team_children := (SELECT id FROM team WHERE leader_id=@leader_id AND name='Děti' LIMIT 1);
SET @team_junior   := (SELECT id FROM team WHERE leader_id=@leader_id AND name='Junioři' LIMIT 1);
SET @team_adult    := (SELECT id FROM team WHERE leader_id=@leader_id AND name='Dospělí' LIMIT 1);

-- Děti (8–10 let → roky 2015–2017)
INSERT INTO dancer (leader_id, firstname, surname, birthdate) VALUES
(@leader_id, 'Karel',  'Malý',      '2015-05-12'),
(@leader_id, 'Anna',   'Nováková',  '2016-09-20'),
(@leader_id, 'Petr',   'Svoboda',   '2017-02-03'),
(@leader_id, 'Lucie',  'Dvořáková', '2016-11-11');

-- první ID z dávky:
SET @first_child_id := LAST_INSERT_ID();
SET @d1 := @first_child_id + 0;
SET @d2 := @first_child_id + 1;
SET @d3 := @first_child_id + 2;
SET @d4 := @first_child_id + 3;

INSERT INTO team_member (team_id, dancer_id) VALUES
(@team_children, @d1),(@team_children, @d2),(@team_children, @d3),(@team_children, @d4);

-- Junioři (10–18 let → roky 2007–2015)
INSERT INTO dancer (leader_id, firstname, surname, birthdate) VALUES
(@leader_id, 'David',  'Horák',    '2010-04-05'),
(@leader_id, 'Tereza', 'Benešová', '2012-07-18'),
(@leader_id, 'Filip',  'Král',     '2014-01-29');

SET @first_jun_id := LAST_INSERT_ID();
SET @j1 := @first_jun_id + 0;
SET @j2 := @first_jun_id + 1;
SET @j3 := @first_jun_id + 2;

INSERT INTO team_member (team_id, dancer_id) VALUES
(@team_junior, @j1),(@team_junior, @j2),(@team_junior, @j3);

-- Dospělí (18+ → rok narození ≤ 2006)
INSERT INTO dancer (leader_id, firstname, surname, birthdate) VALUES
(@leader_id, 'Michal', 'Procházka', '2005-03-14'),
(@leader_id, 'Jana',   'Černá',      '2000-06-22'),
(@leader_id, 'Eva',    'Kučerová',   '1998-10-09'),
(@leader_id, 'Tomáš',  'Pokorný',    '1990-12-01');

SET @first_adult_id := LAST_INSERT_ID();
SET @a1 := @first_adult_id + 0;
SET @a2 := @first_adult_id + 1;
SET @a3 := @first_adult_id + 2;
SET @a4 := @first_adult_id + 3;

INSERT INTO team_member (team_id, dancer_id) VALUES
(@team_adult, @a1),(@team_adult, @a2),(@team_adult, @a3),(@team_adult, @a4);

COMMIT;

-- ++++++++++++++++++++++++++++++

START TRANSACTION;

-- 0) Pořadatel
SET @organizer_id := (SELECT id FROM person WHERE email = 'admin@nasoutez.eu');

-- 1) Soutěž
INSERT INTO contest (
  organizer_id, title, description,
  venue_name, venue_street, venue_city, venue_zip, venue_country,
  venue_date, start_time, deadline,
  age_selection, age_calculation,
  min_dancers, min_duration_sec, max_duration_sec, base_fee_czk
) VALUES (
  @organizer_id,
  'Jedno startovné a délka vystoupení, bez úrovní',
  NULL,
  NULL, NULL, NULL, NULL, 'CZ',
  '2025-10-12', NULL, '2025-09-30',
  'SELECT_CATEGORY',
  'AT_EVENT_DATE',
  3,
  60, 300,
  100
);
SET @contest_id := LAST_INSERT_ID();

-- 2) Věky
INSERT INTO contest_age (contest_id, title, age_from, age_to) VALUES
(@contest_id, 'Děti 3–10 let',      3, 10),
(@contest_id, 'Junioři 10–18 let', 10, 18),
(@contest_id, 'Dospělí 18+ let',   18, NULL);

-- 3) Styly
INSERT INTO contest_style (contest_id, title, music_required) VALUES
(@contest_id, 'Art dance',   0),
(@contest_id, 'Disco dance', 0);

-- 4) Nabídky (offers): všechny věky × všechny styly, level NENÍ (NULL)
INSERT INTO contest_offers (contest_id, age_id, style_id, level_id)
SELECT a.contest_id, a.id, s.id, NULL
FROM contest_age a
JOIN contest_style s ON s.contest_id = a.contest_id
WHERE a.contest_id = @contest_id;

-- 5) Úrovně NEzakládáme
-- 6) Pravidla NEzadáváme (globální defaulty soutěže pokrývají min/max/fee)

COMMIT;

--	+++++++++++++++++++++++++++++
START TRANSACTION;

-- 0) Pořadatel
SET @organizer_id := (SELECT id FROM person WHERE email = 'admin@nasoutez.eu');

-- 1) Soutěž
INSERT INTO contest (
  organizer_id, title, description,
  venue_name, venue_street, venue_city, venue_zip, venue_country,
  venue_date, start_time, deadline,
  age_selection, age_calculation,
  min_dancers, min_duration_sec, max_duration_sec, base_fee_czk
) VALUES (
  @organizer_id,
  'Různé tance a výkonnosti dle věku',
  NULL,
  NULL, NULL, NULL, NULL, 'CZ',
  '2025-11-15', NULL, '2025-11-01',
  'SELECT_CATEGORY',
  'AT_EVENT_DATE',
  3,
  60, 300,
  0
);
SET @contest_id := LAST_INSERT_ID();

-- 2) Věky
INSERT INTO contest_age (contest_id, title, age_from, age_to) VALUES
(@contest_id, 'Mini 3–6 let',       3,  6),
(@contest_id, 'Děti 6–10 let',      6, 10),
(@contest_id, 'Junioři 10–18 let', 10, 18),
(@contest_id, 'Dospělí 18+ let',   18, NULL);

SET @age_mini  := (SELECT id FROM contest_age WHERE contest_id=@contest_id AND title='Mini 3–6 let' LIMIT 1);
SET @age_deti  := (SELECT id FROM contest_age WHERE contest_id=@contest_id AND title='Děti 6–10 let' LIMIT 1);
SET @age_jun   := (SELECT id FROM contest_age WHERE contest_id=@contest_id AND title='Junioři 10–18 let' LIMIT 1);
SET @age_adult := (SELECT id FROM contest_age WHERE contest_id=@contest_id AND title='Dospělí 18+ let' LIMIT 1);

-- 3) Styly
INSERT INTO contest_style (contest_id, title, music_required) VALUES
(@contest_id, 'Bez rozdílu stylu', 0),
(@contest_id, 'Art dance',         0),
(@contest_id, 'Disco dance',       0);

SET @style_any   := (SELECT id FROM contest_style WHERE contest_id=@contest_id AND title='Bez rozdílu stylu' LIMIT 1);
SET @style_art   := (SELECT id FROM contest_style WHERE contest_id=@contest_id AND title='Art dance' LIMIT 1);
SET @style_disco := (SELECT id FROM contest_style WHERE contest_id=@contest_id AND title='Disco dance' LIMIT 1);

-- 4) Úrovně (děti bez Profi; junioři/dospělí včetně Profi)
INSERT INTO contest_level (contest_id, title, sort_order) VALUES
(@contest_id, 'Začínající', 10),
(@contest_id, 'Pokročilí',  20),
(@contest_id, 'Profi',      30);

SET @lvl_beg := (SELECT id FROM contest_level WHERE contest_id=@contest_id AND title='Začínající' LIMIT 1);
SET @lvl_int := (SELECT id FROM contest_level WHERE contest_id=@contest_id AND title='Pokročilí'  LIMIT 1);
SET @lvl_pro := (SELECT id FROM contest_level WHERE contest_id=@contest_id AND title='Profi'      LIMIT 1);

-- 5) Nabídky (offers)

-- Mini: jen "Bez rozdílu stylu", bez úrovní
INSERT INTO contest_offers (contest_id, age_id, style_id, level_id)
VALUES (@contest_id, @age_mini, @style_any, NULL);

-- Děti: Art/Disco × (Začínající, Pokročilí)
INSERT INTO contest_offers (contest_id, age_id, style_id, level_id)
SELECT @contest_id, @age_deti, s.style_id, l.level_id
FROM (SELECT @style_art AS style_id UNION ALL SELECT @style_disco) s
JOIN (SELECT @lvl_beg AS level_id UNION ALL SELECT @lvl_int) l;

-- Junioři + Dospělí: Art/Disco × (Začínající, Pokročilí, Profi)
INSERT INTO contest_offers (contest_id, age_id, style_id, level_id)
SELECT @contest_id, a.age_id, s.style_id, l.level_id
FROM (SELECT @age_jun AS age_id UNION ALL SELECT @age_adult) a
JOIN (SELECT @style_art AS style_id UNION ALL SELECT @style_disco) s
JOIN (SELECT @lvl_beg AS level_id UNION ALL SELECT @lvl_int UNION ALL SELECT @lvl_pro) l;

-- 6) Pravidla (cena/délka)
-- Mini: 1–2 min, fee 100/os
INSERT INTO contest_rules (contest_id, age_id, style_id, level_id, fee_czk, min_duration_sec, max_duration_sec, music_required, manual_priority)
VALUES (@contest_id, @age_mini, @style_any, NULL, 100, 60, 120, NULL, 100);

-- Děti/Jun/Adult – Začínající: 100/os
INSERT INTO contest_rules (contest_id, age_id, style_id, level_id, fee_czk, manual_priority)
SELECT @contest_id, age_id, style_id, @lvl_beg, 100, 50
FROM (
  SELECT @age_deti AS age_id UNION ALL
  SELECT @age_jun  UNION ALL
  SELECT @age_adult
) a
CROSS JOIN (SELECT @style_art AS style_id UNION ALL SELECT @style_disco) s;

-- Pokročilí: 150/os
INSERT INTO contest_rules (contest_id, age_id, style_id, level_id, fee_czk, manual_priority)
SELECT @contest_id, age_id, style_id, @lvl_int, 150, 50
FROM (
  SELECT @age_deti AS age_id UNION ALL
  SELECT @age_jun  UNION ALL
  SELECT @age_adult
) a
CROSS JOIN (SELECT @style_art AS style_id UNION ALL SELECT @style_disco) s;

-- Profi: 200/os (jen Junioři + Dospělí)
INSERT INTO contest_rules (contest_id, age_id, style_id, level_id, fee_czk, manual_priority)
SELECT @contest_id, age_id, style_id, @lvl_pro, 200, 50
FROM (
  SELECT @age_jun  AS age_id UNION ALL
  SELECT @age_adult
) a
CROSS JOIN (SELECT @style_art AS style_id UNION ALL SELECT @style_disco) s;

COMMIT;

--	+++++++++++++++++++++++++++++

START TRANSACTION;

-- 0) Pořadatel
SET @organizer_id := (SELECT id FROM person WHERE email = 'admin@nasoutez.eu' LIMIT 1);

-- 1) Soutěž
INSERT INTO contest (
  organizer_id, title, description,
  venue_name, venue_street, venue_city, venue_zip, venue_country,
  venue_date, start_time, deadline,
  age_selection, age_calculation, use_team_sizes,
  min_dancers, min_duration_sec, max_duration_sec, base_fee_czk
) VALUES (
  @organizer_id,
  'Délka dle velikosti týmu',
  NULL,
  NULL, NULL, NULL, NULL, 'CZ',
  '2025-10-12', NULL, '2025-09-30',
  'SELECT_CATEGORY',
  'AT_EVENT_DATE',
  1,
  1, 60, 300, 100
);
SET @contest_id := LAST_INSERT_ID();

-- 2) Věky
INSERT INTO contest_age (contest_id, title, age_from, age_to) VALUES
(@contest_id, 'Děti 3–10 let',      3, 10),
(@contest_id, 'Junioři 10–18 let', 10, 18),
(@contest_id, 'Dospělí 18+ let',   18, NULL);

-- 3) Styly
INSERT INTO contest_style (contest_id, title, music_required) VALUES
(@contest_id, 'Art dance',   0),
(@contest_id, 'Disco dance', 0);

-- 4) Úrovně (Začínající, Pokročilí)
INSERT INTO contest_level (contest_id, title, sort_order) VALUES
(@contest_id, 'Začínající', 10),
(@contest_id, 'Pokročilí',  20);

SET @lvl_beg := (SELECT id FROM contest_level WHERE contest_id=@contest_id AND title='Začínající' LIMIT 1);
SET @lvl_int := (SELECT id FROM contest_level WHERE contest_id=@contest_id AND title='Pokročilí'  LIMIT 1);

-- 5) Nabídky (offers): všechny věky × styly × (Začínající, Pokročilí)
INSERT INTO contest_offers (contest_id, age_id, style_id, level_id)
SELECT @contest_id, a.id, s.id, l.level_id
FROM contest_age a
JOIN contest_style s ON s.contest_id = a.contest_id
JOIN (SELECT @lvl_beg AS level_id UNION ALL SELECT @lvl_int) l
WHERE a.contest_id = @contest_id;

-- 6) Velikosti týmů (určují délky)
INSERT INTO contest_team_size (contest_id, title, min_members, max_members, min_duration_sec, max_duration_sec) VALUES
(@contest_id, 'Sólo',           1,   1,   40, 165),
(@contest_id, 'Duo/Trio',       2,   3,   40, 180),
(@contest_id, 'Malé formace',   4,  10,   60, 240),
(@contest_id, 'Formace',       11,  24,  100, 300),
(@contest_id, 'Production',    25, NULL, 120, 480);

-- 7) Pravidla nejsou potřeba (fee globálně 100 Kč, délky z team_size)

COMMIT;
