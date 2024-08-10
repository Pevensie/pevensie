import birl
import decode
import gleam/dynamic.{
  type DecodeErrors as DynamicDecodeErrors, type Decoder,
  DecodeError as DynamicDecodeError,
}
import gleam/json
import gleam/option.{None, Some}
import gleam/pgo.{type Connection, type QueryError as PgoQueryError}
import gleam/result
import pevensie/internal/user.{type User, User}

pub type GetUserError {
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
  conn: Connection,
  by column: String,
  with value: String,
  using user_metadata_decoder: Decoder(user_metadata),
) -> Result(User(user_metadata), GetUserError) {
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
    where " <> column <> " = $1"

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

pub fn get_user_by_id(
  conn: Connection,
  id: String,
  user_metadata_decoder: Decoder(user_metadata),
) -> Result(User(user_metadata), GetUserError) {
  get_user(conn, by: "id", with: id, using: user_metadata_decoder)
}
