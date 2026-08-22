//  ChainRuleTemplates.swift
//  Sub-type: chain rule.

private let chainRuleStatement = "\\frac{d}{dx}\\left[f(g(x))\\right] = f'(g(x))\\, g'(x)"

/// `(a x^n + b)^m`
struct PowerOfPolynomialTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.chain.power")
    let subTypeID = SubTypeID.chainRule
    let displayName = "Power of a polynomial"
    let difficultyRange = 3...9

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let n = generator.drawInt(in: 1...scale.exponentRange.upperBound)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: 2...max(2, scale.exponentRange.upperBound - 1))

        let inner = Expression.sum([powerTerm(a, n), .integer(b)]).simplified()
        let innerDerivative = powerRuleDerivative(a, n)
        let problem = Expression.power(inner, .integer(m)).simplified()
        let outerDerivative = Expression.product([
            .integer(m),
            .power(inner, .integer(m - 1))
        ]).simplified()
        let answer = Expression.product([outerDerivative, innerDerivative]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(
                title: "Name the inner function",
                first: ("g(x)", inner),
                second: ("g'(x)", innerDerivative)
            ),
            .narrative("Apply the chain rule", latex: chainRuleStatement),
            SolutionStep(title: "Differentiate the outer power", expression: outerDerivative),
            SolutionStep(title: "Multiply by the inner derivative", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "m", value: m)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `sin(a x^n + b)` or `cos(a x^n + b)`
struct TrigOfPolynomialTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.chain.trig")
    let subTypeID = SubTypeID.chainRule
    let displayName = "Trig of a polynomial"
    let difficultyRange = 4...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let n = generator.drawInt(in: 1...scale.exponentRange.upperBound)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let choice = generator.drawElement(from: TrigChoice.allCases) ?? .sine

        let inner = Expression.sum([powerTerm(a, n), .integer(b)]).simplified()
        let innerDerivative = powerRuleDerivative(a, n)
        let problem = Expression.function(choice.function, inner)
        let outerDerivative = choice.derivative(of: inner)
        let answer = Expression.product([outerDerivative, innerDerivative]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(
                title: "Name the inner function",
                first: ("g(x)", inner),
                second: ("g'(x)", innerDerivative)
            ),
            .narrative("Apply the chain rule", latex: chainRuleStatement),
            SolutionStep(
                title: "Differentiate the outer \(choice.displayName)",
                expression: outerDerivative
            ),
            SolutionStep(title: "Multiply by the inner derivative", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "trig", value: choice == .sine ? 0 : 1)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `sqrt(a x^2 + b)`
struct RadicalOfPolynomialTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.chain.radical")
    let subTypeID = SubTypeID.chainRule
    let displayName = "Radical of a polynomial"
    let difficultyRange = 5...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        // Both coefficients stay positive so the radicand is positive everywhere and the
        // problem has no hidden domain restriction to reason about.
        let a = generator.drawInt(in: 1...max(1, scale.innerCoefficientRange.upperBound))
        let b = generator.drawInt(in: 1...(1 + difficulty))

        let inner = Expression.sum([powerTerm(a, 2), .integer(b)]).simplified()
        let innerDerivative = powerRuleDerivative(a, 2)
        let problem = Expression.function(.sqrt, inner)

        // (1/2)(inner)^(-1/2) * 2ax  ->  ax / sqrt(inner)
        let halfPower = Expression.product([
            .fraction(1, 2),
            .power(inner, .fraction(-1, 2))
        ]).simplified()
        let answer = Expression.ratio(powerTerm(a, 1), over: .function(.sqrt, inner))

        let steps: [SolutionStep] = [
            .narrative(
                "Rewrite the radical as a fractional power",
                latex: "\\sqrt{\(inner.latex)} = \\left(\(inner.latex)\\right)^{\\frac{1}{2}}"
            ),
            namedPartsStep(
                title: "Name the inner function",
                first: ("g(x)", inner),
                second: ("g'(x)", innerDerivative)
            ),
            .narrative("Apply the chain rule", latex: chainRuleStatement),
            SolutionStep(title: "Differentiate the outer power", expression: halfPower),
            SolutionStep(title: "Multiply by the inner derivative and simplify", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "b", value: b)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}
