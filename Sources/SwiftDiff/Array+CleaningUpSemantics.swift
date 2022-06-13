import Foundation

extension Array where Element == Diff {
    public func cleaningUpSemantics() -> [Diff] {
        cleanupSemantic(diffs: self)
    }
}
