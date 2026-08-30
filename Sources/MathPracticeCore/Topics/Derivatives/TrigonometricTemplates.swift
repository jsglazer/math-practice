//  TrigonometricTemplates.swift
//  Sub-type: trigonometric derivatives.

/// `a sin(kx) + b cos(kx)`
struct SineCosineTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.trig.sine-cosine")
    let subTypeID = SubTypeID.trigonometric
    let displayName = "Sine and cosine"
    let difficultyRange = 2...8

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)

        let argument = powerTerm(k, 1)
        let sinePart = Expression.product([.integer(a), .function(.sin, argument)]).simplified()
        let cosinePart = Expression.product([.integer(b), .function(.cos, argument)]).simplified()
        let problem = Expression.sum([sinePart, cosinePart]).simplified()

        let sineDerivative = Expression.product([
            .integer(a * k), .function(.cos, argument)
        ]).simplified()
        let cosineDerivative = Expression.product([
            .integer(-b * k), .function(.sin, argument)
        ]).simplified()
        let answer = Expression.sum([sineDerivative, cosineDerivative]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Recall the trig derivatives, each with its chain factor",
                latex: "\\frac{d}{dx}\\sin(kx) = k\\cos(kx),\\quad \\frac{d}{dx}\\cos(kx) = -k\\sin(kx)"
            ),
            SolutionStep(title: "Differentiate $\(sinePart.latex)$", expression: sineDerivative),
            SolutionStep(title: "Differentiate $\(cosinePart.latex)$", expression: cosineDerivative),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "k", value: k)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a tan(kx)` or `a sec(kx)`
struct TangentSecantTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.trig.tangent-secant")
    let subTypeID = SubTypeID.trigonometric
    let displayName = "Tangent and secant"
    let difficultyRange = 5...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let usesTangent = generator.drawBool(numerator: 1, denominator: 2)

        let argument = powerTerm(k, 1)
        let function: MathFunction = usesTangent ? .tan : .sec
        let problem = Expression.product([.integer(a), .function(function, argument)]).simplified()

        // d/dx tan(u) = sec^2(u) u'   |   d/dx sec(u) = sec(u)tan(u) u'
        let outerDerivative: Expression = usesTangent
            ? .power(.function(.sec, argument), .integer(2))
            : .product([.function(.sec, argument), .function(.tan, argument)])
        let answer = Expression.product([
            .integer(a * k),
            outerDerivative
        ]).simplified()

        let ruleLatex = usesTangent
            ? "\\frac{d}{dx}\\tan(u) = \\sec^{2}(u)\\, u'"
            : "\\frac{d}{dx}\\sec(u) = \\sec(u)\\tan(u)\\, u'"

        let steps: [SolutionStep] = [
            .narrative("Recall the derivative of the outer function", latex: ruleLatex),
            .narrative(
                "The inner function is $\(argument.latex)$, so the chain factor is \(k)",
                latex: "u = \(argument.latex),\\quad u' = \(k)"
            ),
            SolutionStep(title: "Multiply through", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "k", value: k),
                ProblemParameter(name: "function", value: usesTangent ? 0 : 1)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}
