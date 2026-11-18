///|
#derive(Debug)
struct MatchResult {
  success : Bool
  captures : Array[String]
  named_captures : Map[String, String]
}

///|
pub fn MatchResult::success(self : MatchResult) -> Bool {
  self.success
}

///|
pub fn MatchResult::captures(self : MatchResult) -> Array[String] {
  self.captures
}

///|
pub fn MatchResult::named_captures(self : MatchResult) -> Map[String, String] {
  self.named_captures
}

///|
test "get captures" {
  let res = {
    success: true,
    captures: ["123456789", "123", "456", "789"],
    named_captures: { "a": "123", "b": "456", "c": "789" },
  }
  inspect(res.success(), content="true")
  inspect(
    Repr(res.captures),
    content=(
      #|["123456789", "123", "456", "789"]
    ),
  )
  inspect(
    format_capture_names(res.named_captures()),
    content=(
      #|{"a": "123", "b": "456", "c": "789"}
    ),
  )
}

///|
pub impl Show for MatchResult with fn output(self, logger) {
  logger.write_string(
    "{success: \{self.success}, captures: \{format_captures(self.captures)}, named_captures: \{format_capture_names(self.named_captures)}}",
  )
}

///|
fn quote_capture(value : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in value {
    match c {
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      c =>
        if c.to_int() < 32 || c.to_int() == 127 {
          out.write_string("\\x")
          if c.to_int() < 16 {
            out.write_char('0')
          }
          out.write_string(c.to_int().to_string(radix=16))
        } else {
          out.write_char(c)
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn format_captures(values : Array[String]) -> String {
  "[" + values.map(quote_capture).join(", ") + "]"
}

///|
fn format_capture_names(values : Map[String, String]) -> String {
  "{" +
  values
  .iter()
  .map(fn(pair) {
    let (k, v) = pair
    quote_capture(k) + ": " + quote_capture(v)
  })
  .collect()
  .join(", ") +
  "}"
}
