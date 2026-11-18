///|
priv enum AstNodeInternal {
  // Leave nodes of the AST.
  Empty
  Single(char~ : Char)
  NotSingle(char~ : Char)
  Class(class~ : CharClass)
  // Multi(str~ : String)
  SingleLoop(char~ : Char, min~ : Int32, max~ : Int32?, greedy~ : Bool)
  NotSingleLoop(char~ : Char, min~ : Int32, max~ : Int32?, greedy~ : Bool)
  ClassLoop(class~ : CharClass, min~ : Int32, max~ : Int32?, greedy~ : Bool)
  // Backreference(index~ : Int)
  BeginOfInput
  EndOfInput
  // Branch nodes of the AST that have at least one child.
  Alternate
  Concatenate
  Loop(min~ : Int32, max~ : Int32?, greedy~ : Bool)
  Capture(index~ : Int32)
  Group
}

///|
priv struct AstNode {
  internal : AstNodeInternal
  mut parent : AstNode?
  children : Array[AstNode]
}

///|
fn AstNode::new(
  internal : AstNodeInternal,
  parent~ : AstNode? = None,
  children~ : Array[AstNode] = [],
) -> AstNode {
  { internal, parent, children, }
}

///|
fn AstNode::add_child(self : AstNode, child : AstNode) -> Unit {
  child.parent = Some(self)
  self.children.push(child)
}

///|
fn AstNode::get_child(self : AstNode, idx : Int32) -> AstNode {
  self.children[idx]
}

///|
fn AstNode::child_num(self : AstNode) -> Int32 {
  self.children.length()
}

///|
priv struct Ast {
  root : AstNode
  capture_num : Int32
  capture_name_mapping : Map[String, Int32]
}
