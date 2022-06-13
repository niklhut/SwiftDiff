import XCTest
@testable import SwiftDiff
import CoreFoundation
import Dispatch


class SwiftDiffTests: XCTestCase {

    func testDiffCommonPrefix() {
        // Detect any common prefix.

        // Null case.
        XCTAssertEqual(0, commonPrefixLength(text1: "abc", text2: "xyz"))

        // Non-null case.
        XCTAssertEqual(4, commonPrefixLength(text1: "1234abcdef", text2: "1234xyz"))

        // Whole case.
        XCTAssertEqual(4, commonPrefixLength(text1: "1234", text2: "1234xyz"))
    }

    func testDiffCommonSuffix() {
        // Detect any common suffix.

        // Null case.
        XCTAssertEqual(0, commonSuffixLength(text1: "abc", text2: "xyz"))

        // Non-null case.
        XCTAssertEqual(4, commonSuffixLength(text1: "abcdef1234", text2: "xyz1234"))

        // Whole case.
        XCTAssertEqual(4, commonSuffixLength(text1: "1234", text2: "xyz1234"))
    }

    func testDiffCommonOverlap() {
        // Detect any suffix/prefix overlap.

        // Null case.
        XCTAssertEqual(0, commonOverlapLength(text1: "", text2: "abcd"));

        // Whole case.
        XCTAssertEqual(3, commonOverlapLength(text1: "abc", text2: "abcd"));

        // No overlap.
        XCTAssertEqual(0, commonOverlapLength(text1: "123456", text2: "abcd"));

        // Overlap.
        XCTAssertEqual(3, commonOverlapLength(text1: "123456xxx", text2: "xxxabcd"));

        // Unicode.
        // Some overly clever languages (C#) may treat ligatures as equal to their
        // component letters.  E.g. U+FB01 == 'fi'
        XCTAssertEqual(0, commonOverlapLength(text1: "fi", text2: "\u{fb01}i"));
    }

    func testDiff() {
        // Null case.
        XCTAssertEqual([],
                       diff(text1: "", text2: ""))

        // Equality.
        XCTAssertEqual([.equal(text: "abc")],
                       diff(text1: "abc", text2: "abc"))

        // Simple insertion.
        XCTAssertEqual([.equal(text: "ab"), .insert(text: "123"), .equal(text: "c")],
                       diff(text1: "abc",
                            text2: "ab123c"))

        // Simple deletion.
        XCTAssertEqual([.equal(text: "a"), .delete(text: "123"), .equal(text: "bc")],
                       diff(text1: "a123bc",
                            text2: "abc"))

        // Two insertions.
        XCTAssertEqual([.equal(text: "a"), .insert(text: "123"),
                        .equal(text: "b"), .insert(text: "456"),
                        .equal(text: "c")],
                       diff(text1: "abc",
                            text2: "a123b456c"))

        // Two deletions.
        XCTAssertEqual([.equal(text: "a"), .delete(text: "123"),
                        .equal(text: "b"), .delete(text: "456"),
                        .equal(text: "c")],
                       diff(text1: "a123b456c",
                            text2: "abc"))

        // Simple cases.
        XCTAssertEqual([.delete(text: "a"), .insert(text: "b")],
                       diff(text1: "a",
                            text2: "b"))

        XCTAssertEqual([.delete(text: "a"), .insert(text: "\u{0680}"), .equal(text: "x"), .delete(text: "\t"), .insert(text: "\0")],
                       diff(text1: "ax\t",
                            text2: "\u{0680}x\0"))

        // Requires first phase of cleanupMerge.
        XCTAssertEqual([.delete(text: "Apple"), .insert(text: "Banana"), .equal(text: "s are a"),
                        .insert(text: "lso"), .equal(text: " fruit.")],
                       diff(text1: "Apples are a fruit.",
                            text2: "Bananas are also fruit."))

        // Overlaps.
        XCTAssertEqual([.delete(text: "1"), .equal(text: "a"), .delete(text: "y"), .equal(text: "b"), .delete(text: "2"), .insert(text: "xab")],
                       diff(text1: "1ayb2",
                            text2: "abxab"))

        // Requires second phase of cleanupMerge.
        XCTAssertEqual([.insert(text: "xaxcx"), .equal(text: "abc"), .delete(text: "y")],
                       diff(text1: "abcy", text2: "xaxcxabc"))

        XCTAssertEqual([.delete(text: "ABCD"), .equal(text: "a"), .delete(text: "="), .insert(text: "-"), .equal(text: "bcd"),
                        .delete(text: "="), .insert(text: "-"), .equal(text: "efghijklmnopqrs"), .delete(text: "EFGHIJKLMNOefg")],
                       diff(text1: "ABCDa=bcd=efghijklmnopqrsEFGHIJKLMNOefg",
                            text2: "a-bcd-efghijklmnopqrs"))

        // Large equality.
        XCTAssertEqual([.insert(text: " "), .equal(text: "a"), .insert(text: "nd"),
                        .equal(text: " [[Pennsylvania]]"), .delete(text: " and [[New")],
                       diff(text1: "a [[Pennsylvania]] and [[New",
                            text2: " and [[Pennsylvania]]"))


        // Timeout.
        var a = "`Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe:\nAll mimsy were the borogoves,\nAnd the mome raths outgrabe.\n"
        var b = "I am the very model of a modern major general,\nI\'ve information vegetable, animal, and mineral,\nI know the kings of England, and I quote the fights historical,\nFrom Marathon to Waterloo, in order categorical.\n"
        // Increase the text lengths by 1024 times to ensure a timeout.
        for _ in 0..<10 {
            a = a + a
            b = b + b
        }

        // 100ms
        let timeout = 0.1
        let timeoutExpectation = expectation(description: "timeout")
        var duration: CFTimeInterval? = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = diff(text1: a, text2: b, timeout: timeout)
            let endTime = CFAbsoluteTimeGetCurrent()
            duration = endTime - startTime
            timeoutExpectation.fulfill()
        }

        // Ensure diff calculation doesn't take forever
        waitForExpectations(timeout: 5) { error in
            guard error == nil else {
                return
            }
            XCTAssertNotNil(duration)
            // Test that we took at least the timeout period.
            XCTAssertLessThanOrEqual(timeout, duration ?? Double.nan)
        }
    }

    func testDiffHalfMatch() {
        // Detect a halfmatch.

        // No match.
        XCTAssertEqual(nil, halfMatch(text1: "1234567890",
                                      text2: "abcdef"))

        XCTAssertEqual(nil, halfMatch(text1: "12345",
                                      text2: "23"))

        // Single Match.
        XCTAssertEqual(HalfMatch(text1A: "12", text1B: "9",
                                 text2A: "a", text2B: "z",
                                 midCommon: "345678"),
                       halfMatch(text1: "123456789",
                                 text2: "a345678z"))

        XCTAssertEqual(HalfMatch(text1A: "a", text1B: "z",
                                 text2A: "12", text2B: "90",
                                 midCommon: "345678"),
                       halfMatch(text1: "a345678z",
                                 text2: "1234567890"))

        XCTAssertEqual(HalfMatch(text1A: "abc", text1B: "z",
                                 text2A: "1234", text2B: "0",
                                 midCommon: "56789"),
                       halfMatch(text1: "abc56789z",
                                 text2: "1234567890"))

        XCTAssertEqual(HalfMatch(text1A: "a", text1B: "xyz",
                                 text2A: "1", text2B: "7890",
                                 midCommon: "23456"),
                       halfMatch(text1: "a23456xyz",
                                 text2: "1234567890"))

        // Multiple Matches.
        XCTAssertEqual(HalfMatch(text1A: "12123", text1B: "123121",
                                 text2A: "a", text2B: "z",
                                 midCommon: "1234123451234"),
                       halfMatch(text1: "121231234123451234123121",
                                 text2: "a1234123451234z"))

        XCTAssertEqual(HalfMatch(text1A: "", text1B: "-=-=-=-=-=",
                                 text2A: "x", text2B: "",
                                 midCommon: "x-=-=-=-=-=-=-="),
                       halfMatch(text1: "x-=-=-=-=-=-=-=-=-=-=-=-=",
                                 text2: "xx-=-=-=-=-=-=-="))

        XCTAssertEqual(HalfMatch(text1A: "-=-=-=-=-=", text1B: "",
                                 text2A: "", text2B: "y",
                                 midCommon: "-=-=-=-=-=-=-=y"),
                       halfMatch(text1: "-=-=-=-=-=-=-=-=-=-=-=-=y",
                                 text2: "-=-=-=-=-=-=-=yy"))

        // Non-optimal halfmatch.
        // Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
        XCTAssertEqual(HalfMatch(text1A: "qHillo", text1B: "w",
                                 text2A: "x", text2B: "Hulloy",
                                 midCommon: "HelloHe"),
                       halfMatch(text1: "qHilloHelloHew",
                                 text2: "xHelloHeHulloy"))
    }

    func testCleanupMerge() {
        // Cleanup a messy diff.

        // First phase:

        // Null case.
        XCTAssertEqual([],
                       cleanupMerge(diffs: []))

        // No change case.
        XCTAssertEqual([.equal(text: "a"), .delete(text: "b"), .insert(text: "c")],
                       cleanupMerge(diffs:
                                        [.equal(text: "a"), .delete(text: "b"), .insert(text: "c")]))

        // Merge equalities.
        XCTAssertEqual([.equal(text: "abc")],
                       cleanupMerge(diffs:
                                        [.equal(text: "a"), .equal(text: "b"), .equal(text: "c")]))

        // Merge deletions.
        XCTAssertEqual([.delete(text: "abc")],
                       cleanupMerge(diffs:
                                        [.delete(text: "a"), .delete(text: "b"), .delete(text: "c")]))

        // Merge insertions.
        XCTAssertEqual([.insert(text: "abc")],
                       cleanupMerge(diffs:
                                        [.insert(text: "a"), .insert(text: "b"), .insert(text: "c")]))

        // Merge interweave.
        XCTAssertEqual([.delete(text: "ac"), .insert(text: "bd"), .equal(text: "ef")],
                       cleanupMerge(diffs:
                                        [.delete(text: "a"), .insert(text: "b"), .delete(text: "c"), .insert(text: "d"), .equal(text: "e"), .equal(text: "f")]))

        // Prefix and suffix detection.
        XCTAssertEqual([.equal(text: "a"), .delete(text: "d"), .insert(text: "b"), .equal(text: "c")],
                       cleanupMerge(diffs:
                                        [.delete(text: "a"), .insert(text: "abc"), .delete(text: "dc")]))

        // Prefix and suffix detection with equalities.
        XCTAssertEqual([.equal(text: "xa"), .delete(text: "d"), .insert(text: "b"), .equal(text: "cy")],
                       cleanupMerge(diffs:
                                        [.equal(text: "x"), .delete(text: "a"), .insert(text: "abc"), .delete(text: "dc"), .equal(text: "y")]))

        // Second phase:

        // Slide edit left.
        XCTAssertEqual([.insert(text: "ab"), .equal(text: "ac")],
                       cleanupMerge(diffs:
                                        [.equal(text: "a"), .insert(text: "ba"), .equal(text: "c")]))

        // Slide edit right.
        XCTAssertEqual([.equal(text: "ca"), .insert(text: "ba")],
                       cleanupMerge(diffs:
                                        [.equal(text: "c"), .insert(text: "ab"), .equal(text: "a")]))

        // Slide edit left recursive.
        XCTAssertEqual([.delete(text: "abc"), .equal(text: "acx")],
                       cleanupMerge(diffs:
                                        [.equal(text: "a"), .delete(text: "b"), .equal(text: "c"), .delete(text: "ac"), .equal(text: "x")]))

        // Slide edit right recursive.
        XCTAssertEqual([.equal(text: "xca"), .delete(text: "cba")],
                       cleanupMerge(diffs:
                                        [.equal(text: "x"), .delete(text: "ca"), .equal(text: "c"), .delete(text: "b"), .equal(text: "a")]))
    }

    func testCleanupSemanticScore() {
        XCTAssertEqual(6, cleanupSemanticScore(text1: "", text2: ""))
        XCTAssertEqual(6, cleanupSemanticScore(text1: " ", text2: ""))
        XCTAssertEqual(5, cleanupSemanticScore(text1: "\n\n", text2: "\n\n"))
        XCTAssertEqual(5, cleanupSemanticScore(text1: "\r\n\n", text2: "\n\r\n"))
        XCTAssertEqual(5, cleanupSemanticScore(text1: "\r\n\r\n", text2: "\n\n"))
        XCTAssertEqual(2, cleanupSemanticScore(text1: " ", text2: " "))
    }

    func testCleanupSemanticLossless() {
        // Slide diffs to match logical boundaries.

        // Null case.
        XCTAssertEqual([],
                       cleanupSemanticLossless(diffs: []))

        // Blank lines.
        XCTAssertEqual([.equal(text: "AAA\r\n\r\n"), .insert(text: "BBB\r\nDDD\r\n\r\n"), .equal(text: "BBB\r\nEEE")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "AAA\r\n\r\nBBB"), .insert(text: "\r\nDDD\r\n\r\nBBB"), .equal(text: "\r\nEEE")]))

        // Line boundaries.
        XCTAssertEqual([.equal(text: "AAA\r\n"), .insert(text: "BBB DDD\r\n"), .equal(text: "BBB EEE")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "AAA\r\nBBB"), .insert(text: " DDD\r\nBBB"), .equal(text: " EEE")]))

        // Word boundaries.
        XCTAssertEqual([.equal(text: "The "), .insert(text: "cow and the "), .equal(text: "cat.")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "The c"), .insert(text: "ow and the c"), .equal(text: "at.")]))

        // Alphanumeric boundaries.

        XCTAssertEqual([.equal(text: "The-"), .insert(text: "cow-and-the-"), .equal(text: "cat.")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "The-c"), .insert(text: "ow-and-the-c"), .equal(text: "at.")]))

        // Hitting the start.
        XCTAssertEqual([.delete(text: "a"), .equal(text: "aax")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "a"), .delete(text: "a"), .equal(text: "ax")]))

        // Hitting the end.
        XCTAssertEqual([.equal(text: "xaa"), .delete(text: "a")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "xa"), .delete(text: "a"), .equal(text: "a")]))

        // Sentence boundaries.
        XCTAssertEqual([.equal(text: "The xxx."), .insert(text: " The zzz."), .equal(text: " The yyy.")],
                       cleanupSemanticLossless(diffs:
                                                [.equal(text: "The xxx. The "), .insert(text: "zzz. The "), .equal(text: "yyy.")]))
    }

    func testDiffCleanupSemantic() {
        // Cleanup semantically trivial equalities.

        // Null case.
        XCTAssertEqual([],
                       cleanupSemantic(diffs: []))

        // No elimination #1.
        XCTAssertEqual([.delete(text: "ab"), .insert(text: "cd"), .equal(text: "12"), .delete(text: "e")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "ab"), .insert(text: "cd"), .equal(text: "12"), .delete(text: "e")]))

        // No elimination #2.

        XCTAssertEqual([.delete(text: "abc"), .insert(text: "ABC"), .equal(text: "1234"), .delete(text: "wxyz")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "abc"), .insert(text: "ABC"), .equal(text: "1234"), .delete(text: "wxyz")]))

        // Simple elimination.
        XCTAssertEqual([.delete(text: "abc"), .insert(text: "b")],
                       cleanupSemantic(diffs: [.delete(text: "a"), .equal(text: "b"), .delete(text: "c")]))

        // Backpass elimination.
        XCTAssertEqual([.delete(text: "abcdef"), .insert(text: "cdfg")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "ab"), .equal(text: "cd"), .delete(text: "e"), .equal(text: "f"), .insert(text: "g")]))

        // Multiple eliminations.
        XCTAssertEqual([.delete(text: "AB_AB"), .insert(text: "1A2_1A2")],
                       cleanupSemantic(diffs:
                                        [.insert(text: "1"), .equal(text: "A"), .delete(text: "B"), .insert(text: "2"), .equal(text: "_"),
                                         .insert(text: "1"), .equal(text: "A"), .delete(text: "B"), .insert(text: "2")]))

        // Word boundaries.
        XCTAssertEqual([.equal(text: "The "), .delete(text: "cow and the "), .equal(text: "cat.")],
                       cleanupSemantic(diffs:
                                        [.equal(text: "The c"), .delete(text: "ow and the c"), .equal(text: "at.")]))

        // No overlap elimination.
        XCTAssertEqual([.delete(text: "abcxx"), .insert(text: "xxdef")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "abcxx"), .insert(text: "xxdef")]))

        // Overlap elimination.
        XCTAssertEqual([.delete(text: "abc"), .equal(text: "xxx"), .insert(text: "def")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "abcxxx"), .insert(text: "xxxdef")]))

        // Reverse overlap elimination.
        XCTAssertEqual([.insert(text: "def"), .equal(text: "xxx"), .delete(text: "abc")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "xxxabc"), .insert(text: "defxxx")]))

        // Two overlap eliminations.
        XCTAssertEqual([.delete(text: "abcd"), .equal(text: "1212"), .insert(text: "efghi"), .equal(text: "----"),
                        .delete(text: "A"), .equal(text: "3"), .insert(text: "BC")],
                       cleanupSemantic(diffs:
                                        [.delete(text: "abcd1212"), .insert(text: "1212efghi"), .equal(text: "----"),
                         .delete(text: "A3"), .insert(text: "3BC")]))
    }
}

#if os(Linux)
    extension SwiftDiffTests {
        static var allTests : [(String, (SwiftDiffTests) -> () throws -> Void)] {
            return [
                ("testDiffCommonPrefix", testDiffCommonPrefix),
                ("testDiffCommonSuffix", testDiffCommonSuffix),
                ("testDiffCommonOverlap", testDiffCommonOverlap),
                ("testDiff", testDiff),
                ("testDiffHalfMatch", testDiffHalfMatch),
                ("testCleanupMerge", testCleanupMerge),
                ("testCleanupSemanticScore", testCleanupSemanticScore),
                ("testCleanupSemanticLossless", testCleanupSemanticLossless),
                ("testDiffCleanupSemantic", testDiffCleanupSemantic),
            ]
        }
    }
#endif
