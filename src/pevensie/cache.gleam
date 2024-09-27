//// Pevensie Cache is a smiple module for caching data in your application.
//// It is designed to be easily used with all parts of Pevensie, and follows
//// the driver-based architecture.
////
//// > Important: data stored in Pevensie Cache may be lost (e.g. on restart),
//// > and is not guaranteed to be durable. Do not use Pevensie Cache for data
//// > that you need to keep indefinitely.
////
//// ## Getting Started
////
//// All you need to provide to the `new` function is your chosen driver.
////
//// ```gleam
//// import pevensie/cache.{type PevensieCache}
//// import pevensie/drivers/postgres.{type PostgresConfig}
////
//// pub fn main() {
////   let config = PostgresConfig(
////     ..postgres.default_config(),
////     database: "my_database",
////   )
////   let driver = postgres.new_cache_driver(config)
////   let pevensie_cache = cache.new(driver)
//// }
//// ```
////
//// You'll need to run the [`connect`](/pevensie/cache.html#connect) function
//// on your Pevensie Cache instance before using it. This allows your driver
//// to perform any setup required, such as creating a database connection
//// pool.
////
//// Once connected, you can use the [`set`](/pevensie/cache.html#set),
//// [`get`](/pevensie/cache.html#get), and [`delete`](/pevensie/cache.html#delete)
//// functions to store, retrieve, and delete data from the cache.
////
//// ```gleam
//// import pevensie/cache.{type PevensieCache}
////
//// pub fn main() {
////   // ...
////let assert Ok(pevensie_cache) = cache.connect(pevensie_cache)
////   cache.set(pevensie_cache, "key", "value", None)
////   cache.get(pevensie_cache, "key")
////   cache.delete(pevensie_cache, "key")
////   // ...
//// }
//// ```
////
//// ## Drivers
////
//// Pevensie Cache is designed to be driver-agnostic, so you can use any driver
//// you like. The drivers provided with Pevensie are:
////
//// - [`postgres`](/pevensie/drivers/postgres.html) - A driver for PostgreSQL
//// - [`redis`](/pevensie/drivers/redis.html) - A driver for Redis (coming soon)
//// - [`ets`](/pevensie/drivers/ets.html) - A driver for ETS, Erlang's in-memory key-value store (coming soon)
////
//// The hope is that other first- and third-party drivers will be available
//// in the future.
////
//// > Note: database-based drivers will require migrations to be run before
//// > using them. See the documentation for your chosen driver for more
//// > information.

import gleam/option.{type Option}
import gleam/result
import pevensie/drivers.{
  type CacheDriver, type Connected, type Disconnected, CacheDriver,
}

// ----- PevensieCache ----- //

/// The entrypoint to the Pevensie Cache API. This type is used when using
/// the majority of the functions in `pevensie/cache`.
///
/// You must connect your Pevensie Cache instance before using it. This
/// allows your driver to perform any setup required, such as creating
/// a database connection pool.
///
/// Create a new `PevensieCache` instance using the
/// [`new`](#new) function.
///
/// ```gleam
/// import pevensie/cache.{type PevensieCache}
///
/// pub fn main() {
///   let pevensie_cache = cache.new(
///     postgres.new_cache_driver(postgres.default_config()),
///   )
///   // ...
/// }
/// ```
pub type PevensieCache(driver, connected) {
  PevensieCache(driver: CacheDriver(driver))
}

/// Creates a new [`PevensieCache`](#PevensieCache) instance.
///
/// The `driver` argument is the driver to use for caching. Use either
/// a driver provided by Pevensie, or any third-party driver you like.
///
/// ```gleam
/// import pevensie/cache.{type PevensieCache}
///
/// pub fn main() {
///   let pevensie_cache = cache.new(
///     postgres.new_cache_driver(postgres.default_config()),
///   )
///   // ...
/// }
/// ```
pub fn new(
  driver driver: CacheDriver(cache_driver),
) -> PevensieCache(cache_driver, Disconnected) {
  PevensieCache(driver:)
}

/// Runs setup for your chosen cache driver and returns a connected
/// [`PevensieCache`](#PevensieCache) instance.
///
/// This function must be called before using any other functions in
/// the Pevensie Cache API. Attempting to use the API before calling
/// `connect` will result in a compile error.
///
/// ```gleam
/// import pevensie/cache.{type PevensieCache}
///
/// pub fn main() {
///   // ...
///   let assert Ok(pevensie_cache) = cache.connect(pevensie_cache)
///   // ...
/// }
/// ```
pub fn connect(
  pevensie_cache: PevensieCache(cache_driver, Disconnected),
) -> Result(PevensieCache(cache_driver, Connected), Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.connect(driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieCache(driver: CacheDriver(..driver, driver: internal_driver))
  })
}

/// Runs teardown for your chosen cache driver and returns a disconnected
/// [`PevensieCache`](#PevensieCache) instance.
///
/// After calling this function, you can no longer use the cache driver
/// unless you call [`connect`](#connect) again.
pub fn disconnect(
  pevensie_cache: PevensieCache(cache_driver, Connected),
) -> Result(PevensieCache(cache_driver, Disconnected), Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.disconnect(driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieCache(driver: CacheDriver(..driver, driver: internal_driver))
  })
}

// ----- Cache CRUD Functions ----- //

/// Store a value in the cache. Both the key and value must be strings.
///
/// The `resource_type` argument is used to help organize your cache. It
/// should be a string that uniquely identifies the type of data you're
/// caching. For example, if you're caching user data, you might use
/// `"user"` as the resource type.
///
/// The `ttl_seconds` argument is the number of seconds the value should
/// be stored in the cache. If `None`, the value will never expire.
///
/// ```gleam
/// import pevensie/cache.{type PevensieCache}
///
/// pub fn main() {
///   // ...
///   let assert Ok(pevensie_cache) = cache.connect(pevensie_cache)
///   let assert Ok(_) = cache.set(
///     pevensie_cache,
///     "ship",
///     "dawntreader",
///     "{\"name\": \"Dawn Treader\", \"captain\": \"Prince Caspian\"}",
///     None,
///   )
///   // ...
/// }
/// ```
pub fn set(
  pevensie_cache: PevensieCache(cache_driver, Connected),
  resource_type resource_type: String,
  key key: String,
  value value: String,
  ttl_seconds ttl_seconds: Option(Int),
) -> Result(Nil, Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.store(driver.driver, resource_type, key, value, ttl_seconds)
}

/// Retrieve a value from the cache.
pub fn get(
  pevensie_cache: PevensieCache(cache_driver, Connected),
  resource_type resource_type: String,
  key key: String,
) -> Result(Option(String), Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.get(driver.driver, resource_type, key)
}

/// Delete a value from the cache.
pub fn delete(
  pevensie_cache: PevensieCache(cache_driver, Connected),
  resource_type resource_type: String,
  key key: String,
) -> Result(Nil, Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.delete(driver.driver, resource_type, key)
}
