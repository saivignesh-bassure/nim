import sequtils, strutils

const
  Plain = "abcdefghijklmnopqrstuvwxyz"
  Cipher = "zyxwvutsrqponmlkjihgfedcba"


proc group(s: seq[char], digits = 5): string =
  for index, letter in s:
    if index mod 5 == 0 and index > 0:
      result.add " "
    result.add letter

proc clean(phrase: string): seq[char] =
  phrase.toLowerAscii.filterIt(it.isAlphaNumeric)

proc convert(c: char, fromInput: string, toInput: string): char =
  if c.isAlphaAscii: toInput[fromInput.find(c)] else: c

proc encode*(phrase: string): string =
  phrase.clean.mapIt(it.convert(Plain, Cipher)).group

proc decode*(phrase: string): string =
  phrase.clean.mapIt(it.convert(Cipher, Plain)).join("")
