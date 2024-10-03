create or replace function pevensie.uuid7()
returns uuid
as $$
declare
begin
	return pevensie.uuid7(clock_timestamp());
end $$
language plpgsql
;

create or replace function pevensie.uuid7(p_timestamp timestamp with time zone)
returns uuid
as $$
declare

	v_time double precision := null;

	v_unix_t bigint := null;
	v_rand_a bigint := null;
	v_rand_b bigint := null;

	v_unix_t_hex varchar := null;
	v_rand_a_hex varchar := null;
	v_rand_b_hex varchar := null;

	c_milli double precision := 10^3;  -- 1 000
	c_micro double precision := 10^6;  -- 1 000 000
	c_scale double precision := 4.096; -- 4.0 * (1024 / 1000)
	
	c_version bigint := x'0000000000007000'::bigint; -- RFC-9562 version: b'0111...'
	c_variant bigint := x'8000000000000000'::bigint; -- RFC-9562 variant: b'10xx...'

begin

	v_time := extract(epoch from p_timestamp);

	v_unix_t := trunc(v_time * c_milli);
	v_rand_a := trunc((v_time * c_micro - v_unix_t * c_milli) * c_scale);
	v_rand_b := trunc(random() * 2^30)::bigint << 32 | trunc(random() * 2^32)::bigint;

	v_unix_t_hex := lpad(to_hex(v_unix_t), 12, '0');
	v_rand_a_hex := lpad(to_hex((v_rand_a | c_version)::bigint), 4, '0');
	v_rand_b_hex := lpad(to_hex((v_rand_b | c_variant)::bigint), 16, '0');

	return (v_unix_t_hex || v_rand_a_hex || v_rand_b_hex)::uuid;
	
end $$
language plpgsql
;

create schema if not exists pevensie;

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
  user_id uuid not null references pevensie."user"(id),
  ip inet,
  user_agent text
);

-- cache
create unlogged table if not exists pevensie."cache" (
  resource_type text not null,
  key text not null unique,
  value text not null,
  expires_at timestamptz,
  primary key (resource_type, key)
);

-- one_time_token
-- TODO: see if we can do 'if not exists'
create type pevensie."one_time_token_type" as (
  'password-reset'
);

create table if not exists pevensie."one_time_token" (
  id uuid not null default pevensie.uuid7() primary key,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  expires_at timestamptz not null,
  used_at timestamptz,
  token_type pevensie."one_time_token_type" not null,
  user_id uuid not null references pevensie."user" (id),
  token_hash text not null check (char_length(token_hash) > 0)
);

create index if not exists one_time_token_token_hash_idx on pevensie."one_time_token" using hash (token_hash);
create unique index one_time_token_user_id_token_type_unique_idx on pevensie."one_time_token" (user_id, token_type, deleted_at) nulls not distinct;

-- module_version
-- TODO: see if we can do 'if not exists'
create type pevensie."module" as enum (
  'base',
  'auth',
  'cache'
);

create table if not exists pevensie."module_version" (
  module pevensie."module" not null primary key,
  version date not null
);
