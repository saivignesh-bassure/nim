import
  std / unittest

import
  difference_of_squares

suite "Square the sum of the numbers up to the given number":
  test "square of sum 1":
    check squareOfSum(1) == 1
  test "square of sum 5":
    check squareOfSum(5) == 225
  test "square of sum 100":
    check squareOfSum(100) == 25502500
suite "Sum the squares of the numbers up to the given number":
  test "sum of squares 1":
    check sumOfSquares(1) == 1
  test "sum of squares 5":
    check sumOfSquares(5) == 55
  test "sum of squares 100":
    check sumOfSquares(100) == 338350
suite "Subtract sum of squares from square of sums":
  test "difference of squares 1":
    check differenceOfSquares(1) == 0
  test "difference of squares 5":
    check differenceOfSquares(5) == 170
  test "difference of squares 100":
    check differenceOfSquares(100) == 25164150
