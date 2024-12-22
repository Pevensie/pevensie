-- Initial setup for the Pevensie Auth module.
--
-- Creates user, session and one_time_token tables.
-- user
create table if not exists pevensie."user" (
  id uuid not null default pevensie.uuid7() primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  role text,
  email text not null,
  password_hash text,
  email_confirmed_at timestamptz,
  phone_number text,
  phone_number_confirmed_at timestamptz,
  last_sign_in timestamptz,
  app_metadata jsonb not null default '{}'::jsonb, -- Identity providers, etc. Generally only updated by Pevensie functions
  user_metadata jsonb, -- User data for things like name, nickname, etc. Generally used for business logic
  banned_until timestamptz
);

create unique index user_email_unique_idx on pevensie."user" (email, deleted_at) nulls not distinct where (email is not null);
create unique index user_phone_number_unique_idx on pevensie."user" (phone_number, deleted_at) nulls not distinct where (phone_number is not null);

-- session
create table if not exists pevensie."session" (
  id uuid not null default pevensie.uuid7() primary key,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  user_id uuid not null references pevensie."user"(id) on delete cascade,
  ip inet,
  user_agent text
);

-- one_time_token
create type pevensie."one_time_token_type" as enum (
  'password-reset'
);

create table if not exists pevensie."one_time_token" (
  id uuid not null default pevensie.uuid7() primary key,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  expires_at timestamptz not null,
  used_at timestamptz,
  token_type pevensie."one_time_token_type" not null,
  user_id uuid not null references pevensie."user" (id) on delete cascade,
  token_hash text not null check (char_length(token_hash) > 0)
);

create index if not exists one_time_token_token_hash_idx on pevensie."one_time_token" using hash (token_hash);
create unique index one_time_token_user_id_token_type_unique_idx on pevensie."one_time_token" (user_id, token_type, deleted_at) nulls not distinct;
