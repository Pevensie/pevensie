import gleam/io
import gleam/option.{Some}
import gleam/pgo
import pevensie/internal/postgres

pub fn get_user_by_id(id: String) -> Nil {
  let conn =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "192.168.1.245",
        user: "postgres",
        password: Some("postgres"),
        database: "default",
      ),
    )
  let _ =
    postgres.get_user_by_id(conn, id)
    |> io.debug
  Nil
}
