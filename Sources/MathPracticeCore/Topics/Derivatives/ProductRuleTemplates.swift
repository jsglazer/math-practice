//  ProductRuleTemplates.swift
//  Sub-type: product rule. Answers are left in the factored `u'v + uv'` shape a person
//  would write on paper — expanding is arithmetic, not the skill being drilled.

private let productRuleStatement = "\\frac{d}{dx}\\left[uv\\right] = u'v + uv'"

/// `(a x^n + b)(c x^m + d)`
struct PolynomialProductTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.product.polynomial")
    let subTypeID = SubTypeID.productRule
    let displayName = "Polynomial product"
    let difficultyRange = 2...8

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let c = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let m = generator.drawInt(in: 1...max(1, n - 1))
        let d = generator.drawNonZeroInt(in: scale.coefficientRange)

        let u = Expression.sum([powerTerm(a, n), .integer(b)]).simplified()
        let v = Expression.sum([powerTerm(c, m), .integer(d)]).simplified()
        let uPrime = powerRuleDerivative(a, n)
        let vPrime = powerRuleDerivative(c, m)

        let problem = Expression.product([u, v]).simplified()
        let answer = Expression.sum([
            .product([uPrime, v]),
            .product([u, vPrime])
        ]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(title: "Name the factors", first: ("u", u), second: ("v", v)),
            namedPartsStep(title: "Differentiate each factor", first: ("u'", uPrime), second: ("v'", vPrime)),
            .narrative("Apply the product rule", latex: productRuleStatement),
            SolutionStep(title: "Substitute", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "c", value: c),
                ProblemParameter(name: "m", value: m),
                ProblemParameter(name: "d", value: d)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a x^n sin(kx)` or `a x^n cos(kx)`
struct PolynomialTrigProductTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.product.polynomial-trig")
    let subTypeID = SubTypeID.productRule
    let displayName = "Polynomial x trig"
    let difficultyRange = 4...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let choice = generator.drawElement(from: TrigChoice.allCases) ?? .sine

        let argument = powerTerm(k, 1)
        let u = powerTerm(a, n)
        let v = Expression.function(choice.function, argument)
        let uPrime = powerRuleDerivative(a, n)
        // The inner derivative of `kx` is `k`, so the chain factor is a bare constant.
        let vPrime = Expression.product([.integer(k), choice.derivative(of: argument)]).simplified()

        let problem = Expression.product([u, v]).simplified()
        let answer = Expression.sum([
            .product([uPrime, v]),
            .product([u, vPrime])
        ]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(title: "Name the factors", first: ("u", u), second: ("v", v)),
            namedPartsStep(title: "Differentiate each factor", first: ("u'", uPrime), second: ("v'", vPrime)),
            .narrative("Apply the product rule", latex: productRuleStatement),
            SolutionStep(title: "Substitute", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "k", value: k),
                ProblemParameter(name: "trig", value: choice == .sine ? 0 : 1)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `(a x^n + b) e^(kx)`
struct ExponentialProductTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.product.exponential")
    let subTypeID = SubTypeID.productRule
    let displayName = "Polynomial x exponential"
    let difficultyRange = 5...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)

        let u = Expression.sum([powerTerm(a, n), .integer(b)]).simplified()
        let v = Expression.function(.exp, powerTerm(k, 1))
        let uPrime = powerRuleDerivative(a, n)
        let vPrime = Expression.product([.integer(k), v]).simplified()

        let problem = Expression.product([u, v]).simplified()
        let answer = Expression.sum([
            .product([uPrime, v]),
            .product([u, vPrime])
        ]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(title: "Name the factors", first: ("u", u), second: ("v", v)),
            .narrative(
                "The exponential brings down its inner coefficient",
                latex: "\\frac{d}{dx}\\left[e^{\(powerTerm(k, 1).latex)}\\right] = \(vPrime.latex)"
            ),
            namedPartsStep(title: "Differentiate each factor", first: ("u'", uPrime), second: ("v'", vPrime)),
            .narrative("Apply the product rule", latex: productRuleStatement),
            SolutionStep(title: "Substitute", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "k", value: k)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}
