//  DerivativesTopic.swift
//  Topic 1 of n. Everything specific to derivatives lives in this directory.

/// The derivatives topic: power, product, quotient, chain, trig and exponential/log rules.
public struct DerivativesTopic: TopicModule {
    public init() {}

    public let id = TopicID.derivatives
    public let displayName = "Derivatives"

    public let subTypes: [SubType] = [
        SubType(id: .powerRule, displayName: "Power rule"),
        SubType(id: .productRule, displayName: "Product rule"),
        SubType(id: .quotientRule, displayName: "Quotient rule"),
        SubType(id: .chainRule, displayName: "Chain rule"),
        SubType(id: .trigonometric, displayName: "Trigonometric"),
        SubType(id: .exponentialLogarithmic, displayName: "Exponential & log"),
        SubType(id: .partial, displayName: "Partial derivatives")
    ]

    public let templates: [any ProblemTemplate] = [
        PolynomialTemplate(),
        NegativeExponentTemplate(),
        RadicalTemplate(),
        PolynomialProductTemplate(),
        PolynomialTrigProductTemplate(),
        ExponentialProductTemplate(),
        LinearQuotientTemplate(),
        PolynomialQuotientTemplate(),
        TrigQuotientTemplate(),
        PowerOfPolynomialTemplate(),
        TrigOfPolynomialTemplate(),
        RadicalOfPolynomialTemplate(),
        SineCosineTemplate(),
        TangentSecantTemplate(),
        ExponentialTemplate(),
        LogarithmTemplate(),
        PartialPolynomialXTemplate(),
        PartialPolynomialYTemplate(),
        PartialProductXTemplate(),
        PartialProductYTemplate(),
        PartialExponentialXTemplate(),
        PartialExponentialYTemplate(),
        PartialTrigXTemplate(),
        PartialTrigYTemplate()
    ]
}
