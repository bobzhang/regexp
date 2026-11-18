///|
let max_loop_count = 100_000

///|
#derive(Eq, Debug)
pub(all) suberror ParseError {
  InternalParserError
  UnmatchedGroupBegin(pos~ : Int32)
  UnmatchedGroupEnd(pos~ : Int32)
  UnmatchedGroupName(pos~ : Int32)
  EmptyGroupName(pos~ : Int32)
  EmptyGroup(pos~ : Int32)
  UnmatchedCharClassEnd(pos~ : Int32)
  UnspecifiedLoopTarget(pos~ : Int32)
  InvalidLoop(pos~ : Int32)
  LoopCountOutOfRange(pos~ : Int32)
  LoopMaxCountSmallerThanMinCount(pos~ : Int32)
  EndPatternAtEscape(pos~ : Int32)
  ClassMissingBracket(pos~ : Int32)
  GroupMissingParen(pos~ : Int32)
}

///|
priv struct Parser {
  pattern : String
  mut pos : Int32
  mut group_index : Int32
  mut capture_num : Int32
  capture_name_mapping : Map[String, Int32]
}

///|
fn Parser::new(pattern : String) -> Parser {
  { pattern, pos: 0, group_index: 0, capture_num: 0, capture_name_mapping: {}, }
}

///|
fn Parser::rewind(self : Parser, n : Int32) -> Unit {
  self.pos -= n
}

///|
fn Parser::advance(self : Parser, n : Int32) -> Unit {
  self.pos += n
}

///|
fn Parser::more(self : Parser) -> Bool {
  self.pos < self.pattern.length()
}

///|
fn Parser::peek(self : Parser) -> Char {
  if !self.more() {
    abort("index out of bounds")
  }
  self.pattern[self.pos].unsafe_to_char()
}

///|
fn Parser::peek_is(self : Parser, expected : Char) -> Bool {
  if !self.more() {
    false
  } else {
    self.peek() == expected
  }
}

///|
fn Parser::fetch_unsigned_num(self : Parser) -> Int32? {
  let num_buf = StringBuilder()
  for ;; {
    match self.peek() {
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' as d => {
        num_buf.write_char(d)
        self.advance(1)
        if self.more() {
          continue
        } else {
          break
        }
      }
      _ => break
    }
  }
  let num_str = num_buf.to_string()
  if num_str == "" {
    return None
  }
  try {
    let num = @string.parse_int(num_str)
    Some(num)
  } catch {
    _ => None
  }
}

///|
fn Parser::parse(self : Parser) -> Ast raise ParseError {
  let root = AstNode::new(Capture(index=self.group_index))
  self.group_index += 1
  self.capture_num += 1
  root.add_child(self.parse_expr(false))
  {
    root,
    capture_num: self.capture_num,
    capture_name_mapping: self.capture_name_mapping,
  }
}

///|
fn Parser::parse_expr(
  self : Parser,
  in_group : Bool,
) -> AstNode raise ParseError {
  let node = self.parse_concat(in_group)
  if !self.more() || (in_group && self.peek_is(')')) {
    return node
  } else if self.peek_is('|') {
    let alt_node = AstNode::new(Alternate)
    alt_node.add_child(node)
    while self.peek_is('|') {
      self.advance(1) // |
      alt_node.add_child(self.parse_concat(in_group))
    }
    if !in_group && self.more() {
      raise InternalParserError
    } else {
      alt_node
    }
  } else {
    raise InternalParserError
  }
}

///|
fn Parser::parse_concat(
  self : Parser,
  in_group : Bool,
) -> AstNode raise ParseError {
  let node = self.parse_node(in_group)
  if !self.more() || self.peek_is('|') || (in_group && self.peek_is(')')) {
    node
  } else {
    let concat_node = AstNode::new(Concatenate)
    concat_node.add_child(node)
    while self.more() && !self.peek_is('|') && !(in_group && self.peek_is(')')) {
      concat_node.add_child(self.parse_node(in_group))
    }
    concat_node
  }
}

///|
fn Parser::parse_node(
  self : Parser,
  in_group : Bool,
) -> AstNode raise ParseError {
  if !self.more() || (in_group && self.peek_is(')')) {
    return AstNode::new(Empty)
  }
  let node = match self.peek() {
    '|' => {
      self.advance(1)
      AstNode::new(Empty)
    }
    '.' => {
      self.advance(1)
      AstNode::new(NotSingle(char='\n'))
    }
    '^' => {
      self.advance(1)
      AstNode::new(BeginOfInput)
    }
    '$' => {
      self.advance(1)
      AstNode::new(EndOfInput)
    }
    '(' => {
      self.advance(1)
      self.parse_group()
    }
    ')' => raise UnmatchedGroupEnd(pos=self.pos)
    '[' => {
      self.advance(1)
      self.parse_class()
    }
    ']' => raise UnmatchedCharClassEnd(pos=self.pos)
    '*' | '+' | '?' | '{' | '}' => raise UnspecifiedLoopTarget(pos=self.pos)
    '\\' => {
      self.advance(1)
      self.parse_escape()
    }
    _ as char => {
      self.advance(1)
      AstNode::new(Single(char~))
    }
  }
  self.parse_loop(node)
}

///|
fn Parser::parse_loop(
  self : Parser,
  target : AstNode,
) -> AstNode raise ParseError {
  if !self.more() {
    return target
  }
  let mut greedy = true
  let mut min = 0
  let mut max : Int32? = None
  match self.peek() {
    '*' => self.advance(1)
    '+' => {
      self.advance(1)
      min = 1
    }
    '?' => {
      self.advance(1)
      max = Some(1)
    }
    '{' => {
      self.advance(1)
      let range = self.parse_loop_range()
      min = range.0
      max = range.1
    }
    _ => return target
  }
  if self.peek_is('?') {
    self.advance(1)
    greedy = false
  }
  match target.internal {
    Single(char~) => AstNode::new(SingleLoop(char~, min~, max~, greedy~))
    NotSingle(char~) => AstNode::new(NotSingleLoop(char~, min~, max~, greedy~))
    Class(class~) => AstNode::new(ClassLoop(class~, min~, max~, greedy~))
    _ => {
      let node = AstNode::new(Loop(min~, max~, greedy~))
      node.add_child(target)
      node
    }
  }
}

///|
fn Parser::parse_loop_range(self : Parser) -> (Int32, Int32?) raise ParseError {
  if !self.more() {
    raise InvalidLoop(pos=self.pos)
  }
  let min = match self.fetch_unsigned_num() {
    Some(v) => v
    None => raise InvalidLoop(pos=self.pos)
  }
  if min < 0 || min > max_loop_count {
    raise LoopCountOutOfRange(pos=self.pos)
  }
  if !self.more() {
    raise InvalidLoop(pos=self.pos)
  }
  let max : Int32? = if self.peek_is(',') {
    self.advance(1) // ','
    self.fetch_unsigned_num()
  } else {
    Some(min)
  }
  if !(max is None) && (max.unwrap() < 0 || max.unwrap() > max_loop_count) {
    raise LoopCountOutOfRange(pos=self.pos)
  }
  if !self.more() || !self.peek_is('}') {
    raise InvalidLoop(pos=self.pos)
  }
  self.advance(1) // '}'
  if !(max is None) && min > max.unwrap() {
    raise LoopMaxCountSmallerThanMinCount(pos=self.pos)
  }
  (min, max)
}

///|
fn Parser::parse_group(self : Parser) -> AstNode raise ParseError {
  if !self.more() {
    raise UnmatchedGroupBegin(pos=self.pos)
  }
  let mut capture = true
  let mut name = ""
  let index = self.group_index
  self.group_index += 1
  self.capture_num += 1
  if self.peek_is('?') {
    self.advance(1) // '?'
    match self.peek() {
      ':' => {
        capture = false
        self.capture_num -= 1
        self.advance(1) // ':'
      }
      '<' => {
        name = self.parse_group_name()
        if name == "" {
          raise EmptyGroupName(pos=self.pos)
        }
        self.capture_name_mapping.set(name, index)
      }
      _ => ()
    }
  }
  if !self.more() || self.peek_is(')') {
    raise EmptyGroup(pos=self.pos)
  }
  let node = if capture {
    AstNode::new(Capture(index~))
  } else {
    AstNode::new(Group)
  }
  node.add_child(self.parse_expr(true))
  if !self.more() || !self.peek_is(')') {
    raise GroupMissingParen(pos=self.pos)
  }
  self.advance(1) // ')'
  node
}

///|
fn Parser::parse_group_name(self : Parser) -> String raise ParseError {
  self.advance(1) // '<'
  let buf = StringBuilder()
  while self.more() && !self.peek_is('>') {
    buf.write_char(self.peek())
    self.advance(1)
  }
  if !self.peek_is('>') {
    raise UnmatchedGroupName(pos=self.pos)
  }
  self.advance(1) // '>'
  buf.to_string()
}

///|
fn Parser::parse_class(self : Parser) -> AstNode raise ParseError {
  let neg = if self.peek_is('^') {
    self.advance(1)
    true
  } else {
    false
  }
  let mut first = true
  let char_class = CharClass::new(neg~)
  // Allow ']' and '-' as first char in class
  while self.more() && (!self.peek_is(']') || first) {
    if (self.peek_is(']') || self.peek_is('-')) && first {
      char_class.add_single(self.peek())
      self.advance(1)
    }
    first = false
    if self.peek_is('\\') {
      self.advance(1)
      match self.peek() {
        'd' => char_class.add_category(Digit)
        'D' => char_class.add_category(NotDigit)
        's' => char_class.add_category(Space)
        'S' => char_class.add_category(NotSpace)
        'w' => char_class.add_category(Word)
        'W' => char_class.add_category(NotWord)
        't' => char_class.add_single('\t')
        'r' => char_class.add_single('\r')
        'n' => char_class.add_single('\n')
        'v' => char_class.add_single('\u000B')
        'f' => char_class.add_single('\u000C')
        _ as c => char_class.add_single(c)
      }
      self.advance(1)
    } else {
      let low = self.parse_char_class_char()
      let mut high = low
      if self.more() && self.peek_is('-') {
        self.advance(1) // '-'
        if self.more() && self.peek_is(']') {
          // '-' is the last char
          self.rewind(1)
        } else {
          high = self.parse_char_class_char()
        }
      }
      char_class.add_range(low, high)
    }
  }
  if !self.more() || !self.peek_is(']') {
    raise ClassMissingBracket(pos=self.pos)
  } else {
    self.advance(1) // ']'
    AstNode::new(Class(class=char_class))
  }
}

///|
fn Parser::parse_char_class_char(self : Parser) -> Char raise ParseError {
  if !self.more() {
    raise ClassMissingBracket(pos=self.pos)
  }
  if self.peek_is('\\') {
    self.advance(1)
  }
  let c = self.peek()
  self.advance(1)
  c
}

///|
fn Parser::parse_escape(self : Parser) -> AstNode raise ParseError {
  if !self.more() {
    raise EndPatternAtEscape(pos=self.pos)
  }
  let node : AstNodeInternal = match self.peek() {
    'd' => Class(class=CharClass::new()..add_category(Digit))
    'D' => Class(class=CharClass::new()..add_category(NotDigit))
    's' => Class(class=CharClass::new()..add_category(Space))
    'S' => Class(class=CharClass::new()..add_category(NotSpace))
    'w' => Class(class=CharClass::new()..add_category(Word))
    'W' => Class(class=CharClass::new()..add_category(NotWord))
    't' => Single(char='\t')
    'r' => Single(char='\r')
    'n' => Single(char='\n')
    'v' => Single(char='\u000B')
    'f' => Single(char='\u000C')
    _ as char => Single(char~)
  }
  self.advance(1)
  AstNode::new(node)
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  logger.write_object(Repr(self))
}
