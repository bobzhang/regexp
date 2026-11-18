///|
priv struct Program {
  bytecodes : Array[Int32]
  classes : Array[CharClass]
  capture_num : Int32
  capture_name_mapping : Map[String, Int32]
}

///|
fn Program::op_code(self : Program, pos : Int32) -> OpCode {
  OpCode::from_bytecode(self.bytecodes[pos])
}

///|
fn Program::operand(self : Program, pos : Int32) -> Int32 {
  self.bytecodes[pos]
}
