///|
fn AstNodeInternal::to_string(self : AstNodeInternal) -> String {
  fn range_str(min : Int32, max : Int32?) {
    match max {
      Some(max) => if min == max { "{\{min}} " } else { "{\{min},\{max}} " }
      None => "{\{min},} "
    }
  }

  fn greedy_str(g : Bool) -> String {
    if g {
      "Greedy "
    } else {
      "NonGreedy "
    }
  }

  match self {
    Empty => "Empty"
    Single(char~) => "Single " + char.to_int().to_string()
    NotSingle(char~) => "NotSingle " + char.to_int().to_string()
    Class(class~) => "Class " + Show::to_string(class)
    SingleLoop(char~, min~, max~, greedy~) =>
      "SingleLoop " +
      greedy_str(greedy) +
      range_str(min, max) +
      char.to_int().to_string()
    NotSingleLoop(char~, min~, max~, greedy~) =>
      "NotSingleLoop " +
      greedy_str(greedy) +
      range_str(min, max) +
      char.to_int().to_string()
    ClassLoop(class~, min~, max~, greedy~) =>
      "ClassLoop " +
      greedy_str(greedy) +
      range_str(min, max) +
      Show::to_string(class)
    BeginOfInput => "BeginOfLine"
    EndOfInput => "EndOfLine"
    Alternate => "Alternate"
    Concatenate => "Concatenate"
    Loop(min~, max~, greedy~) =>
      "Loop " + greedy_str(greedy) + range_str(min, max)
    Capture(index~) => "Capture \{index}"
    Group => "Group"
  }
}

///|
impl Show for AstNode with fn output(self, logger) -> Unit {
  let mut cur_node = self
  let mut cur_child = 0
  let stack = []
  logger.write_string(cur_node.internal.to_string())
  logger.write_char('\n')
  for ;; {
    if cur_child < cur_node.child_num() {
      stack.push(cur_child + 1)
      cur_node = cur_node.get_child(cur_child)
      cur_child = 0
      for i = 0; i < stack.length(); i = i + 1 {
        logger.write_string("  ")
      }
      logger.write_string(cur_node.internal.to_string())
      logger.write_char('\n')
    } else {
      if stack.is_empty() {
        break
      }
      cur_child = stack.unsafe_pop()
      cur_node = match cur_node.parent {
        Some(node) => node
        None => break
      }
    }
  }
}

///|
impl Show for Ast with fn output(self, logger) {
  logger.write_char('\n')
  logger.write_string("Number of captures: " + self.capture_num.to_string())
  logger.write_char('\n')
  logger.write_string("Capture name mapping: ")
  logger.write_string(
    "{" +
    self.capture_name_mapping
    .iter()
    .map(fn(pair) {
      let (k, v) = pair
      quote_capture(k) + ": " + v.to_string()
    })
    .collect()
    .join(", ") +
    "}",
  )
  logger.write_char('\n')
  logger.write_string("Ast:\n")
  logger.write_string(Show::to_string(self.root))
}

///|
impl Show for Program with fn output(self, logger) -> Unit {
  let mut pos = 0
  while pos < self.bytecodes.length() {
    let size = self.output_op(pos, logger)
    logger.write_char('\n')
    pos += size
  }
}

///|
fn Program::output_op(self : Program, pos : Int32, logger : &Logger) -> Int32 {
  let mut size = 0
  logger.write_string("\{pos} ")
  let opcode = OpCode::from_bytecode(self.bytecodes[pos])
  match opcode {
    Nop | Stop | BeginOfInput | EndOfInput | NullMark | SetMark | GetMark => {
      logger.write_string("\{opcode}")
      size = 1
    }
    Goto
    | BranchLazy
    | BranchMark
    | BranchMarkLazy
    | NullCount
    | SetCount
    | CaptureMark => {
      let opd = self.bytecodes[pos + 1]
      logger.write_string("\{opcode} \{opd}")
      size = 2
    }
    Single | NotSingle => {
      let char = self.bytecodes[pos + 1]
      logger.write_string("\{opcode} \{char}")
      size = 2
    }
    Class => {
      let class_idx = self.bytecodes[pos + 1]
      let class = self.classes[class_idx]
      logger.write_string("\{opcode} \{class}")
      size = 2
    }
    SingleRepeat
    | NotSingleRepeat
    | SingleLoop
    | NotSingleLoop
    | SingleLazy
    | NotSingleLazy => {
      let char = self.bytecodes[pos + 1]
      let opd2 = self.bytecodes[pos + 2]
      logger.write_string("\{opcode} \{char} \{opd2}")
      size = 3
    }
    BranchCount | BranchCountLazy => {
      let opd1 = self.bytecodes[pos + 1]
      let opd2 = self.bytecodes[pos + 2]
      logger.write_string("\{opcode} \{opd1} \{opd2}")
      size = 3
    }
    ClassRepeat | ClassLoop | ClassLazy => {
      let class_idx = self.bytecodes[pos + 1]
      let class = self.classes[class_idx]
      let opd2 = self.bytecodes[pos + 2]
      logger.write_string("\{opcode} \{class} \{opd2}")
      size = 3
    }
  }
  size
}

///|
impl Show for CharClass with fn output(self, logger) -> Unit {
  logger.write_char('[')
  if self.neg {
    logger.write_char('^')
  }
  for i = 0; i < self.ranges.length(); i = i + 2 {
    let min = self.ranges[i]
    let max = self.ranges[i + 1]
    if i > 0 {
      logger.write_char(',')
    }
    if min == max {
      logger.write_string(min.to_string())
    } else {
      logger.write_string(min.to_string())
      logger.write_char('-')
      logger.write_string(max.to_string())
    }
  }
  for category in self.categories {
    match category {
      Digit => logger.write_string("\\d")
      NotDigit => logger.write_string("\\D")
      Space => logger.write_string("\\s")
      NotSpace => logger.write_string("\\S")
      Word => logger.write_string("\\w")
      NotWord => logger.write_string("\\W")
    }
  }
  logger.write_char(']')
}

///|
impl Show for OpCode with fn output(self, logger) {
  logger.write_string(
    match self {
      Nop => "Nop"
      Stop => "Stop"
      Single => "Single"
      NotSingle => "NotSingle"
      Class => "Class"
      SingleRepeat => "SingleRepeat"
      NotSingleRepeat => "NotSingleRepeat"
      ClassRepeat => "ClassRepeat"
      SingleLoop => "SingleLoop"
      NotSingleLoop => "NotSingleLoop"
      ClassLoop => "ClassLoop"
      SingleLazy => "SingleLazy"
      NotSingleLazy => "NotSingleLazy"
      ClassLazy => "ClassLazy"
      BeginOfInput => "BeginOfInput"
      EndOfInput => "EndOfInput"
      Goto => "Goto"
      BranchLazy => "BranchLazy"
      BranchMark => "BranchMark"
      BranchMarkLazy => "BranchMarkLazy"
      NullCount => "NullCount"
      SetCount => "SetCount"
      BranchCount => "BranchCount"
      BranchCountLazy => "BranchCountLazy"
      NullMark => "NullMark"
      SetMark => "SetMark"
      CaptureMark => "CaptureMark"
      GetMark => "GetMark"
    },
  )
}
