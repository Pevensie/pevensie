import gleam/erlang/atom.{type Atom}
import gleam/erlang/charlist.{type Charlist}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type IpAddress {
  IpV4(Int, Int, Int, Int)
  IpV6(Int, Int, Int, Int, Int, Int, Int, Int)
}

// These accept Erlang `string()`s, which are not the same as Gleam `String`s.
// We convert them to Erlang `string()`s (equivalent to Gleam `List(String)`s
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

pub fn parse_ip_address(ip: String) -> Result(IpAddress, Nil) {
  parse_ipv4(ip)
  |> result.lazy_or(fn() { parse_ipv6(ip) })
}

pub fn format_ip_address(ip: IpAddress) -> String {
  case ip {
    IpV4(a, b, c, d) -> {
      [a, b, c, d]
      |> list.map(int.to_string)
      |> string.join(".")
    }
    IpV6(a, b, c, d, e, f, g, h) -> {
      [a, b, c, d, e, f, g, h]
      |> list.map(int.to_string)
      |> string.join(":")
    }
  }
}
