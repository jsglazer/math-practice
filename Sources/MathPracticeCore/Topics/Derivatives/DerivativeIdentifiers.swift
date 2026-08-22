//  DerivativeIdentifiers.swift
//  The identity strings for the derivatives topic. Persisted, so treat as a data contract.

public extension TopicID {
    static let derivatives = TopicID("derivatives")
}

public extension SubTypeID {
    static let powerRule = SubTypeID("power")
    static let productRule = SubTypeID("product")
    static let quotientRule = SubTypeID("quotient")
    static let chainRule = SubTypeID("chain")
    static let trigonometric = SubTypeID("trig")
    static let exponentialLogarithmic = SubTypeID("exp-log")
}
