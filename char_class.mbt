///|
priv struct CharClass {
  neg : Bool
  ranges : Array[Int32]
  categories : Array[CharClassCategory]
}

///|
priv enum CharClassCategory {
  Digit
  NotDigit
  Space
  NotSpace
  Word
  NotWord
}

///|
fn CharClass::new(
  neg~ : Bool = false,
  ranges~ : Array[Int32] = [],
  categories~ : Array[CharClassCategory] = [],
) -> CharClass {
  { neg, ranges, categories, }
}

///|
fn CharClass::add_single(self : CharClass, char : Char) -> Unit {
  self.ranges.push(char.to_int())
  self.ranges.push(char.to_int())
}

///|
fn CharClass::add_range(self : CharClass, low : Char, high : Char) -> Unit {
  self.ranges.push(low.to_int())
  self.ranges.push(high.to_int())
}

///|
fn CharClass::add_category(
  self : CharClass,
  category : CharClassCategory,
) -> Unit {
  self.categories.push(category)
}

///|
fn CharClass::contains(self : CharClass, char : Int32) -> Bool {
  let result = self.ranges_contains(char) || self.categories_contains(char)
  if self.neg {
    !result
  } else {
    result
  }
}

///|
fn CharClass::ranges_contains(self : CharClass, char : Int32) -> Bool {
  for i = 0; i < self.ranges.length(); i = i + 2 {
    let low = self.ranges[i]
    let high = self.ranges[i + 1]
    if char >= low && char <= high {
      return true
    }
  } nobreak {
    return false
  }
}

///|
fn CharClass::categories_contains(self : CharClass, char : Int32) -> Bool {
  for category in self.categories {
    let res = match category {
      Digit => is_digit(char)
      NotDigit => !is_digit(char)
      Space => is_whitespace(char)
      NotSpace => !is_whitespace(char)
      Word => is_word_char(char)
      NotWord => !is_word_char(char)
    }
    if res {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn is_whitespace(char : Int32) -> Bool {
  return char == ' '.to_int() ||
    char == '\t'.to_int() ||
    char == '\n'.to_int() ||
    char == '\r'.to_int() ||
    char == '\u000B'.to_int() ||
    char == '\u000C'.to_int() ||
    char == '\u0020'.to_int() ||
    char == '\u00A0'.to_int() ||
    char == '\u1680'.to_int() ||
    char == '\u2000'.to_int() ||
    char == '\u2001'.to_int() ||
    char == '\u2002'.to_int() ||
    char == '\u2003'.to_int() ||
    char == '\u2004'.to_int() ||
    char == '\u2005'.to_int() ||
    char == '\u2006'.to_int() ||
    char == '\u2007'.to_int() ||
    char == '\u2008'.to_int() ||
    char == '\u2009'.to_int() ||
    char == '\u2028'.to_int() ||
    char == '\u2029'.to_int()
}

///|
fn is_word_char(char : Int32) -> Bool {
  return (char >= 'a'.to_int() && char <= 'z'.to_int()) ||
    (char >= 'A'.to_int() && char <= 'Z'.to_int()) ||
    (char >= '0'.to_int() && char <= '9'.to_int()) ||
    char == '_'.to_int()
}

///|
fn is_digit(char : Int32) -> Bool {
  return char >= '0'.to_int() && char <= '9'.to_int()
}
