-- Initial base migration for Pevensie.
--
-- Sets up the `pevensie` schema, useful functions (UUIDv7)
-- and the `module_version` table.
-- Schema
create schema if not exists pevensie;

-- UUIDv7
-- All IDs are stored as UUIDs, and are generated using using a UUIDv7 implementation
-- made available by [Fabio Lima](https://github.com/fabiolimace) under the MIT license.
-- The implementation is available
-- [here](https://gist.github.com/fabiolimace/515a0440e3e40efeb234e12644a6a346).
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

-- `module_version` table
-- Stores the most up-to-date migration used for each module.
-- Module versions are stored as dates that correspond to the
-- filenames of the migrations in priv/drivers/postgres/migrations/<module_name>
create type pevensie."module" as enum (
  'base',
  'auth',
  'cache'
);

create table if not exists pevensie."module_version" (
  module pevensie."module" not null primary key,
  version timestamptz not null
);
