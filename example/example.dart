// Copyright 2012 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Author: Paul Brauner (polux@google.com)

import 'package:pattern_matching/pattern_matching.dart';
import 'package:persistent/persistent.dart';

// We define linked lists.

class LList {}
class Nil implements LList {
  toString() => "Nil()";
}
class Cons implements LList {
  final x;
  final LList xs;
  Cons(this.x, this.xs);
  toString() => "Cons($x, $xs)";
}

// This is boilerplate code that can be automatically derived from the
// definition of Nil and Cons. Note that patterns are typed:
// cons(eq(1), eq(2)) is ill-typed according to Dart's type system. You can
// also define more exotic patterns, like a pattern that matches any even number
// for instance.

OPattern<LList> nil() =>
    constructor([],
        (s) => (s is Nil) ? new Option.some([]) : new Option.none());
OPattern<LList> cons(OPattern p1, OPattern<LList> p2) =>
    constructor([p1, p2],
        (s) => (s is Cons) ? new Option.some([s.x, s.xs]) : new Option.none());

main() {
  final list = new Cons(1, new Cons(2, new Cons(3, new Nil())));

  // The right-hand side of the first rule that matches (in this case the
  // last one) is executed. "pvar" denote pattern variables.

  match(list).against(
      nil()                              >> (_) { throw "should not happen"; }
    | cons(v('x'), nil())                >> (_) { throw "should not happen"; }
    | cons(v('x'), cons(eq(1), v('xs'))) >> (_) { throw "should not happen"; }
    | cons(v('x'), cons(eq(2), v('xs'))) >> (e) { print("match: ${e['x']} ${e['xs']}"); }
  ); // prints "match: 1 Cons(3, Nil())"

  // Match returns a value: the value returned by the executed right-hand side.

  final tailOfTail = match(list).against(
      cons(v('_'), cons(v('_'), v('xs'))) >> (e) { return e['xs']; }  // _ is a wildcard
  );
  print(tailOfTail); // prints "Cons(3, Nil())"

  // Non-linear patterns are supported.

  final nonLinear = cons(v('x'), cons(v('x'), nil()));

  match(new Cons(1, new Cons(2, new Nil()))).against(
      nonLinear >> (_) { print("bad"); }
    | v('_')    >> (_) { print("good"); }
  );
  match(new Cons(1, new Cons(1, new Nil()))).against(
      nonLinear >> (_) { print("good"); }
  );

  // If no branch matches, a MatchFailure is raised.

  try {
    match(list).against(
        nil() >> (_) {  throw "should not happen"; }
    );
  } on MatchFailure catch (_) {
    print("failed as intended");
  }

  // Subpatterns can be aliased with %

  match(list).against(
      cons(v('_'), v('xs') % cons(v('_'), v('x'))) >> (e) { print("${e['xs']} ${e['x']}"); }
  ); // prints "Cons(2, Cons(3, Nil())) Cons(3, Nil())"

  // Guards allow to put extra conditions on patterns.

  match(list).against(
      cons(v('x'), v('_')) & guard((e) => e['x'] > 1) >> (_) { throw "impossible"; }
                           & otherwise                >> (e) { print("x = ${e['x']}"); }
    | nil()                                           >> (_) { throw "impossible"; }
  ); // prints "x = 1"

  // The obligatory map function.

  LList map(Function f, LList xs) =>
      match(xs).against(
          nil()                 >> (_) { return new Nil(); }
        | cons(v('y'), v('ys')) >> (e) { return new Cons(f(e['y']), map(f, e['ys'])); }
      );
  print(map((n) => n + 1, list));
}
