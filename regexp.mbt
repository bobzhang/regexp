///|
struct RegExp {
  pattern : String
  prog : Program
}

///|
fn RegExp::new(pattern : String) -> RegExp raise {
  let ast = Parser::new(pattern).parse()
  let prog = Emitter::new(ast).emit()
  { pattern, prog, }
}

///|
pub fn compile(pattern : String) -> RegExp raise {
  RegExp::new(pattern)
}

///|
pub fn RegExp::pattern(self : RegExp) -> String {
  self.pattern
}

///|
pub fn RegExp::matches(
  self : RegExp,
  text : String,
  start~ : Int32 = 0,
  end~ : Int32 = text.length(),
) -> MatchResult {
  Interpreter::new(self.prog).scan(text, start, end)
}
