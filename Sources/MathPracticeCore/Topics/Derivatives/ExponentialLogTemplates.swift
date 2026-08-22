//  ExponentialLogTemplates.swift
//  Sub-type: exponential and logarithmic derivatives.

/// `a e^(kx) + b x`
struct ExponentialTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.exp-log.exponential")
    let subTypeID = SubTypeID.exponentialLogarithmic
    let displayName = "Exponential"
    let difficultyRange = 2...8

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)

        let argument = powerTerm(k, 1)
        let exponentialPart = Expression.product([
            .integer(a), .function(.exp, argument)
        ]).simplified()
        let problem = Expression.sum([exponentialPart, powerTerm(b, 1)]).simplified()

        let exponentialDerivative = Expression.product([
            .integer(a * k), .function(.exp, argument)
        ]).simplified()
        let answer = Expression.sum([exponentialDerivative, .integer(b)]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "The exponential reproduces itself, times the inner derivative",
                latex: "\\frac{d}{dx}e^{kx} = k e^{kx}"
            ),
            SolutionStep(title: "Differentiate \(exponentialPart.latex)", expression: exponentialDerivative),
            SolutionStep(title: "Differentiate \(powerTerm(b, 1).latex)", expression: .integer(b)),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "k", value: k),
                ProblemParameter(name: "b", value: b)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a ln(b x^n + c)`
struct LogarithmTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.exp-log.logarithm")
    let subTypeID = SubTypeID.exponentialLogarithmic
    let displayName = "Logarithm"
    let difficultyRange = 4...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        // The argument is kept positive-leading so the logarithm has a sensible domain.
        let b = generator.drawInt(in: 1...max(1, scale.innerCoefficientRange.upperBound))
        let n = generator.drawInt(in: 1...scale.exponentRange.upperBound)
        let c = generator.drawInt(in: 1...(1 + difficulty))

        let inner = Expression.sum([powerTerm(b, n), .integer(c)]).simplified()
        let innerDerivative = powerRuleDerivative(b, n)
        let problem = Expression.product([.integer(a), .function(.ln, inner)]).simplified()
        let answer = Expression.ratio(
            .product([.integer(a), innerDerivative]).simplified(),
            over: inner
        )

        let steps: [SolutionStep] = [
            .narrative(
                "The logarithm differentiates to the inner derivative over the argument",
                latex: "\\frac{d}{dx}\\ln(u) = \\frac{u'}{u}"
            ),
            namedPartsStep(
                title: "Name the argument",
                first: ("u", inner),
                second: ("u'", innerDerivative)
            ),
            SolutionStep(title: "Substitute and keep the outer coefficient", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "c", value: c)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}
