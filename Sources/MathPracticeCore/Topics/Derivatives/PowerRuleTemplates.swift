//  PowerRuleTemplates.swift
//  Sub-type: power rule. Polynomials, negative exponents, radicals.

/// `a x^n + b x^m + c`
struct PolynomialTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.power.polynomial")
    let subTypeID = SubTypeID.powerRule
    let displayName = "Polynomial"
    let difficultyRange = 1...7

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: 1...max(1, n - 1))
        let c = generator.drawInt(in: scale.constantRange)

        let problem = Expression.sum([
            powerTerm(a, n),
            powerTerm(b, m),
            .integer(c)
        ]).simplified()

        let firstDerivative = powerRuleDerivative(a, n)
        let secondDerivative = powerRuleDerivative(b, m)
        let answer = Expression.sum([firstDerivative, secondDerivative]).simplified()

        var steps: [SolutionStep] = [
            .narrative(
                "Apply the power rule term by term",
                latex: "\\frac{d}{dx}\\left[k x^{p}\\right] = k p\\, x^{p-1}"
            ),
            SolutionStep(title: "Differentiate \(powerTerm(a, n).latex)", expression: firstDerivative),
            SolutionStep(title: "Differentiate \(powerTerm(b, m).latex)", expression: secondDerivative)
        ]
        if c != 0 {
            steps.append(.narrative("The derivative of the constant \(c) is 0", latex: "0"))
        }
        steps.append(SolutionStep(title: "Combine the terms", expression: answer))

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "m", value: m),
                ProblemParameter(name: "c", value: c)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a x^(-n) + b x`
struct NegativeExponentTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.power.negative-exponent")
    let subTypeID = SubTypeID.powerRule
    let displayName = "Negative exponent"
    let difficultyRange = 3...9

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: 1...(scale.exponentRange.upperBound - 1))
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)

        let problem = Expression.sum([powerTerm(a, -n), powerTerm(b, 1)]).simplified()
        let firstDerivative = powerRuleDerivative(a, -n)
        let answer = Expression.sum([firstDerivative, .integer(b)]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Rewrite the reciprocal as a negative power",
                latex: "\\frac{\(a)}{x^{\(n)}} = \(powerTerm(a, -n).latex)"
            ),
            SolutionStep(title: "Apply the power rule to the negative power", expression: firstDerivative),
            SolutionStep(title: "Differentiate \(powerTerm(b, 1).latex)", expression: .integer(b)),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "b", value: b)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a sqrt(x) + b x^m`
struct RadicalTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.power.radical")
    let subTypeID = SubTypeID.powerRule
    let displayName = "Radical"
    let difficultyRange = 4...10

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: scale.exponentRange)

        let root = Expression.power(.x, .fraction(1, 2))
        let problem = Expression.sum([
            .product([.integer(a), root]),
            powerTerm(b, m)
        ]).simplified()

        // d/dx [a x^(1/2)] = (a/2) x^(-1/2)
        let rootDerivative = Expression.product([
            .fraction(a, 2),
            .power(.x, .fraction(-1, 2))
        ]).simplified()
        let polynomialDerivative = powerRuleDerivative(b, m)
        let answer = Expression.sum([rootDerivative, polynomialDerivative]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Rewrite the radical as a fractional power",
                latex: "\\sqrt{x} = x^{\\frac{1}{2}}"
            ),
            SolutionStep(title: "Apply the power rule to the radical term", expression: rootDerivative),
            SolutionStep(title: "Differentiate \(powerTerm(b, m).latex)", expression: polynomialDerivative),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "m", value: m)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}
