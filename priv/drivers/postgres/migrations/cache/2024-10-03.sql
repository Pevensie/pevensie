-- Initial setup for the Pevensie Cache module.
--
-- Creates the unlogged cache table.
create unlogged table if not exists pevensie."cache" (
  resource_type text not null,
  key text not null unique,
  value text not null,
  expires_at timestamptz,
  primary key (resource_type, key)
);
