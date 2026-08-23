//  PartialDerivativeBuilders.swift
//  Shared construction helpers for the partial-derivative templates. Each helper treats
//  whichever variable is not being differentiated as a constant, the same tidying a person
//  does on paper.

/// `coefficient * x^xExponent * y^yExponent`. Either exponent may be 0 to drop that factor.
func partialPowerTerm(_ coefficient: Int, x xExponent: Int, y yExponent: Int) -> Expression {
    Expression.product([
        .integer(coefficient),
        .power(.x, .integer(xExponent)),
        .power(.y, .integer(yExponent))
    ]).simplified()
}

/// `∂/∂x [coefficient * x^xExponent * y^yExponent]`, holding y constant.
func partialXDerivative(_ coefficient: Int, x xExponent: Int, y yExponent: Int) -> Expression {
    guard xExponent != 0 else { return .zero }
    return Expression.product([
        .integer(coefficient * xExponent),
        .power(.x, .integer(xExponent - 1)),
        .power(.y, .integer(yExponent))
    ]).simplified()
}

/// `∂/∂y [coefficient * x^xExponent * y^yExponent]`, holding x constant.
func partialYDerivative(_ coefficient: Int, x xExponent: Int, y yExponent: Int) -> Expression {
    guard yExponent != 0 else { return .zero }
    return Expression.product([
        .integer(coefficient * yExponent),
        .power(.x, .integer(xExponent)),
        .power(.y, .integer(yExponent - 1))
    ]).simplified()
}

/// `coefficient * y^exponent`. The y-axis counterpart of `powerTerm`.
func yPowerTerm(_ coefficient: Int, _ exponent: Int) -> Expression {
    Expression.product([.integer(coefficient), .power(.y, .integer(exponent))]).simplified()
}

/// `d/dy [coefficient * y^exponent]`. The y-axis counterpart of `powerRuleDerivative`.
func yPowerRuleDerivative(_ coefficient: Int, _ exponent: Int) -> Expression {
    Expression.product([
        .integer(coefficient * exponent),
        .power(.y, .integer(exponent - 1))
    ]).simplified()
}
