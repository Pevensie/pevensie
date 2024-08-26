import birl
import decode
import gleam/dynamic.{
  type DecodeErrors as DynamicDecodeErrors, type Decoder,
  DecodeError as DynamicDecodeError,
}
import gleam/function
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type QueryError as PgoQueryError}
import gleam/result
import pevensie/drivers.{
  type AuthDriver, type CacheDriver, type Encoder, AuthDriver, CacheDriver,
}
import pevensie/internal/user.{
  type User, type UserInsert, User, app_metadata_to_json,
}

pub type IpVersion {
  Ipv4
  Ipv6
}

pub type PostgresConfig {
  PostgresConfig(
    host: String,
    port: Int,
    database: String,
    user: String,
    password: Option(String),
    ssl: Bool,
    connection_parameters: List(#(String, String)),
    pool_size: Int,
    queue_target: Int,
    queue_interval: Int,
    idle_interval: Int,
    trace: Bool,
    ip_version: IpVersion,
  )
}

pub opaque type Postgres {
  Postgres(config: pgo.Config, conn: Option(pgo.Connection))
}

pub fn default_config() -> PostgresConfig {
  PostgresConfig(
    host: "127.0.0.1",
    port: 5432,
    database: "postgres",
    user: "postgres",
    password: None,
    ssl: False,
    connection_parameters: [],
    pool_size: 1,
    queue_target: 50,
    queue_interval: 1000,
    idle_interval: 1000,
    trace: False,
    ip_version: Ipv4,
  )
}

fn postgres_config_to_pgo_config(config: PostgresConfig) -> pgo.Config {
  pgo.Config(
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    password: config.password,
    ssl: config.ssl,
    connection_parameters: config.connection_parameters,
    pool_size: config.pool_size,
    queue_target: config.queue_target,
    queue_interval: config.queue_interval,
    idle_interval: config.idle_interval,
    trace: config.trace,
    ip_version: case config.ip_version {
      Ipv4 -> pgo.Ipv4
      Ipv6 -> pgo.Ipv6
    },
  )
}

pub fn new_auth_driver(
  config: PostgresConfig,
) -> AuthDriver(Postgres, user_metadata) {
  AuthDriver(
    driver: Postgres(config |> postgres_config_to_pgo_config, None),
    connect: connect,
    disconnect: disconnect,
    get_user: fn(driver, field, value, decoder) {
      get_user(driver, field, value, decoder)
      // TODO: Handle errors
      |> result.map_error(fn(_err) { Nil })
    },
    insert_user: fn(driver, user, user_metadata_decoder, user_metadata_encoder) {
      insert_user(driver, user, user_metadata_decoder, user_metadata_encoder)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
  )
}

fn connect(driver: Postgres) -> Result(Postgres, Nil) {
  case driver {
    Postgres(config, None) -> {
      let conn = pgo.connect(config)

      Ok(Postgres(config, Some(conn)))
    }
    Postgres(_, Some(_)) -> Error(Nil)
  }
}

fn disconnect(driver: Postgres) -> Result(Postgres, Nil) {
  case driver {
    Postgres(config, Some(conn)) -> {
      let _ = pgo.disconnect(conn)
      Ok(Postgres(config, None))
    }
    Postgres(_, None) -> Error(Nil)
  }
}

pub type PostgresError {
  NotFound
  QueryError(PgoQueryError)
  DecodeError(DynamicDecodeErrors)
  InternalError(String)
}

fn postgres_user_decoder(
  user_metadata_decoder: Decoder(user_metadata),
) -> Decoder(User(user_metadata)) {
  fn(data) {
    decode.into({
      use id <- decode.parameter
      use created_at_tuple <- decode.parameter
      use updated_at_tuple <- decode.parameter
      use deleted_at_tuple <- decode.parameter
      use role <- decode.parameter
      use email <- decode.parameter
      use password_hash <- decode.parameter
      use email_confirmed_at_tuple <- decode.parameter
      use phone_number <- decode.parameter
      use phone_number_confirmed_at_tuple <- decode.parameter
      use last_sign_in_tuple <- decode.parameter
      use app_metadata_string <- decode.parameter
      use user_metadata_string <- decode.parameter
      use banned_until_tuple <- decode.parameter

      let created_at = birl.from_unix_micro(created_at_tuple)
      let updated_at = birl.from_unix_micro(updated_at_tuple)
      let deleted_at = case deleted_at_tuple {
        None -> None
        Some(deleted_at_tuple) -> Some(birl.from_unix_micro(deleted_at_tuple))
      }
      let email_confirmed_at = case email_confirmed_at_tuple {
        None -> None
        Some(email_confirmed_at_tuple) ->
          Some(birl.from_unix_micro(email_confirmed_at_tuple))
      }
      let phone_number_confirmed_at = case phone_number_confirmed_at_tuple {
        None -> None
        Some(phone_number_confirmed_at_tuple) ->
          Some(birl.from_unix_micro(phone_number_confirmed_at_tuple))
      }
      let last_sign_in = case last_sign_in_tuple {
        None -> None
        Some(last_sign_in_tuple) ->
          Some(birl.from_unix_micro(last_sign_in_tuple))
      }

      use app_metadata <- result.try(
        json.decode(
          app_metadata_string,
          dynamic.dict(dynamic.string, dynamic.dynamic),
        )
        |> result.map_error(fn(err) {
          case err {
            json.UnexpectedFormat(errs) -> errs
            _ -> [
              DynamicDecodeError("Valid JSON", "Invalid JSON", ["app_metadata"]),
            ]
          }
        }),
      )

      use user_metadata <- result.try(
        json.decode(
          user_metadata_string |> option.unwrap("null"),
          user_metadata_decoder,
        )
        |> result.map_error(fn(err) {
          case err {
            json.UnexpectedFormat(errs) -> errs
            _ -> [
              DynamicDecodeError("Valid JSON", "Invalid JSON", ["user_metadata"]),
            ]
          }
        }),
      )

      let banned_until = case banned_until_tuple {
        None -> None
        Some(banned_until_tuple) ->
          Some(birl.from_unix_micro(banned_until_tuple))
      }

      Ok(User(
        id,
        created_at,
        updated_at,
        deleted_at,
        role,
        email,
        password_hash,
        email_confirmed_at,
        phone_number,
        phone_number_confirmed_at,
        last_sign_in,
        app_metadata,
        user_metadata,
        banned_until,
      ))
    })
    |> decode.field(0, decode.string)
    |> decode.field(1, decode.int)
    |> decode.field(2, decode.int)
    |> decode.field(3, decode.optional(decode.int))
    |> decode.field(4, decode.optional(decode.string))
    |> decode.field(5, decode.string)
    |> decode.field(6, decode.optional(decode.string))
    |> decode.field(7, decode.optional(decode.int))
    |> decode.field(8, decode.optional(decode.string))
    |> decode.field(9, decode.optional(decode.int))
    |> decode.field(10, decode.optional(decode.int))
    |> decode.field(11, decode.string)
    |> decode.field(12, decode.optional(decode.string))
    |> decode.field(14, decode.optional(decode.int))
    |> decode.from(data)
    |> result.flatten
  }
}

fn get_user(
  driver: Postgres,
  by column: String,
  with value: String,
  using user_metadata_decoder: Decoder(user_metadata),
) -> Result(User(user_metadata), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql = "
    select
      id::text,
      -- Convert timestamp fields to UNIX epoch microseconds
      (extract(epoch from created_at) * 1000000)::bigint as created_at,
      (extract(epoch from updated_at) * 1000000)::bigint as updated_at,
      (extract(epoch from deleted_at) * 1000000)::bigint as deleted_at,
      role,
      email,
      password_hash,
      (extract(epoch from email_confirmed_at) * 1000000)::bigint as email_confirmed_at,
      phone_number,
      (extract(epoch from phone_number_confirmed_at) * 1000000)::bigint as phone_number_confirmed_at,
      (extract(epoch from last_sign_in) * 1000000)::bigint as last_sign_in,
      app_metadata,
      user_metadata,
      (extract(epoch from banned_until) * 1000000)::bigint as banned_until
    from pevensie.\"user\"
    where " <> column <> " = $1 and deleted_at is null"

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(value)],
      postgres_user_decoder(user_metadata_decoder),
    )
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Error(NotFound)
    [user] -> Ok(user)
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

fn insert_user(
  driver: Postgres,
  user: UserInsert(user_metadata),
  decoder user_metadata_decoder: Decoder(user_metadata),
  encoder user_metadata_encoder: Encoder(user_metadata),
) -> Result(User(user_metadata), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    insert into pevensie.\"user\" (
      role,
      email,
      password_hash,
      email_confirmed_at,
      phone_number,
      phone_number_confirmed_at,
      app_metadata,
      user_metadata
    ) values (
      $1,
      $2,
      $3,
      $4::timestamptz,
      $5,
      $6::timestamptz,
      $7::jsonb,
      $8::jsonb
    )
    returning
      id::text,
      -- Convert timestamp fields to UNIX epoch microseconds
      (extract(epoch from created_at) * 1000000)::bigint as created_at,
      (extract(epoch from updated_at) * 1000000)::bigint as updated_at,
      (extract(epoch from deleted_at) * 1000000)::bigint as deleted_at,
      role,
      email,
      password_hash,
      (extract(epoch from email_confirmed_at) * 1000000)::bigint as email_confirmed_at,
      phone_number,
      (extract(epoch from phone_number_confirmed_at) * 1000000)::bigint as phone_number_confirmed_at,
      (extract(epoch from last_sign_in) * 1000000)::bigint as last_sign_in,
      app_metadata,
      user_metadata,
      (extract(epoch from banned_until) * 1000000)::bigint as banned_until
  "

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.nullable(pgo.text, user.role),
        pgo.text(user.email),
        pgo.nullable(pgo.text, user.password_hash),
        pgo.nullable(
          pgo.timestamp,
          user.email_confirmed_at |> option.map(birl.to_erlang_datetime),
        ),
        pgo.nullable(pgo.text, user.phone_number),
        pgo.nullable(
          pgo.timestamp,
          user.phone_number_confirmed_at |> option.map(birl.to_erlang_datetime),
        ),
        pgo.text(app_metadata_to_json(user.app_metadata) |> json.to_string),
        pgo.text(user_metadata_encoder(user.user_metadata) |> json.to_string),
      ],
      postgres_user_decoder(user_metadata_decoder),
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Error(NotFound)
    [user] -> Ok(user)
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

pub fn new_cache_driver(config: PostgresConfig) -> CacheDriver(Postgres) {
  CacheDriver(
    driver: Postgres(config |> postgres_config_to_pgo_config, None),
    connect: connect,
    disconnect: disconnect,
    store: fn(driver, resource_type, key, value) {
      store(driver, resource_type, key, value)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    get: fn(driver, resource_type, key) {
      get(driver, resource_type, key)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    delete: fn(driver, resource_type, key) {
      delete(driver, resource_type, key)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
  )
}

fn store(
  driver: Postgres,
  resource_type: String,
  key: String,
  value: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    insert into pevensie.\"cache\" (
      resource_type,
      key,
      value
    ) values (
      $1,
      $2,
      $3
    )
    on conflict (resource_type, key) do update set value = $3"

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(resource_type), pgo.text(key), pgo.text(value)],
      fn(_) { Ok(json.null()) },
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn get(
  driver: Postgres,
  resource_type: String,
  key: String,
) -> Result(String, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    select value::text
    from pevensie.\"cache\"
    where resource_type = $1 and key = $2"

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(resource_type), pgo.text(key)],
      dynamic.decode1(function.identity, dynamic.element(0, dynamic.string)),
    )
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Error(NotFound)
    [value] -> Ok(value)
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

fn delete(
  driver: Postgres,
  resource_type: String,
  key: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    delete from pevensie.\"cache\"
    where resource_type = $1 and key = $2"

  let query_result =
    pgo.execute(sql, conn, [pgo.text(resource_type), pgo.text(key)], fn(_) {
      Ok(json.null())
    })
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}
