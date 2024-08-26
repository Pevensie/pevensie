create or replace function uuid7()
returns uuid
as $$
declare
begin
	return uuid7(clock_timestamp());
end $$
language plpgsql
;

create or replace function uuid7(p_timestamp timestamp with time zone)
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

create table if not exists pevensie."user" (
  id uuid not null default uuid7(),
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

create unique index user_email_unique_idx on "user" (email, deleted_at) where (email is not null) nulls not distinct;

create table if not exists pevensie."cache" (
  resource_type text not null,
  key text not null unique,
  value text not null,
  primary key (resource_type, key)
);
