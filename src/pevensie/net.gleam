//// `pevensie/net` contains convencience functions for working with
//// IP addresses and other networking-related tasks.

import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/charlist.{type Charlist}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// An IP address. Can be either an IPv4 or IPv6 address. Data is stored
/// as a record of integers. To display an IP address, use the
/// [`format_ip_address`](#format_ip_address) function.
pub type IpAddress {
  IpV4(Int, Int, Int, Int)
  IpV6(Int, Int, Int, Int, Int, Int, Int, Int)
}

// These accept Erlang `string()`s, which are not the same as Gleam `String`s.
// We convert them to Erlang `string()`s (equivalent to `charlist.Charlist`s
// where each element is a single character) before passing them to the
// Erlang function.
@external(erlang, "inet", "parse_ipv4_address")
fn inet_parse_ipv4(ip: Charlist) -> Result(#(Int, Int, Int, Int), Atom)

@external(erlang, "inet", "parse_ipv6_address")
fn inet_parse_ipv6(
  ip: Charlist,
) -> Result(#(Int, Int, Int, Int, Int, Int, Int, Int), Atom)

fn parse_ipv4(ip: String) -> Result(IpAddress, Nil) {
  ip
  |> charlist.from_string
  |> inet_parse_ipv4
  |> result.map(fn(ip) { IpV4(ip.0, ip.1, ip.2, ip.3) })
  |> result.replace_error(Nil)
}

fn parse_ipv6(ip: String) -> Result(IpAddress, Nil) {
  ip
  |> charlist.from_string
  |> inet_parse_ipv6
  |> result.map(fn(ip) { IpV6(ip.0, ip.1, ip.2, ip.3, ip.4, ip.5, ip.6, ip.7) })
  |> result.replace_error(Nil)
}

/// Parses an IP address from a string. Returns an error if the string
/// is not a valid IP address. Accepts relaxed IPv4 and IPv6 formats,
/// such as `127.1` and `2001:db8::1`.
pub fn parse_ip_address(ip: String) -> Result(IpAddress, Nil) {
  parse_ipv4(ip)
  |> result.lazy_or(fn() { parse_ipv6(ip) })
}

/// A decoder to get an IP address from a string.
pub fn ip_address_decoder() -> Decoder(IpAddress) {
  use ip_addr_string <- decode.then(decode.string)
  case parse_ip_address(ip_addr_string) {
    Ok(ip) -> decode.success(ip)
    Error(_) -> decode.failure(IpV4(0, 0, 0, 0), "IpAddress")
  }
}

/// Formats an IP address as a string. This is useful for displaying
/// IP addresses in a user-friendly way, or for inserting them into
/// a database.
pub fn format_ip_address(ip: IpAddress) -> String {
  case ip {
    IpV4(a, b, c, d) -> {
      [a, b, c, d]
      |> list.map(int.to_string)
      |> string.join(".")
    }
    IpV6(a, b, c, d, e, f, g, h) -> {
      [a, b, c, d, e, f, g, h]
      |> list.map(fn(value) {
        case value {
          0 -> ""
          _ -> int.to_base16(value)
        }
      })
      |> string.join(":")
    }
  }
}
