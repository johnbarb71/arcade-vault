-- SPEC 06: catálogo de juegos (games) y leaderboard real (scores).

create table public.games (
  id text primary key,
  title text not null,
  short text not null,
  long text not null,
  cat text not null,
  cover text not null,
  color text not null,
  best integer not null,
  plays text not null
);

create table public.scores (
  id bigint generated always as identity primary key,
  game_id text not null references public.games (id),
  name text not null,
  score integer not null,
  created_at timestamptz not null default now()
);

create index scores_game_id_score_idx on public.scores (game_id, score desc);

alter table public.games enable row level security;
alter table public.scores enable row level security;

create policy "games_select_all" on public.games
  for select to anon, authenticated using (true);

create policy "scores_select_all" on public.scores
  for select to anon, authenticated using (true);

create policy "scores_insert_anon" on public.scores
  for insert to anon, authenticated with check (true);

-- games seed (8 rows, tal cual GAMES en lib/data.ts)
insert into public.games (id, title, short, long, cat, cover, color, best, plays) values
  ('bloque-buster', 'BLOQUE BUSTER', 'Rebota la pelota y destruye muros de neón.', 'Pilota una nave-paleta y rebota un núcleo de plasma para pulverizar muros de bloques cromáticos. Cada nivel reorganiza la grilla en patrones imposibles. ¿Hasta dónde llegará tu racha?', 'ARCADE', 'cover-bricks', 'cyan', 28450, '12.4K'),
  ('caida', 'CAÍDA', 'Encaja las piezas antes de que el techo te aplaste.', 'Piezas geométricas descienden desde la oscuridad. Rótalas, encástralas y limpia líneas para sobrevivir. La velocidad aumenta sin piedad cada 10 líneas.', 'PUZZLE', 'cover-tetro', 'magenta', 184220, '31.8K'),
  ('serpentina', 'SERPENTINA', 'Crece sin morder tu propia cola.', 'Una serpiente de luz recorre la grilla buscando núcleos magenta. Cada bocado la alarga y la hace más veloz. Un movimiento en falso y se devora a sí misma.', 'ARCADE', 'cover-snake', 'green', 7820, '9.1K'),
  ('gloton', 'GLOTÓN', 'Devora puntos y escapa de los fantasmas.', 'Un círculo glotón patrulla un laberinto coleccionando puntos luminosos. Cuatro espectros lo persiguen, pero cada cierto tiempo aparece una píldora que invierte los papeles.', 'ARCADE', 'cover-glot', 'yellow', 96400, '27.2K'),
  ('invasores', 'INVASORES', 'Defiende el planeta de filas alienígenas.', 'Olas de pixeles hostiles descienden formación tras formación. Mueve tu cañón en horizontal y abre fuego con precisión, antes de que toquen la superficie.', 'SHOOTER', 'cover-invaders', 'green', 54190, '18.0K'),
  ('rocas', 'ROCAS', 'Pulveriza asteroides en gravedad cero.', 'Tu nave triangular flota en vacío absoluto. Dispara y rota para dividir rocas en fragmentos cada vez más pequeños. Cuidado con los OVNIs en el horizonte.', 'SHOOTER', 'cover-rocas', 'yellow', 41200, '15.6K'),
  ('ranaria', 'RANARIA', 'Cruza la autopista de pixeles.', 'Salta entre carriles de coches a toda velocidad y troncos a la deriva en el río. Llega a los nenúfares antes de que se acabe el tiempo.', 'ARCADE', 'cover-rana', 'green', 18900, '6.4K'),
  ('duelo-pixel', 'DUELO PIXEL', 'Dos paletas. Una pelota. Reflejos máximos.', 'El duelo más puro: dos paletas verticales se enfrentan por rebotar una pelota luminosa. Modo solitario contra la CPU o partida local a dos jugadores.', 'VERSUS', 'cover-duelo', 'cyan', 24, '4.2K');

-- scores seed (12 filas por juego, 96 en total), generadas con la misma
-- lógica de seededScores(gameId.length * 23 + 7, 12) de lib/data.ts.
insert into public.scores (game_id, name, score) values
  ('bloque-buster', 'RGB_QUEEN', 275088),
  ('bloque-buster', 'GLITCHA', 232454),
  ('bloque-buster', 'Z3R0COOL', 232104),
  ('bloque-buster', 'DROID_X', 214488),
  ('bloque-buster', 'MAGENTA88', 210081),
  ('bloque-buster', 'VAULT_07', 209958),
  ('bloque-buster', 'CYBER_LU', 174442),
  ('bloque-buster', 'NEONFOX', 160117),
  ('bloque-buster', 'PIXEL_DAD', 140654),
  ('bloque-buster', 'ARKADYA', 112969),
  ('bloque-buster', 'VECTORX', 35990),
  ('bloque-buster', 'PX_KAI', 4146),
  ('caida', 'PIXEL_DAD', 278245),
  ('caida', 'Z3R0COOL', 225057),
  ('caida', 'NEONFOX', 222599),
  ('caida', 'ARKADYA', 216608),
  ('caida', 'VAULT_07', 195074),
  ('caida', 'RETROVIRA', 193429),
  ('caida', 'CYBER_LU', 179935),
  ('caida', 'VECTORX', 108899),
  ('caida', 'PX_KAI', 102080),
  ('caida', 'DROID_X', 58663),
  ('caida', 'JOY_STK', 49834),
  ('caida', 'GLITCHA', 39744),
  ('serpentina', 'DROID_X', 270582),
  ('serpentina', 'RGB_QUEEN', 259517),
  ('serpentina', 'ARKADYA', 255001),
  ('serpentina', 'NEONFOX', 238365),
  ('serpentina', 'VAULT_07', 192053),
  ('serpentina', 'JOY_STK', 131767),
  ('serpentina', 'SCANLINE', 123815),
  ('serpentina', 'PX_KAI', 120785),
  ('serpentina', 'CYBER_LU', 110896),
  ('serpentina', 'MAGENTA88', 94783),
  ('serpentina', 'PIXEL_DAD', 44169),
  ('serpentina', 'VECTORX', 23452),
  ('gloton', 'JOY_STK', 279079),
  ('gloton', 'PIXEL_DAD', 267110),
  ('gloton', 'PX_KAI', 214662),
  ('gloton', 'DROID_X', 203174),
  ('gloton', 'VECTORX', 202488),
  ('gloton', 'RGB_QUEEN', 195723),
  ('gloton', 'MAGENTA88', 191010),
  ('gloton', 'SCANLINE', 186887),
  ('gloton', 'ATARI_KID', 183133),
  ('gloton', 'BIT_LORD', 143287),
  ('gloton', 'RETROVIRA', 128647),
  ('gloton', 'VAULT_07', 67068),
  ('invasores', 'NEONFOX', 286640),
  ('invasores', 'ATARI_KID', 261239),
  ('invasores', 'ARKADYA', 245303),
  ('invasores', 'MAGENTA88', 238189),
  ('invasores', 'RGB_QUEEN', 198521),
  ('invasores', 'BIT_LORD', 195542),
  ('invasores', 'VECTORX', 170503),
  ('invasores', 'VAULT_07', 140256),
  ('invasores', 'PX_KAI', 47871),
  ('invasores', 'M00NRYU', 29677),
  ('invasores', 'JOY_STK', 22397),
  ('invasores', 'RETROVIRA', 1000),
  ('rocas', 'PIXEL_DAD', 278245),
  ('rocas', 'Z3R0COOL', 225057),
  ('rocas', 'NEONFOX', 222599),
  ('rocas', 'ARKADYA', 216608),
  ('rocas', 'VAULT_07', 195074),
  ('rocas', 'RETROVIRA', 193429),
  ('rocas', 'CYBER_LU', 179935),
  ('rocas', 'VECTORX', 108899),
  ('rocas', 'PX_KAI', 102080),
  ('rocas', 'DROID_X', 58663),
  ('rocas', 'JOY_STK', 49834),
  ('rocas', 'GLITCHA', 39744),
  ('ranaria', 'ATARI_KID', 274036),
  ('ranaria', 'CYBER_LU', 248743),
  ('ranaria', 'Z3R0COOL', 221737),
  ('ranaria', 'RETROVIRA', 171321),
  ('ranaria', 'MAGENTA88', 149988),
  ('ranaria', 'BIT_LORD', 138861),
  ('ranaria', 'M00NRYU', 116754),
  ('ranaria', 'VAULT_07', 112288),
  ('ranaria', 'DROID_X', 109893),
  ('ranaria', 'GLITCHA', 102992),
  ('ranaria', 'VECTORX', 85560),
  ('ranaria', 'PX_KAI', 49903),
  ('duelo-pixel', 'SCANLINE', 281190),
  ('duelo-pixel', 'GLITCHA', 231848),
  ('duelo-pixel', 'VECTORX', 210992),
  ('duelo-pixel', 'ARKADYA', 151133),
  ('duelo-pixel', 'PIXEL_DAD', 129572),
  ('duelo-pixel', 'JOY_STK', 93040),
  ('duelo-pixel', 'RGB_QUEEN', 85990),
  ('duelo-pixel', 'Z3R0COOL', 79598),
  ('duelo-pixel', 'M00NRYU', 75621),
  ('duelo-pixel', 'NEONFOX', 67338),
  ('duelo-pixel', 'VAULT_07', 65201),
  ('duelo-pixel', 'BIT_LORD', 61481);
