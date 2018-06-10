// Generated using Sourcery 0.11.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable file_length
// swiftlint:disable line_length

fileprivate func combineHashes(_ hashes: [Int]) -> Int {
    return hashes.reduce(0, combineHashValues)
}

fileprivate func combineHashValues(_ initial: Int, _ other: Int) -> Int {
    #if arch(x86_64) || arch(arm64)
        let magic: UInt = 0x9e3779b97f4a7c15
    #elseif arch(i386) || arch(arm)
        let magic: UInt = 0x9e3779b9
    #endif
    var lhs = UInt(bitPattern: initial)
    let rhs = UInt(bitPattern: other)
    lhs ^= rhs &+ magic &+ (lhs << 6) &+ (lhs >> 2)
    return Int(bitPattern: lhs)
}

fileprivate func hashArray<T: Hashable>(_ array: [T]?) -> Int {
    guard let array = array else {
        return 0
    }
    return array.reduce(5381) {
        ($0 << 5) &+ $0 &+ $1.hashValue
    }
}

#if swift(>=4.0)
fileprivate func hashDictionary<T, U: Hashable>(_ dictionary: [T: U]?) -> Int {
    guard let dictionary = dictionary else {
        return 0
    }
    return dictionary.reduce(5381) {
        combineHashValues($0, combineHashValues($1.key.hashValue, $1.value.hashValue))
    }
}
#else
fileprivate func hashDictionary<T: Hashable, U: Hashable>(_ dictionary: [T: U]?) -> Int {
    guard let dictionary = dictionary else {
        return 0
    }
    return dictionary.reduce(5381) {
        combineHashValues($0, combineHashValues($1.key.hashValue, $1.value.hashValue))
    }
}
#endif








// MARK: - AutoHashable for classes, protocols, structs
// MARK: - ConfigurationAnnotation AutoHashable
extension ConfigurationAnnotation: Hashable {
    public var hashValue: Int {
        let attributeHashValue = attribute.hashValue
        let targetHashValue = target.hashValue

        return combineHashes([
            attributeHashValue,
            targetHashValue,
            0])
    }
}

// MARK: - AutoHashable for Enums

// MARK: - ConfigurationAttribute AutoHashable
extension ConfigurationAttribute: Hashable {
    internal var hashValue: Int {
        switch self {
        case .isIsolated(let data):
            return combineHashes([1, data.hashValue])
        case .customRef(let data):
            return combineHashes([2, data.hashValue])
        }
    }
}

// MARK: - ConfigurationAttributeTarget AutoHashable
extension ConfigurationAttributeTarget: Hashable {
    internal var hashValue: Int {
        switch self {
        case .`self`:
            return combineHashes([1, ])
        case .dependency(let data):
            return combineHashes([2, data.hashValue])
        }
    }
}
