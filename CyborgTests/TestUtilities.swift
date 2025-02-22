//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@testable import Cyborg
import XCTest

class NoTheme: ResourceProviding, ThemeProviding {

    func colorFromResources(named _: String) -> UIColor {
        return .black
    }

    func colorFromTheme(named _: String) -> UIColor {
        return .black
    }
}

extension CGPoint {

    init(_ xy: (CGFloat, CGFloat)) {
        self.init(x: xy.0, y: xy.1)
    }

}

extension CGSize {

    static let identity = CGSize(width: 1, height: 1)

}

func createPath(from pathSegment: PathSegment,
                start: PriorContext = .zero,
                path: CGMutablePath = CGMutablePath()) -> CGMutablePath {
    var priorContext: PriorContext = start
    for segment in pathSegment {
        priorContext = segment.apply(to: path, using: priorContext, in: .identity)
    }
    return path
}

extension String {

    func withXMLString<T>(_ function: (XMLString) -> (T)) -> T {
        let (string, buffer) = XMLString.create(from: self)
        defer {
            buffer.deallocate()
        }
        return function(string)
    }

}

extension XMLString {

    static func create(from string: String) -> (XMLString, UnsafeMutablePointer<UInt8>) {
        return string.withCString { pointer in
            pointer.withMemoryRebound(to: UInt8.self,
                                      capacity: string.utf8.count + 1, { pointer in
                                          let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: string.count + 1)
                                          for i in 0..<string.utf8.count + 1 {
                                              buffer.advanced(by: i).pointee = pointer.advanced(by: i).pointee
                                          }
                                          return (XMLString(buffer, count: Int32(string.utf8.count)), buffer)
            })
        }
    }

}

extension ParseResult {

    var asOptional: (Wrapped, Int32)? {
        switch self {
        case .ok(let wrapped): return wrapped
        case .error: return nil
        }
    }

}

extension Result {

    func expectSuccess() -> Wrapped {
        switch self {
        case .ok(let wrapped): return wrapped
        case .error(let error): fatalError(error)
        }
    }

    func expectFailure() -> ParseError {
        switch self {
        case .ok(let wrapped): fatalError("\(wrapped)")
        case .error(let error): return error
        }
    }

}

extension VectorDrawable {

    static func create(from string: String) -> Result<VectorDrawable> {
        return create(from: string.data(using: .utf8)!)
    }

}

extension CALayer {

    func layerInHierarchy(named name: String) -> CALayer? {
        if self.name == name {
            return self
        }
        for layer in sublayers ?? [] {
            if layer.name == name {
                return layer
            } else if let sublayer = layer.layerInHierarchy(named: name) {
                return sublayer
            }
        }
        return nil
    }

}

extension CGSize {

    func intoBounds() -> CGRect {
        return CGRect(origin: .zero, size: self)
    }

}

extension CGRect {

    static func boundsRect(_ width: CGFloat, _ height: CGFloat) -> CGRect {
        return .init(origin: .zero, size: .init(width: width, height: height))
    }

}

indirect enum ElementType {

    static let path: ElementType = .pathWithGradient(nil)
    
    case clipPath
    case pathWithGradient(ElementType?)
    case group([ElementType])
    case gradient

    var asType: AnyClass {
        switch self {
        case .clipPath: return VectorDrawable.ClipPath.self
        case .pathWithGradient: return VectorDrawable.Path.self
        case .group: return VectorDrawable.Group.self
        case .gradient: return VectorDrawable.Gradient.self
        }
    }

    var children: [ElementType] {
        if case .group(let children) = self {
            return children
        } else if case .pathWithGradient(let optionalChild) = self,
            let child = optionalChild {
            return [child]
        } else {
            return []
        }
    }

}

func assertHierarchiesEqual(_ lhs: DrawableHierarchyProviding,
                            _ rhs: [ElementType],
                            file: StaticString = #file,
                            line: UInt = #line) {
    XCTAssert(
        lhs.hierarchyMatches(rhs),
        "Hierarchies didn't match: \n Expected: \(lhs), Actual: \(rhs)",
        file: file,
        line: line
    )
}

protocol DrawableHierarchyProviding: AnyObject {

    var hierarchy: [GroupChild] { get }

}

extension DrawableHierarchyProviding {

    func hierarchyMatches(_ expectedHierarchy: [ElementType]) -> Bool {
        if hierarchy.count != expectedHierarchy.count {
            print(hierarchy)
            return false
        }
        for (child, elementType) in zip(hierarchy, expectedHierarchy) {
            if type(of: child) == elementType.asType {
                if let child = child as? DrawableHierarchyProviding,
                    !child.hierarchyMatches(elementType.children) {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }

}

extension VectorDrawable: DrawableHierarchyProviding {

    var hierarchy: [GroupChild] {
        return groups
    }

}

extension VectorDrawable.Group: DrawableHierarchyProviding {

    var hierarchy: [GroupChild] {
        return children
    }

}
