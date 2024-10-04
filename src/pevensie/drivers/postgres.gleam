//// The official PostgreSQL driver for Pevensie. It provides driver
//// implementations for Pevensie modules to be used with Postgres
//// databases.
////
//// Currently provides drivers for:
////
//// - [Pevensie Auth](/pevensie/auth.html)
//// - [Pevensie Cache](/pevensie/cache.html)
////
//// ## Getting Started
////
//// Configure your driver to connect to your database using the
//// [`PostgresConfig`](/pevensie/drivers/postgres.html#PostgresConfig)
//// type. You can use the [`default_config`](/pevensie/drivers/postgres.html#default_config)
//// function to get a default configuration for connecting to a local
//// Postgres database with sensible concurrency defaults.
////
//// ```gleam
//// import pevensie/drivers/postgres.{type PostgresConfig}
////
//// pub fn main() {
////   let config = PostgresConfig(
////     ..postgres.default_config(),
////     host: "db.pevensie.dev",
////     database: "my_database",
////   )
////   // ...
//// }
//// ```
////
//// Create a new driver using one of the `new_<driver>_driver` functions
//// provided by this module. You can then use the driver with Pevensie
//// modules.
////
//// ```gleam
//// import pevensie/drivers/postgres.{type PostgresConfig}
//// import pevensie/auth.{type PevensieAuth}
////
//// pub fn main() {
////   let config = PostgresConfig(
////     ..postgres.default_config(),
////     host: "db.pevensie.dev",
////     database: "my_database",
////   )
////   let driver = postgres.new_auth_driver(config)
////   let pevensie_auth = auth.new(
////     driver:,
////     user_metadata_decoder:,
////     user_metadata_encoder:,
////     cookie_key: "super secret signing key",
////   )
////   // ...
//// }
//// ```
////
//// ## Connection Management
////
//// When called with the Postgres driver, the [`connect`](/pevensie/auth.html#connect) function
//// provided by Pevensie Auth will create a connection pool for the database. This can be called
//// once on boot, and will be reused for the lifetime of the application.
////
//// The [`disconnect`](/pevensie/auth.html#disconnect) function will close the connection pool.
////
//// ## Tables
////
//// This driver creates tables in the `pevensie` schema to store user
//// data, sessions, and cache data.
////
//// The current tables created by this driver are:
////
//// | Table Name | Description |
//// | ---------- | ----------- |
//// | `cache` | Stores cache data. This table is unlogged, so data will be lost when the database stops. |
//// | `one_time_token` | Stores one time tokens. Uses soft deletions. |
//// | `session` | Stores session data. |
//// | `user` | Stores user data. Uses soft deletions. |
//// | `module_version` | Stores the current versions of the tables required by this driver. Versions are stored as dates. |
////
//// ### Types
////
//// Generally, the Postgres driver makes a best effort to map the types
//// used by Pevensie to best-practice Postgres types. Generally, columns
//// are non-nullable unless the Gleam type is `Option(a)`. The following
//// types are mapped to Postgres types:
////
//// | Gleam Type | Postgres Type |
//// | ---------- | ------------- |
//// | Any resource ID | `UUID` (generated as UUIDv7) |
//// | `String` | `text` |
//// | `birl.Time` | `timestamptz` |
//// | Record types (e.g. `user_metadata`) | `jsonb` |
//// | `pevensie/net.IpAddr` | `inet` |
////
//// ## Migrations
////
//// You can run migrations against your
//// database using the provided CLI:
////
//// ```sh
//// gleam run -m pevensie/drivers/postgres migrate <connection_string> --modules=auth,cache
//// ```
////
//// The required SQL statements will be printed to the console. You can
//// apply the migrations directly using the `--apply` flag.
////
//// See docs on the [`migrate`](/pevensie/drivers/postgres.html#migrate)
//// function for more information.
////
//// ## Implementation Details
////
//// This driver uses the [gleam_pgo](https://github.com//pgo) library for interacting
//// with Postgres.
////
//// All IDs are stored as UUIDs, and are generated using using a UUIDv7 implementation
//// made available by [Fabio Lima](https://github.com/fabiolimace) under the MIT license.
//// The implementation is available [here](https://gist.github.com/fabiolimace/515a0440e3e40efeb234e12644a6a346).
////
//// ### Pevensie Auth
////
//// The `user` table follows the structure of the [`User`](/pevensie/user.html#User)
//// type. The `user_metadata` column is a JSONB column, and is used to store
//// any custom user metadata.
////
//// It also contains a `deleted_at` column, which is used to mark users as deleted,
//// rather than deleting the row from the database.
////
//// Alongside the primary key, the `user` table has unique indexes on the
//// `email` and `phone_number` columns. These are partial, and only index
//// where values are provided. They also include the `deleted_at` column,
//// so users can sign up with the same email if a user with that email
//// has been deleted.
////
//// The `session` table follows the structure of the [`Session`](/pevensie/session.html#Session)
//// type. The `user_id` column is a foreign key referencing the `user` table. If
//// an expired session is read, the `get_session` function will return `None`, and
//// delete the expired session from the database.
////
//// #### Searching for users
////
//// The `list_users` function provided by Pevensie Auth allows you to search for users
//// by ID, email or phone number. With the Postgres driver, the lists in you
//// [`UserSearchFields`](/pevensie/user.html#UserSearchFields) argument are processed
//// using a `like any()` where clause. This means that you can search for users
//// by providing a list of values, and the driver will search for users with
//// any of those values.
////
//// You can also use Postgres `like` wildcards in your search values. For example,
//// if you search for users with an email ending in `@example.com`, you can use
//// `%@example.com` as the search value.
////
//// ### Pevensie Cache
////
//// The `cache` table is an [`unlogged`](https://www.postgresql.org/docs/current/sql-createtable.html#SQL-CREATETABLE-UNLOGGED)
//// table. This ensures that writes are fast, but data is lost when the database
//// is stopped. Do not use Pevensie Cache for data you need to keep indefinitely.
////
//// The table's primary key is a composite of the `resource_type` and `key`
//// columns. This allows you to store multiple values for a given key, and
//// retrieve them all at once.
////
//// Writes to the cache will overwrite any existing value for the given
//// resource type and key. This driver does not keep a version history.
////
//// If an expired value is read, the `get` function will return `None`, and
//// delete the expired value from the cache.
////
//// ### Custom Queries
////
//// If you wish to query the `user` or `session` tables directly, this driver
//// provides helper utilities for doing so.
////
//// The [`user_decoder`](/pevensie/drivers/postgres.html#user_decoder) and
//// [`session_decoder`](/pevensie/drivers/postgres.html#session_decoder) functions
//// can be used to decode selections from the `user` and `session` tables, respectively.
////
//// The [`user_select_fields`](/pevensie/drivers/postgres.html#user_select_fields)
//// and [`session_select_fields`](/pevensie/drivers/postgres.html#session_select_fields)
//// variables contain the SQL used to select fields from the `user` and `session`
//// tables for use with the `user_decoder` and `session_decoder` functions.

import argv
import birl.{type Time}
import decode
import filepath
import gleam/bit_array
import gleam/crypto
import gleam/dynamic.{
  type DecodeErrors as DynamicDecodeErrors, type Decoder,
  DecodeError as DynamicDecodeError,
}
import gleam/erlang
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/pgo.{type QueryError as PgoQueryError}
import gleam/result
import gleam/set
import gleam/string
import glint
import glint/constraint
import pevensie/auth.{
  type AuthDriver, type OneTimeTokenType, AuthDriver, PasswordReset,
}
import pevensie/cache.{type CacheDriver, CacheDriver}
import pevensie/internal/encode.{type Encoder}
import pevensie/net.{type IpAddress}
import pevensie/session.{type Session, Session}
import pevensie/user.{
  type UpdateField, type User, type UserInsert, type UserSearchFields,
  type UserUpdate, Ignore, Set, User, app_metadata_encoder,
}
import simplifile
import snag

/// An IP version for a [`PostgresConfig`](#PostgresConfig).
pub type IpVersion {
  Ipv4
  Ipv6
}

/// Configuration for connecting to a Postgres database.
///
/// Use the [`default_config`](/pevensie/drivers/postgres.html#default_config)
/// function to get a default configuration for connecting to a local
/// Postgres database with sensible concurrency defaults.
///
/// ```gleam
/// import pevensie/drivers/postgres.{type PostgresConfig}
///
/// pub fn main() {
///   let config = PostgresConfig(
///     ..postgres.default_config(),
///     host: "db.pevensie.dev",
///     database: "my_database",
///   )
///   // ...
/// }
/// ```
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

/// The Postgres driver.
pub opaque type Postgres {
  Postgres(config: pgo.Config, conn: Option(pgo.Connection))
}

/// Returns a default [`PostgresConfig`](#PostgresConfig) for connecting to a local
/// Postgres database.
///
/// Can also be used to provide sensible concurrency defaults for connecting
/// to a remote database.
///
/// ```gleam
/// import pevensie/drivers/postgres.{type PostgresConfig}
///
/// pub fn main() {
///   let config = PostgresConfig(
///     ..postgres.default_config(),
///     host: "db.pevensie.dev",
///     database: "my_database",
///   )
///   // ...
/// }
/// ```
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

// ----- Auth Driver ----- //

/// Creates a new [`AuthDriver`](/pevensie/drivers/drivers.html#AuthDriver) for use with
/// the [`pevensie/auth.new`](/pevensie/auth.html#new) function.
///
/// ```gleam
/// import pevensie/drivers/postgres.{type PostgresConfig}
/// import pevensie/auth.{type PevensieAuth}
///
/// pub fn main() {
///   let config = PostgresConfig(
///     ..postgres.default_config(),
///     host: "db.pevensie.dev",
///     database: "my_database",
///   )
///   let driver = postgres.new_auth_driver(config)
///   let pevensie_auth = auth.new(
///     driver:,
///     user_metadata_decoder:,
///     user_metadata_encoder:,
///     cookie_key: "super secret signing key",
///   )
///   // ...
/// }
/// ```
pub fn new_auth_driver(
  config: PostgresConfig,
) -> AuthDriver(Postgres, user_metadata) {
  AuthDriver(
    driver: Postgres(config |> postgres_config_to_pgo_config, None),
    connect: connect,
    disconnect: disconnect,
    list_users: fn(driver, limit, offset, user_search_fields, decoder) {
      list_users(driver, limit, offset, user_search_fields, decoder)
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
    update_user: fn(
      driver,
      field,
      value,
      user,
      user_metadata_decoder,
      user_metadata_encoder,
    ) {
      update_user(
        driver,
        field,
        value,
        user,
        user_metadata_decoder,
        user_metadata_encoder,
      )
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    delete_user: fn(driver, field, value, user_metadata_decoder) {
      delete_user(driver, field, value, user_metadata_decoder)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    get_session: fn(driver, session_id, ip, user_agent) {
      get_session(driver, session_id, ip, user_agent)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    create_session: fn(
      driver,
      user_id,
      ip,
      user_agent,
      ttl_seconds,
      delete_other_sessions,
    ) {
      create_session(
        driver,
        user_id,
        ip,
        user_agent,
        ttl_seconds,
        delete_other_sessions,
      )
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    delete_session: fn(driver, session_id) {
      delete_session(driver, session_id)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    create_one_time_token: fn(driver, user_id, token_type, ttl_seconds) {
      create_one_time_token(driver, user_id, token_type, ttl_seconds)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    validate_one_time_token: fn(driver, user_id, token_type, token) {
      validate_one_time_token(driver, user_id, token_type, token)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    use_one_time_token: fn(driver, user_id, token_type, token) {
      use_one_time_token(driver, user_id, token_type, token)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    delete_one_time_token: fn(driver, user_id, token_type, token) {
      delete_one_time_token(driver, user_id, token_type, token)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
  )
}

// Creates a new connection pool for the given Postgres driver.
fn connect(driver: Postgres) -> Result(Postgres, Nil) {
  case driver {
    Postgres(config, None) -> {
      let conn = pgo.connect(config)

      Ok(Postgres(config, Some(conn)))
    }
    Postgres(_, Some(_)) -> Error(Nil)
  }
}

// Closes the connection pool for the given Postgres driver.
fn disconnect(driver: Postgres) -> Result(Postgres, Nil) {
  case driver {
    Postgres(config, Some(conn)) -> {
      let _ = pgo.disconnect(conn)
      Ok(Postgres(config, None))
    }
    Postgres(_, None) -> Error(Nil)
  }
}

/// Errors that can occur when interacting with the Postgres driver.
/// Will probably be removed or changed - haven't decided on the final API yet.
pub type PostgresError {
  NotFound
  QueryError(PgoQueryError)
  DecodeError(DynamicDecodeErrors)
  InternalError(String)
}

/// The SQL used to select fields from the `user` table.
pub const user_select_fields = "
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

/// A decoder for the `user` table. Requires use of the
/// [`user_select_fields`](#user_select_fields) when querying.
pub fn user_decoder(
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

      use app_metadata_data <- result.try(
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
        id:,
        created_at:,
        updated_at:,
        deleted_at:,
        role:,
        email:,
        password_hash:,
        email_confirmed_at:,
        phone_number:,
        phone_number_confirmed_at:,
        last_sign_in:,
        app_metadata: user.new_app_metadata(app_metadata_data),
        user_metadata:,
        banned_until:,
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

fn list_users(
  driver: Postgres,
  limit: Int,
  offset: Int,
  filters: UserSearchFields,
  using user_metadata_decoder: Decoder(user_metadata),
) -> Result(List(User(user_metadata)), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let filter_fields =
    [
      #("id", filters.id),
      #("email", filters.email),
      #("phone_number", filters.phone_number),
    ]
    |> list.filter(fn(field) { option.is_some(field.1) })
    |> list.index_map(fn(field, index) {
      #(
        // Filter SQL
        field.0 <> " like any($" <> int.to_string(index + 1) <> ")",
        // Filter values
        field.1 |> option.unwrap([]) |> pgo.array,
      )
    })

  let filter_sql =
    filter_fields
    |> list.map(pair.first)
    |> string.join(" or ")

  let sql = "
    select
      " <> user_select_fields <> "
    from pevensie.\"user\"
    where " <> filter_sql <> " and deleted_at is null
    limit " <> int.to_string(limit) <> "
    offset " <> int.to_string(offset)

  let query_result =
    pgo.execute(
      sql,
      conn,
      filter_fields |> list.map(pair.second),
      user_decoder(user_metadata_decoder),
    )
    |> result.map_error(QueryError)

  query_result |> result.map(fn(response) { response.rows })
}

fn insert_user(
  driver: Postgres,
  user: UserInsert(user_metadata),
  decoder user_metadata_decoder: Decoder(user_metadata),
  encoder user_metadata_encoder: Encoder(user_metadata),
) -> Result(User(user_metadata), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql = "
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
      " <> user_select_fields

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
        pgo.text(app_metadata_encoder(user.app_metadata) |> json.to_string),
        pgo.text(user_metadata_encoder(user.user_metadata) |> json.to_string),
      ],
      user_decoder(user_metadata_decoder),
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [user] -> Ok(user)
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

fn update_field_to_sql(
  field: UpdateField(a),
  sql_type: fn(a) -> pgo.Value,
) -> UpdateField(pgo.Value) {
  case field {
    Set(value) -> Set(sql_type(value))
    Ignore -> Ignore
  }
}

fn update_user(
  driver: Postgres,
  field: String,
  value: String,
  user: UserUpdate(user_metadata),
  decoder user_metadata_decoder: Decoder(user_metadata),
  encoder user_metadata_encoder: Encoder(user_metadata),
) -> Result(User(user_metadata), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let optional_timestamp_to_pgo = fn(timestamp: Option(Time)) -> pgo.Value {
    timestamp
    |> option.map(birl.to_erlang_datetime)
    |> pgo.nullable(pgo.timestamp, _)
  }

  let record_to_pgo = fn(record: a, encoder: Encoder(a)) -> pgo.Value {
    pgo.text(encoder(record) |> json.to_string)
  }

  // Create a list of fields to update, filter by those that are set,
  // then create SQL to update those fields.
  let fields: List(#(String, UpdateField(pgo.Value))) = [
    #("role", update_field_to_sql(user.role, pgo.nullable(pgo.text, _))),
    #("email", update_field_to_sql(user.email, pgo.text)),
    #(
      "password_hash",
      update_field_to_sql(user.password_hash, pgo.nullable(pgo.text, _)),
    ),
    #(
      "email_confirmed_at",
      update_field_to_sql(user.email_confirmed_at, optional_timestamp_to_pgo),
    ),
    #(
      "phone_number",
      update_field_to_sql(user.phone_number, pgo.nullable(pgo.text, _)),
    ),
    #(
      "phone_number_confirmed_at",
      update_field_to_sql(
        user.phone_number_confirmed_at,
        optional_timestamp_to_pgo,
      ),
    ),
    #(
      "last_sign_in",
      update_field_to_sql(user.last_sign_in, optional_timestamp_to_pgo),
    ),
    #(
      "app_metadata",
      update_field_to_sql(user.app_metadata, record_to_pgo(
        _,
        app_metadata_encoder,
      )),
    ),
    #(
      "user_metadata",
      update_field_to_sql(user.user_metadata, record_to_pgo(
        _,
        user_metadata_encoder,
      )),
    ),
  ]

  let fields_to_update =
    fields
    |> list.filter_map(fn(field) {
      case field.1 {
        Set(value) -> Ok(#(field.0, value))
        Ignore -> Error(Nil)
      }
    })

  let field_setters =
    fields_to_update
    |> list.index_map(fn(field, index) {
      field.0 <> " = $" <> int.to_string(index + 1)
    })
    |> string.join(", ")

  // Add the updated_at field to the list of fields to update
  let field_setters = case field_setters {
    "" -> "updated_at = now()"
    _ -> field_setters <> ", updated_at = now()"
  }

  let update_values =
    fields_to_update
    |> list.map(pair.second)

  let sql = "
    update pevensie.\"user\"
    set " <> field_setters <> "
    where " <> field <> " = $" <> int.to_string(
      list.length(fields_to_update) + 1,
    ) <> " and deleted_at is null
    returning " <> user_select_fields

  let query_result =
    pgo.execute(
      sql,
      conn,
      list.append(update_values, [pgo.text(value)]),
      user_decoder(user_metadata_decoder),
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

fn delete_user(
  driver: Postgres,
  field: String,
  value: String,
  decoder user_metadata_decoder: Decoder(user_metadata),
) -> Result(User(user_metadata), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql = "
    update pevensie.\"user\"
    set deleted_at = now()
    where " <> field <> " = $1 and deleted_at is null
    returning " <> user_select_fields

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(value)],
      user_decoder(user_metadata_decoder),
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

/// The SQL used to select fields from the `session` table.
pub const session_select_fields = "
  id::text,
  user_id::text,
  (extract(epoch from created_at) * 1000000)::bigint as created_at,
  (extract(epoch from expires_at) * 1000000)::bigint as expires_at,
  host(ip)::text,
  user_agent
"

/// A decoder for the `session` table. Requires use of the
/// [`session_select_fields`](#session_select_fields) when querying.
pub fn session_decoder() -> Decoder(Session) {
  fn(data) {
    decode.into({
      use id <- decode.parameter
      use user_id <- decode.parameter
      use created_at_tuple <- decode.parameter
      use expires_at_tuple <- decode.parameter
      use ip_string <- decode.parameter
      use user_agent <- decode.parameter

      let created_at = birl.from_unix_micro(created_at_tuple)
      let expires_at = case expires_at_tuple {
        None -> None
        Some(expires_at_tuple) -> Some(birl.from_unix_micro(expires_at_tuple))
      }

      use ip <- result.try(case ip_string {
        None -> Ok(None)
        Some(ip_string) -> {
          net.parse_ip_address(ip_string)
          |> result.map_error(fn(_) {
            [
              dynamic.DecodeError(
                expected: "IP address",
                found: ip_string,
                path: [],
              ),
            ]
          })
          |> result.map(Some)
        }
      })

      Ok(Session(id:, created_at:, expires_at:, user_id:, ip:, user_agent:))
    })
    |> decode.field(0, decode.string)
    |> decode.field(1, decode.string)
    |> decode.field(2, decode.int)
    |> decode.field(3, decode.optional(decode.int))
    |> decode.field(4, decode.optional(decode.string))
    |> decode.field(5, decode.optional(decode.string))
    |> decode.from(data)
    |> result.flatten
  }
}

fn get_session(
  driver: Postgres,
  session_id: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
) -> Result(Option(Session), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql = "
    select
      " <> session_select_fields <> ",
      -- Returns true only if the exporation time is
      -- set and has passed
      (expires_at is not null and expires_at < now()) as expired
    from pevensie.\"session\"
    where id = $1
    "

  let additional_fields = [
    #(
      case ip {
        None -> "ip is $"
        Some(_) -> "ip = $"
      },
      pgo.nullable(pgo.text, ip |> option.map(net.format_ip_address)),
    ),
    #(
      case user_agent {
        None -> "user_agent is $"
        Some(_) -> "user_agent = $"
      },
      pgo.nullable(pgo.text, user_agent),
    ),
  ]

  let sql =
    list.index_fold(additional_fields, sql, fn(sql, field, index) {
      sql <> " and " <> field.0 <> int.to_string(index + 2)
    })

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.text(session_id),
        pgo.nullable(pgo.text, ip |> option.map(net.format_ip_address)),
        pgo.nullable(pgo.text, user_agent),
      ],
      dynamic.decode2(
        fn(session, expired) { #(session, expired) },
        session_decoder(),
        dynamic.element(1, dynamic.bool),
      ),
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Ok(None)
    // If no expiration is set, the value is valid forever
    [#(session, False)] -> Ok(Some(session))
    // If the value has expired, return None and delete the session
    // in an async task
    [#(_, True)] -> {
      process.start(fn() { delete_session(driver, session_id) }, False)
      Ok(None)
    }
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

// > Note: thir may become part of the public driver API in the future
fn delete_sessions_for_user(
  driver: Postgres,
  user_id: String,
  except ignored_session_id: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    delete from pevensie.\"session\"
    where user_id = $1 and id != $2
    returning id
  "

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(user_id), pgo.text(ignored_session_id)],
      dynamic.dynamic,
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn create_session(
  driver: Postgres,
  user_id: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
  ttl_seconds: Option(Int),
  delete_other_sessions: Bool,
) -> Result(Session, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let expires_at_sql = case ttl_seconds {
    None -> "null"
    Some(ttl_seconds) ->
      "now() + interval '" <> int.to_string(ttl_seconds) <> " seconds'"
  }

  // inet is a weird type and doesn't work with pgo,
  // so we have to cast it to text.
  // This is fine because the `IpAddress` type is guaranteed
  // to be a valid IP address, so there's no chance of
  // SQL injection.
  let ip_string = case ip {
    None -> "null"
    Some(ip) -> "'" <> net.format_ip_address(ip) <> "'::inet"
  }

  let _ = net.parse_ip_address("127.0.0.1")

  let sql = "
    insert into pevensie.\"session\" (
      user_id,
      ip,
      user_agent,
      expires_at
    ) values (
      $1,
      " <> ip_string <> ",
      $2,
      " <> expires_at_sql <> "
    )
    returning
      " <> session_select_fields

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.text(user_id),
        // pgo.nullable(pgo.text, ip |> option.map(net.format_ip_address)),
        pgo.nullable(pgo.text, user_agent),
      ],
      session_decoder(),
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Error(NotFound)
    [session] -> {
      case delete_other_sessions {
        True -> {
          use _ <- result.try(delete_sessions_for_user(
            driver,
            user_id,
            session.id,
          ))
          Ok(session)
        }
        False -> Ok(session)
      }
    }
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

fn delete_session(
  driver: Postgres,
  session_id: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    delete from pevensie.\"session\"
    where id = $1
    returning id
      "

  let query_result =
    pgo.execute(sql, conn, [pgo.text(session_id)], dynamic.dynamic)
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn one_time_token_type_to_prefix(token_type: OneTimeTokenType) -> String {
  case token_type {
    PasswordReset -> "pr"
  }
}

fn one_time_token_type_to_pg_enum(token_type: OneTimeTokenType) -> String {
  case token_type {
    PasswordReset -> "password-reset"
  }
}

fn create_one_time_token(
  driver: Postgres,
  user_id: String,
  token_type: OneTimeTokenType,
  ttl_seconds: Int,
) -> Result(String, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let token =
    one_time_token_type_to_prefix(token_type)
    <> { crypto.strong_random_bytes(36) |> bit_array.base64_encode(True) }
  use token_hash <- result.try(
    encode.sha256_hash(token, token)
    |> result.replace_error(InternalError("Failed to hash token")),
  )

  let sql =
    "
  insert into pevensie.one_time_token (user_id, token_type, token_hash, expires_at)
  values ($1, $2, $3, now() + interval '$4 seconds')
    "

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.text(user_id),
        pgo.text(one_time_token_type_to_pg_enum(token_type)),
        pgo.text(token_hash),
        pgo.text(int.to_string(ttl_seconds)),
      ],
      dynamic.dynamic,
    )
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(token)
    Error(err) -> Error(err)
  }
}

fn validate_one_time_token(
  driver: Postgres,
  user_id: String,
  token_type: OneTimeTokenType,
  token: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  use token_hash <- result.try(
    encode.sha256_hash(token, token)
    |> result.replace_error(InternalError("Failed to hash token")),
  )

  let sql =
    "
  select id from pevensie.one_time_token
  where user_id = $1
    and token_type = $2
    and token_hash = $3
    and deleted_at is null
    and used_at is null
    and expires_at < now() -- USE THIS TO CREATE AN ERROR LATER?
    "

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.text(user_id),
        pgo.text(one_time_token_type_to_pg_enum(token_type)),
        pgo.text(token_hash),
      ],
      dynamic.dynamic,
    )
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn use_one_time_token(
  driver: Postgres,
  user_id: String,
  token_type: OneTimeTokenType,
  token: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  use token_hash <- result.try(
    encode.sha256_hash(token, token)
    |> result.replace_error(InternalError("Failed to hash token")),
  )

  let sql =
    "
  update from pevensie.one_time_token
  set used_at = now()
  where user_id = $1
    and token_type = $2
    and token_hash = $3
    and deleted_at is null
    and used_at is null
    and expires_at < now() -- USE THIS TO CREATE AN ERROR LATER?
  returning id
    "

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.text(user_id),
        pgo.text(one_time_token_type_to_pg_enum(token_type)),
        pgo.text(token_hash),
      ],
      dynamic.dynamic,
    )
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn delete_one_time_token(
  driver: Postgres,
  user_id: String,
  token_type: OneTimeTokenType,
  token: String,
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  use token_hash <- result.try(
    encode.sha256_hash(token, token)
    |> result.replace_error(InternalError("Failed to hash token")),
  )

  let sql =
    "
  update from pevensie.one_time_token
  set deleted_at = now()
  where user_id = $1
    and token_type = $2
    and token_hash = $3
  returning id
    "

  let query_result =
    pgo.execute(
      sql,
      conn,
      [
        pgo.text(user_id),
        pgo.text(one_time_token_type_to_pg_enum(token_type)),
        pgo.text(token_hash),
      ],
      dynamic.dynamic,
    )
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

// ----- Cache Driver ----- //

/// Creates a new [`CacheDriver`](/pevensie/drivers/drivers.html#CacheDriver) for use with
/// the [`pevensie/cache.new`](/pevensie/cache.html#new) function.
///
/// ```gleam
/// import pevensie/drivers/postgres.{type PostgresConfig}
/// import pevensie/cache.{type PevensieCache}
///
/// pub fn main() {
///   let config = PostgresConfig(
///     ..postgres.default_config(),
///     host: "db.pevensie.dev",
///     database: "my_database",
///   )
///   let driver = postgres.new_cache_driver(config)
///   let pevensie_cache = cache.new(driver)
///   // ...
/// }
/// ```
pub fn new_cache_driver(config: PostgresConfig) -> CacheDriver(Postgres) {
  CacheDriver(
    driver: Postgres(config |> postgres_config_to_pgo_config, None),
    connect: connect,
    disconnect: disconnect,
    store: fn(driver, resource_type, key, value, ttl_seconds) {
      store_in_cache(driver, resource_type, key, value, ttl_seconds)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    get: fn(driver, resource_type, key) {
      get_from_cache(driver, resource_type, key)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
    delete: fn(driver, resource_type, key) {
      delete_from_cache(driver, resource_type, key)
      // TODO: Handle errors
      |> result.map_error(fn(err) {
        io.debug(err)
        Nil
      })
    },
  )
}

fn store_in_cache(
  driver: Postgres,
  resource_type: String,
  key: String,
  value: String,
  ttl_seconds: Option(Int),
) -> Result(Nil, PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let expires_at_sql = case ttl_seconds {
    None -> "null"
    Some(ttl_seconds) ->
      "now() + interval '" <> int.to_string(ttl_seconds) <> " seconds'"
  }
  let sql = "
    insert into pevensie.\"cache\" (
      resource_type,
      key,
      value,
      expires_at
    ) values (
      $1,
      $2,
      $3,
      " <> expires_at_sql <> "
    )
    on conflict (resource_type, key) do update set value = $3"

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(resource_type), pgo.text(key), pgo.text(value)],
      dynamic.dynamic,
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn get_from_cache(
  driver: Postgres,
  resource_type: String,
  key: String,
) -> Result(Option(String), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql =
    "
    select
      value::text, 
      -- Returns true only if the exporation time is
      -- set and has passed
      (expires_at is not null and expires_at < now()) as expired
    from pevensie.\"cache\"
    where resource_type = $1 and key = $2"

  let query_result =
    pgo.execute(
      sql,
      conn,
      [pgo.text(resource_type), pgo.text(key)],
      dynamic.decode2(
        fn(value, expired) { #(value, expired) },
        dynamic.element(0, dynamic.string),
        dynamic.element(1, dynamic.bool),
      ),
    )
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Ok(None)
    // If no expiration is set, the value is valid forever
    [#(value, False)] -> {
      Ok(Some(value))
    }
    // If the value has expired, return None and delete the key
    // in an async task
    [#(_, True)] -> {
      process.start(
        fn() { delete_from_cache(driver, resource_type, key) },
        False,
      )
      Ok(None)
    }
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

fn delete_from_cache(
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
    pgo.execute(
      sql,
      conn,
      [pgo.text(resource_type), pgo.text(key)],
      dynamic.dynamic,
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

// ----- Migration function ----- //
fn modules_flag() -> glint.Flag(List(String)) {
  glint.strings_flag("modules")
  |> glint.flag_help("The Pevensie modules to migrate")
  |> glint.flag_constraint(
    constraint.one_of(["auth", "cache"]) |> constraint.each,
  )
}

fn add_error_context(error: String, context: String) {
  context <> ": " <> error
}

fn check_pevensie_schema_exists(tx: pgo.Connection) -> Result(Bool, String) {
  let query_result =
    pgo.execute(
      "select schema_name from information_schema.schemata where schema_name = 'pevensie'",
      tx,
      [],
      dynamic.element(0, of: dynamic.string),
    )
    |> result.map_error(string.inspect)

  use response <- result.try(query_result)
  case response.rows {
    [_] -> Ok(True)
    [] -> Ok(False)
    _ -> Error("Too many rows")
  }
}

fn get_module_version(
  tx: pgo.Connection,
  module: String,
) -> Result(Option(String), String) {
  let query_result =
    pgo.execute(
      // pgo no like enums
      "select version::text from pevensie.module_version where module = '"
        <> module
        <> "' limit 1",
      tx,
      [],
      dynamic.element(0, of: dynamic.string),
    )
    |> result.map_error(string.inspect)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Ok(None)
    [version] -> Ok(Some(version))
    _ -> Error("Too many rows")
  }
}

fn get_migrations_for_module(module: String) -> Result(List(String), String) {
  use priv <- result.try(
    erlang.priv_directory("pevensie")
    |> result.replace_error("Couldn't get priv directory"),
  )

  let assert Ok(directory) =
    [priv, "drivers", "postgres", "migrations", module]
    |> list.reduce(filepath.join)

  simplifile.get_files(directory)
  |> result.map_error(fn(err) {
    err
    |> string.inspect
    |> add_error_context("Unable to get files in priv directory")
  })
}

fn version_from_filename(filename: String) {
  let assert Ok(filename) = filename |> filepath.split |> list.last
  string.replace(filename, ".sql", "")
}

fn get_migrations_to_apply_for_module(
  module: String,
  current_version: Option(String),
) -> Result(List(String), String) {
  use files <- result.try(
    get_migrations_for_module(module)
    |> result.map_error(add_error_context(
      _,
      "Failed to get migrations for '" <> module <> "' module",
    )),
  )

  case current_version {
    None -> Ok(files)
    Some(current_version) -> {
      files
      |> list.filter(fn(file) {
        string.compare(version_from_filename(file), current_version) == order.Gt
      })
      |> Ok
    }
  }
}

fn apply_migrations_for_module(
  tx: pgo.Connection,
  module: String,
  migrations: List(String),
) -> Result(Nil, String) {
  let num_migrations = list.length(migrations)

  case num_migrations {
    0 -> {
      io.println("No migrations to apply for module '" <> module <> "'\n")
      Ok(Nil)
    }
    _ -> {
      io.println(
        "Applying "
        <> int.to_string(num_migrations)
        <> " migrations for module '"
        <> module
        <> "'",
      )
      let migration_result =
        migrations
        |> list.try_each(fn(migration) {
          io.print("Applying " <> version_from_filename(migration) <> ".sql...")
          use sql <- result.try(
            simplifile.read(migration)
            |> result.map_error(fn(err) {
              err
              |> string.inspect
              |> add_error_context("Unable to apply migration " <> migration)
            }),
          )
          use last_char <- result.try(
            string.last(sql |> string.trim_right)
            |> result.replace_error("Empty migratino file"),
          )

          let sql = case last_char {
            ";" -> sql
            _ -> sql <> ";"
          }
          // pgo doesn't allow executing multiple statements, so
          // wrap in a do block
          let sql =
            "do $pevensiemigration$ begin" <> sql <> " end;$pevensiemigration$"

          let query_result =
            pgo.execute(sql, tx, [], fn(_) { Ok(Nil) })
            |> result.map_error(string.inspect)

          use _ <- result.try(query_result)
          io.println("ok.")
          Ok(Nil)
        })

      use _ <- result.try(migration_result)
      let assert Ok(latest_migration) = list.last(migrations)
      let new_version = version_from_filename(latest_migration)
      let assert [Ok(y), Ok(m), Ok(d)] =
        new_version |> string.split("-") |> list.map(int.parse)
      let new_version_date = #(y, m, d)

      io.print(
        "Updating module '" <> module <> "' version to " <> new_version <> "...",
      )
      let query_result =
        // pgo doesn't like enums, so insert it manually
        pgo.execute("
          insert into pevensie.module_version (module, version)
          values ('" <> module <> "', $1)
          on conflict (module)
          do update set version = $2
          ", tx, [pgo.date(new_version_date), pgo.date(new_version_date)], dynamic.dynamic)
        |> result.map_error(string.inspect)

      use _ <- result.try(query_result)
      io.println("ok.")
      io.println("Done applying migrations for module '" <> module <> "'\n")
      Ok(Nil)
    }
  }
}

fn handle_base_migration(tx: pgo.Connection) -> Result(Nil, String) {
  io.print("Checking schema... ")
  use schema_exists <- result.try(
    check_pevensie_schema_exists(tx)
    |> result.map_error(add_error_context(
      _,
      "Unable to check if 'pevensie' schema exists",
    )),
  )
  io.println("ok.")

  io.print("Checking current version of 'base' module... ")
  let base_version_result = case schema_exists {
    False -> Ok(None)
    True ->
      get_module_version(tx, "base")
      |> result.map_error(add_error_context(
        _,
        "Unable to check 'base' module version",
      ))
  }

  use current_base_version <- result.try(base_version_result)
  io.println(
    "ok. Current version: " <> current_base_version |> option.unwrap("none"),
  )

  io.print("Getting migrations for module 'base'... ")
  use base_migrations <- result.try(
    get_migrations_to_apply_for_module("base", current_base_version)
    |> result.map_error(add_error_context(
      _,
      "Failed to get migrations to apply for 'base'",
    )),
  )
  io.println("ok.")

  apply_migrations_for_module(tx, "base", base_migrations)
  |> result.map_error(add_error_context(
    _,
    "Failed to apply migrations for 'base'",
  ))
}

fn handle_module_migration(
  tx: pgo.Connection,
  module: String,
) -> Result(Nil, String) {
  io.print("Checking current version of '" <> module <> "' module... ")
  use current_version <- result.try(
    get_module_version(tx, module)
    |> result.map_error(add_error_context(
      _,
      "Unable to check '" <> module <> "' module version",
    )),
  )

  io.println(
    "ok. Current version: " <> current_version |> option.unwrap("none"),
  )

  io.print("Getting migrations for module '" <> module <> "'... ")
  use migrations <- result.try(
    get_migrations_to_apply_for_module(module, current_version)
    |> result.map_error(add_error_context(
      _,
      "Failed to get migrations to apply for '" <> module <> "'",
    )),
  )
  io.println("ok.")

  apply_migrations_for_module(tx, module, migrations)
  |> result.map_error(add_error_context(
    _,
    "Failed to apply migrations for '" <> module <> "'",
  ))
}

fn migrate_command() {
  use connection_string_arg <- glint.named_arg("connection string")
  use modules_arg <- glint.flag(modules_flag())

  use named, _, flags <- glint.command()
  let connection_string = connection_string_arg(named)
  use modules <- result.try(modules_arg(flags))
  // Deduplicate modules
  let modules = modules |> set.from_list |> set.to_list

  use config <- result.try(
    pgo.url_config(connection_string)
    |> result.replace_error(
      snag.Snag(issue: "Invalid Postgres connection string", cause: [
        "invalid connection string",
      ]),
    ),
  )
  let conn = pgo.connect(config)
  let transaction_result =
    pgo.transaction(conn, fn(tx) {
      use _ <- result.try(handle_base_migration(tx))

      let migration_result =
        modules
        |> list.try_each(handle_module_migration(tx, _))

      use _ <- result.try(migration_result)
      io.println(
        "\nSuccess! Applied migrations for modules: "
        <> modules |> string.join(","),
      )
      Ok(Nil)
    })
  case transaction_result {
    Ok(_) -> Ok(Nil)
    Error(pgo.TransactionRolledBack(msg)) ->
      Error(snag.Snag(issue: msg, cause: ["transaction rolled back"]))
    Error(pgo.TransactionQueryError(err)) ->
      Error(
        snag.Snag(issue: "Query error: " <> string.inspect(err), cause: [
          "query error",
        ]),
      )
  }
}

pub fn main() {
  let cli =
    glint.new()
    |> glint.with_name("pevensie/drivers/postgres")
    |> glint.pretty_help(glint.default_pretty_help())
    |> glint.add(at: ["migrate"], do: migrate_command())

  use cli_result <- glint.run_and_handle(cli, argv.load().arguments)
  use errors <- result.map_error(cli_result)
  io.println("Command failed with an error: " <> errors.issue)
}
