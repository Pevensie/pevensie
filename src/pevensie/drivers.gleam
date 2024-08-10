import gleam/option.{type Option, None}
import gleam/pgo
import pevensie/internal/drivers.{type AuthDriver, PostgresAuthDriver}

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

pub fn default_postgres_config() -> PostgresConfig {
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

pub fn new_postgres_auth_driver(config: PostgresConfig) -> AuthDriver {
  PostgresAuthDriver(config |> postgres_config_to_pgo_config, None)
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
