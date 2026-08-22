//  CanonicalRenderer.swift
//  Expression -> a fully parenthesised infix string the offline SymPy gate can parse.
//
//  This exists purely so `Tools/verify_templates/verify_templates.py` can differentiate the
//  problem and compare it against the template's stated answer. It ships in core because
//  the golden fixture records it, and the headless tests assert it byte-for-byte — but
//  nothing at runtime parses it and no CAS is ever invoked on device.

public extension Expression {
    /// A SymPy-parseable rendering. Every node is parenthesised, so precedence can never
    /// be misread across the Swift/Python boundary.
    var canonical: String {
        CanonicalRenderer.render(self)
    }
}

enum CanonicalRenderer {
    static func render(_ expression: Expression) -> String {
        switch expression {
        case let .constant(value):
            return value.isInteger
                ? "\(value.numerator)"
                : "Rational(\(value.numerator), \(value.denominator))"
        case let .symbol(name):
            return name
        case let .sum(terms):
            return "(" + terms.map(render).joined(separator: " + ") + ")"
        case let .product(factors):
            return "(" + factors.map(render).joined(separator: "*") + ")"
        case let .power(base, exponent):
            return "(\(render(base)))**(\(render(exponent)))"
        case let .function(name, argument):
            return "\(name.sympyName)(\(render(argument)))"
        }
    }
}

extension MathFunction {
    /// The SymPy function name. Note `ln` maps to `log`, which is SymPy's natural log.
    var sympyName: String {
        switch self {
        case .ln: return "log"
        default: return rawValue
        }
    }
}
