import birl.{type Time}
import decode
import gleam/dynamic.{
  type DecodeErrors as DynamicDecodeErrors, type Decoder,
  DecodeError as DynamicDecodeError,
}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/pgo.{type QueryError as PgoQueryError}
import gleam/result
import gleam/string
import pevensie/drivers.{
  type AuthDriver, type CacheDriver, AuthDriver, CacheDriver,
}
import pevensie/internal/encoder.{type Encoder}
import pevensie/net.{type IpAddress}
import pevensie/session.{type Session, Session}
import pevensie/user.{
  type UpdateField, type User, type UserInsert, type UserSearchFields,
  type UserUpdate, Ignore, Set, User, app_metadata_encoder,
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
    list_users: fn(driver, user_search_fields, decoder) {
      list_users(driver, user_search_fields, decoder)
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

const user_select_fields = "
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
    |> string.join(" and ")

  let sql = "
    select
      " <> user_select_fields <> "
    from pevensie.\"user\"
    where " <> filter_sql <> " and deleted_at is null"

  let query_result =
    pgo.execute(
      sql,
      conn,
      filter_fields |> list.map(pair.second),
      postgres_user_decoder(user_metadata_decoder),
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
      postgres_user_decoder(user_metadata_decoder),
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

const session_select_fields = "
  id::text,
  user_id::text,
  (extract(epoch from created_at) * 1000000)::bigint as created_at,
  (extract(epoch from expires_at) * 1000000)::bigint as expires_at,
  host(ip)::text,
  user_agent
"

fn postgres_session_decoder() -> Decoder(Session) {
  fn(data) {
    io.debug(data)
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

pub fn get_session(
  driver: Postgres,
  session_id: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
) -> Result(Option(Session), PostgresError) {
  let assert Postgres(_, Some(conn)) = driver

  let sql = "
    select
      " <> session_select_fields <> "
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
      postgres_session_decoder(),
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  use response <- result.try(query_result)
  case response.rows {
    [] -> Ok(None)
    [session] -> Ok(Some(session))
    _ -> Error(InternalError("Unexpected number of rows returned"))
  }
}

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
      fn(_) { Ok(json.null()) },
    )
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

pub fn create_session(
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

  let _ =
    net.parse_ip_address("127.0.0.1")
    |> io.debug

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
      postgres_session_decoder(),
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

pub fn delete_session(
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
    pgo.execute(sql, conn, [pgo.text(session_id)], fn(_) { Ok(json.null()) })
    // TODO: Handle errors
    |> result.map_error(QueryError)

  case query_result {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

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
      fn(_) { Ok(json.null()) },
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
