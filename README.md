# SwiftDiff

SwiftDiff is a (partial) port of the [Google Diff, Match and Patch Library (google-diff-match-patch)](https://code.google.com/p/google-diff-match-patch/) to Swift. The Google Diff, Match and Patch Library was originally written by [Neil Fraser](http://neil.fraser.name). 

So far only the diff algorithm has been ported. It allows comparing two blocks of plain text and efficiently returning a list of their differences. It supports detecting in-line text differences.

SwiftDiff was updated to Swift 5 and SPM 5.1 by Cyberfun. It was updated to Swift and SPM 5.7 and improved by niklhut.

To use SwiftDiff, add the following package dependency:
```swift
.package(url: "https://github.com/niklhut/SwiftDiff.git", from: "1.0.0")
```

## Usage


```swift
let text1 = "The quick brown fox jumps over the lazy dog."
let text2 = "That quick brown fox jumped over a lazy dog."

let myDiff = diff(text1: text1, text2: text2)
```

The diff would look like the following:

```swift
[
    .equal(text: "Th"), 
    .delete(text: "e"), 
    .insert(text: "at"), 
    .equal(text: " quick brown fox jump"), 
    .delete(text: "s"), 
    .insert(text: "ed"), 
    .equal(text: " over "), 
    .delete(text: "the"), 
    .insert(text: "a"), 
    .equal(text: " lazy dog.")
]
```

To find any overlaps between deletions and insertions you can use `cleanupSemantic(diffs: [Diff])` or directly call `.cleaningUpSemantics()` on an array of `Diff`:

```swift
let text3 = "The quick brown fox goes through the forest."
let text4 = "The brown fox quickly goes home."

let myDiff2 = diff(text1: text3, text2: text4)
```

So the diff is cleaned up and looks like the following 

```swift
[
    .equal(text: "The "), 
    .delete(text: "quick "), 
    .equal(text: "brown fox "), 
    .delete(text: "goes through the forest"), 
    .insert(text: "quickly goes home"), 
    .equal(text: ".")
]
```

instead of

```swift
[
    .equal(text: "The "), 
    .delete(text: "quick "),
    .equal(text: "brown fox "), 
    .insert(text: "quickly "), 
    .equal(text: "goes "), 
    .delete(text: "t"), 
    .equal(text: "h"), 
    .delete(text: "r"), 
    .equal(text: "o"),
    .delete(text: "ugh th"),
    .insert(text: "m"), 
    .equal(text: "e"), 
    .delete(text: " forest"),
    .equal(text: ".")
]
```

### Codable

Since the Diff is `Codable` it can easily be converted to, for example, JSON:

```swift
let jsonEncoder = JSONEncoder()
jsonEncoder.outputFormatting = .prettyPrinted // only for nicer displaying
let jsonData = try jsonEncoder.encode(myDiff2.cleaningUpSemantics())
let json = String(data: jsonData, encoding: .utf8)
print(json!)
```
Output:

```json
[
  {
    "equal" : {
      "text" : "The "
    }
  },
  {
    "delete" : {
      "text" : "quick "
    }
  },
  {
    "equal" : {
      "text" : "brown fox "
    }
  },
  {
    "delete" : {
      "text" : "goes through the forest"
    }
  },
  {
    "insert" : {
      "text" : "quickly goes home"
    }
  },
  {
    "equal" : {
      "text" : "."
    }
  }
]
```

## License

SwiftDiff is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0) – see the `LICENSE` file for details.

The original Google Diff, Match and Patch Library is also licensed under the same license and Copyright (c) 2006 Google Inc.
