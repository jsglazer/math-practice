//  QuotientRuleTemplates.swift
//  Sub-type: quotient rule.

private let quotientRuleStatement = "\\frac{d}{dx}\\left[\\frac{u}{v}\\right] = \\frac{u'v - uv'}{v^{2}}"

/// Builds the unsimplified `\frac{u'v - uv'}{v^2}` an answer is checked against.
private func quotientRuleForm(
    u: Expression,
    uPrime: Expression,
    v: Expression,
    vPrime: Expression
) -> Expression {
    let numerator = Expression.sum([
        .product([uPrime, v]),
        Expression.product([u, vPrime]).negated
    ]).simplified()
    return Expression.ratio(numerator, over: .power(v, .integer(2)))
}

/// `(a x + b) / (c x + d)`
struct LinearQuotientTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.quotient.linear")
    let subTypeID = SubTypeID.quotientRule
    let displayName = "Linear over linear"
    let difficultyRange = 2...7

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let c = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        var d = generator.drawNonZeroInt(in: scale.coefficientRange)
        // ad - bc == 0 makes the quotient a constant and its derivative 0, which teaches
        // nothing. Nudge d until the numerator survives; the nudge is deterministic.
        while a * d - b * c == 0 || d == 0 {
            d += 1
        }

        let u = Expression.sum([powerTerm(a, 1), .integer(b)]).simplified()
        let v = Expression.sum([powerTerm(c, 1), .integer(d)]).simplified()
        let uPrime = Expression.integer(a)
        let vPrime = Expression.integer(c)

        let problem = Expression.ratio(u, over: v)
        let unsimplified = quotientRuleForm(u: u, uPrime: uPrime, v: v, vPrime: vPrime)
        // a(cx+d) - c(ax+b) collapses exactly to the constant ad - bc.
        let answer = Expression.ratio(.integer(a * d - b * c), over: .power(v, .integer(2)))

        let steps: [SolutionStep] = [
            namedPartsStep(title: "Name the parts", first: ("u", u), second: ("v", v)),
            namedPartsStep(title: "Differentiate each part", first: ("u'", uPrime), second: ("v'", vPrime)),
            .narrative("Apply the quotient rule", latex: quotientRuleStatement),
            SolutionStep(title: "Substitute", expression: unsimplified),
            SolutionStep(title: "Expand and collect the numerator", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "c", value: c),
                ProblemParameter(name: "d", value: d)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `(a x^n + b) / (x^2 + c)`
struct PolynomialQuotientTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.quotient.polynomial")
    let subTypeID = SubTypeID.quotientRule
    let displayName = "Polynomial over quadratic"
    let difficultyRange = 5...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let c = generator.drawNonZeroInt(in: 1...(1 + difficulty))

        let u = Expression.sum([powerTerm(a, n), .integer(b)]).simplified()
        let v = Expression.sum([powerTerm(1, 2), .integer(c)]).simplified()
        let uPrime = powerRuleDerivative(a, n)
        let vPrime = powerRuleDerivative(1, 2)

        let problem = Expression.ratio(u, over: v)
        let answer = quotientRuleForm(u: u, uPrime: uPrime, v: v, vPrime: vPrime)

        let steps: [SolutionStep] = [
            namedPartsStep(title: "Name the parts", first: ("u", u), second: ("v", v)),
            namedPartsStep(title: "Differentiate each part", first: ("u'", uPrime), second: ("v'", vPrime)),
            .narrative("Apply the quotient rule", latex: quotientRuleStatement),
            SolutionStep(title: "Substitute", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "c", value: c)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `sin(kx) / x^n` or `cos(kx) / x^n`
struct TrigQuotientTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.quotient.trig")
    let subTypeID = SubTypeID.quotientRule
    let displayName = "Trig over polynomial"
    let difficultyRange = 6...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let n = generator.drawInt(in: 1...scale.exponentRange.upperBound)
        let choice = generator.drawElement(from: TrigChoice.allCases) ?? .sine

        let argument = powerTerm(k, 1)
        let u = Expression.function(choice.function, argument)
        let v = Expression.power(.x, .integer(n)).simplified()
        let uPrime = Expression.product([.integer(k), choice.derivative(of: argument)]).simplified()
        let vPrime = powerRuleDerivative(1, n)

        let problem = Expression.ratio(u, over: v)
        let answer = quotientRuleForm(u: u, uPrime: uPrime, v: v, vPrime: vPrime)

        let steps: [SolutionStep] = [
            namedPartsStep(title: "Name the parts", first: ("u", u), second: ("v", v)),
            namedPartsStep(title: "Differentiate each part", first: ("u'", uPrime), second: ("v'", vPrime)),
            .narrative("Apply the quotient rule", latex: quotientRuleStatement),
            SolutionStep(title: "Substitute", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "k", value: k),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "trig", value: choice == .sine ? 0 : 1)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}
