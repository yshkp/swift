// RUN: %target-swift-frontend -enable-experimental-static-assert -emit-sil %s -verify -Xllvm -debug -Xllvm -debug-only -Xllvm ConstExpr

//===----------------------------------------------------------------------===//
// Basic function calls and control flow
//===----------------------------------------------------------------------===//

func isOne(_ x: Int) -> Bool {
  return x == 1
}

func test_assertionSuccess() {
  #assert(isOne(1))
  #assert(isOne(1), "1 is not 1")
}

func test_assertionFailure() {
  #assert(isOne(2)) // expected-error{{assertion failed}}
  #assert(isOne(2), "2 is not 1") // expected-error{{2 is not 1}}
}

func test_nonConstant() {
  #assert(isOne(Int(readLine()!)!)) // expected-error{{#assert condition not constant}}
  #assert(isOne(Int(readLine()!)!), "input is not 1") // expected-error{{#assert condition not constant}}
}

// We don't support mutation, so the only loop we can make is infinite.
// TODO: As soon as we support mutation, add tests with finite loops.
func infiniteLoop() -> Int {
  // expected-note @+2 {{condition always evaluates to true}}
  // expected-note @+1 {{control flow loop found}}
  while true {}
  // expected-warning @+1 {{will never be executed}}
  return 1
}

func test_infiniteLoop() {
  // expected-error @+2 {{#assert condition not constant}}
  // expected-note @+1 {{when called from here}}
  #assert(infiniteLoop() == 1)
}

func recursive(a: Int) -> Int {
   // expected-note@+1 {{exceeded instruction limit: 512 when evaluating the expression at compile time}}
  return a == 0 ? 0 : recursive(a: a-1)
}

func test_recursive() {
  // expected-error @+1 {{#assert condition not constant}}
  #assert(recursive(a: 20000) > 42)
}

func conditional(_ x: Int) -> Int {
  if x < 0 {
    return 0
  } else {
    return x
  }
}

func test_conditional() {
  #assert(conditional(-5) == 0)
  #assert(conditional(5) == 5)

  // expected-error @+1 {{assertion failed}}
  #assert(conditional(-5) == 1)
  // expected-error @+1 {{assertion failed}}
  #assert(conditional(5) == 1)
}

//===----------------------------------------------------------------------===//
// Top-level evaluation
//===----------------------------------------------------------------------===//

func test_topLevelEvaluation(topLevelArgument: Int) {
  let topLevelConst = 1
  #assert(topLevelConst == 1)

  // The #assert successfully sees the value of this `var` even though it is
  // mutable because DiagnosticConstantPropagation propagates its value.
  var topLevelVar = 1 // expected-warning {{never mutated}}
  #assert(topLevelVar == 1)

  var topLevelVarConditionallyMutated = 1
  if topLevelVarConditionallyMutated < 0 {
    topLevelVarConditionallyMutated += 1
  }
  // expected-error @+2 {{#assert condition not constant}}
  // expected-note @+1 {{could not fold operation}}
  #assert(topLevelVarConditionallyMutated == 1)

  // expected-error @+1 {{#assert condition not constant}}
  #assert(topLevelArgument == 1)
}

//===----------------------------------------------------------------------===//
// Integers
//===----------------------------------------------------------------------===//

func test_trapsAndOverflows() {
  // The error message below is generated by the traditional constant folder.
  // The interpreter responsible for #assert does not generate an overflow
  // error because the traditional constant folder replaces the condition with
  // a constant before the #assert interpreter sees it.
  // expected-error @+1 {{arithmetic operation '124 + 92' (on type 'Int8') results in an overflow}}
  #assert((124 as Int8) + 92 < 42)

  // One error message below is generated by the traditional constant folder.
  // The interpreter responsible for #assert does generate an additional error
  // message.
  // expected-error @+2 {{integer literal '123231' overflows when stored into 'Int8'}}
  // expected-error @+1 {{#assert condition not constant}}
  #assert(Int8(123231) > 42)
  // expected-note @-1 {{integer overflow detected}}

  // The error message below is generated by the traditional constant folder.
  // The interpreter responsible for #assert does not generate an overflow
  // error because the traditional constant folder replaces the condition with
  // a constant before the #assert interpreter sees it.
  // expected-error @+2 {{arithmetic operation '124 + 8' (on type 'Int8') results in an overflow}}
  // expected-error @+1 {{assertion failed}}
  #assert(Int8(124) + 8 > 42)
}

// Calling this stops the traditional mandatory constant folder from folding
// the arithmetic before ConstExpr.cpp gets it.
func identity(_ x: Int) -> Int {
  return x
}

func test_integerArithmetic() {
  #assert(identity(1) + 1 == 2)
  #assert(identity(1) - 1 == 0)
  #assert(identity(2) * 2 == 4)
  #assert(identity(10) / 10 == 1)
  #assert(identity(10) % 7 == 3)
  #assert(identity(1) < 2)
  #assert(identity(1) <= 1)
  #assert(identity(2) > 1)
  #assert(identity(1) >= 1)
}

//===----------------------------------------------------------------------===//
// Custom structs and tuples
//===----------------------------------------------------------------------===//

struct CustomStruct {
  let x: (Int, Int)
  let y: Int
}

func test_CustomStruct() {
  let cs = CustomStruct(x: (1, 2), y: 3)
  #assert(cs.x.0 == 1)
  #assert(cs.x.1 == 2)
  #assert(cs.y == 3)
}
