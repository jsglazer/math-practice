//  PartialDerivativeTemplates.swift
//  Sub-type: partial derivatives. First-order ∂/∂x and ∂/∂y of two-variable expressions,
//  each holding the other variable constant. Four families (polynomial, product,
//  exponential, trig), each drawn once as `∂/∂x` and once as `∂/∂y`.

/// `a x^n y^m + b x^p + c y^q`, differentiated with respect to x.
struct PartialPolynomialXTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.polynomial-x")
    let subTypeID = SubTypeID.partial
    let displayName = "Polynomial (∂/∂x)"
    let difficultyRange = 1...8
    let verificationRule = VerificationRule.partialDerivativeX
    var instruction: String { "Find ∂f/∂x, treating y as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let m = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let p = generator.drawInt(in: scale.exponentRange)
        let c = generator.drawNonZeroInt(in: scale.coefficientRange)
        let q = generator.drawInt(in: scale.exponentRange)

        let mixedTerm = partialPowerTerm(a, x: n, y: m)
        let xTerm = partialPowerTerm(b, x: p, y: 0)
        let yTerm = partialPowerTerm(c, x: 0, y: q)
        let problem = Expression.sum([mixedTerm, xTerm, yTerm]).simplified()

        let mixedDerivative = partialXDerivative(a, x: n, y: m)
        let xTermDerivative = partialXDerivative(b, x: p, y: 0)
        let answer = Expression.sum([mixedDerivative, xTermDerivative]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Differentiate term by term, holding y constant",
                latex: "\\frac{\\partial}{\\partial x}\\left[k x^{p} y^{q}\\right] = k p\\, x^{p-1} y^{q}"
            ),
            SolutionStep(title: "Differentiate \(mixedTerm.latex)", expression: mixedDerivative),
            SolutionStep(title: "Differentiate \(xTerm.latex)", expression: xTermDerivative),
            .narrative("\(yTerm.latex) has no x in it, so it is constant here", latex: "0"),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "m", value: m),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "p", value: p),
                ProblemParameter(name: "c", value: c),
                ProblemParameter(name: "q", value: q)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a x^n y^m + b x^p + c y^q`, differentiated with respect to y.
struct PartialPolynomialYTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.polynomial-y")
    let subTypeID = SubTypeID.partial
    let displayName = "Polynomial (∂/∂y)"
    let difficultyRange = 1...8
    let verificationRule = VerificationRule.partialDerivativeY
    var instruction: String { "Find ∂f/∂y, treating x as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let m = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let p = generator.drawInt(in: scale.exponentRange)
        let c = generator.drawNonZeroInt(in: scale.coefficientRange)
        let q = generator.drawInt(in: scale.exponentRange)

        let mixedTerm = partialPowerTerm(a, x: n, y: m)
        let xTerm = partialPowerTerm(b, x: p, y: 0)
        let yTerm = partialPowerTerm(c, x: 0, y: q)
        let problem = Expression.sum([mixedTerm, xTerm, yTerm]).simplified()

        let mixedDerivative = partialYDerivative(a, x: n, y: m)
        let yTermDerivative = partialYDerivative(c, x: 0, y: q)
        let answer = Expression.sum([mixedDerivative, yTermDerivative]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Differentiate term by term, holding x constant",
                latex: "\\frac{\\partial}{\\partial y}\\left[k x^{p} y^{q}\\right] = k q\\, x^{p} y^{q-1}"
            ),
            SolutionStep(title: "Differentiate \(mixedTerm.latex)", expression: mixedDerivative),
            SolutionStep(title: "Differentiate \(yTerm.latex)", expression: yTermDerivative),
            .narrative("\(xTerm.latex) has no y in it, so it is constant here", latex: "0"),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "m", value: m),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "p", value: p),
                ProblemParameter(name: "c", value: c),
                ProblemParameter(name: "q", value: q)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `(a x^n + p)(b y^m + q)`, differentiated with respect to x.
struct PartialProductXTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.product-x")
    let subTypeID = SubTypeID.partial
    let displayName = "Product of factors (∂/∂x)"
    let difficultyRange = 3...9
    let verificationRule = VerificationRule.partialDerivativeX
    var instruction: String { "Find ∂f/∂x, treating y as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let p = generator.drawInt(in: scale.constantRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: scale.exponentRange)
        let q = generator.drawInt(in: scale.constantRange)

        let xFactor = Expression.sum([powerTerm(a, n), .integer(p)]).simplified()
        let yFactor = Expression.sum([yPowerTerm(b, m), .integer(q)]).simplified()
        let problem = Expression.product([xFactor, yFactor]).simplified()

        let xFactorDerivative = powerRuleDerivative(a, n)
        let answer = Expression.product([xFactorDerivative, yFactor]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(
                title: "Name the two factors",
                first: (name: "u", expression: xFactor),
                second: (name: "v", expression: yFactor)
            ),
            .narrative(
                "Holding y constant, v is a constant multiplier",
                latex: "\\frac{\\partial}{\\partial x}\\left[u \\cdot v\\right] = \\frac{\\partial u}{\\partial x} \\cdot v"
            ),
            SolutionStep(title: "Differentiate u with respect to x", expression: xFactorDerivative),
            SolutionStep(title: "Multiply by v", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "p", value: p),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "m", value: m),
                ProblemParameter(name: "q", value: q)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `(a x^n + p)(b y^m + q)`, differentiated with respect to y.
struct PartialProductYTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.product-y")
    let subTypeID = SubTypeID.partial
    let displayName = "Product of factors (∂/∂y)"
    let difficultyRange = 3...9
    let verificationRule = VerificationRule.partialDerivativeY
    var instruction: String { "Find ∂f/∂y, treating x as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let p = generator.drawInt(in: scale.constantRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: scale.exponentRange)
        let q = generator.drawInt(in: scale.constantRange)

        let xFactor = Expression.sum([powerTerm(a, n), .integer(p)]).simplified()
        let yFactor = Expression.sum([yPowerTerm(b, m), .integer(q)]).simplified()
        let problem = Expression.product([xFactor, yFactor]).simplified()

        let yFactorDerivative = yPowerRuleDerivative(b, m)
        let answer = Expression.product([xFactor, yFactorDerivative]).simplified()

        let steps: [SolutionStep] = [
            namedPartsStep(
                title: "Name the two factors",
                first: (name: "u", expression: xFactor),
                second: (name: "v", expression: yFactor)
            ),
            .narrative(
                "Holding x constant, u is a constant multiplier",
                latex: "\\frac{\\partial}{\\partial y}\\left[u \\cdot v\\right] = u \\cdot \\frac{\\partial v}{\\partial y}"
            ),
            SolutionStep(title: "Differentiate v with respect to y", expression: yFactorDerivative),
            SolutionStep(title: "Multiply by u", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "p", value: p),
                ProblemParameter(name: "b", value: b),
                ProblemParameter(name: "m", value: m),
                ProblemParameter(name: "q", value: q)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a x^n e^(k y)`, differentiated with respect to x.
struct PartialExponentialXTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.exponential-x")
    let subTypeID = SubTypeID.partial
    let displayName = "Exponential (∂/∂x)"
    let difficultyRange = 4...10
    let verificationRule = VerificationRule.partialDerivativeX
    var instruction: String { "Find ∂f/∂x, treating y as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)

        let expFactor = Expression.function(.exp, scaled(k, .y))
        let problem = Expression.product([.integer(a), .power(.x, .integer(n)), expFactor]).simplified()

        let xDerivative = powerRuleDerivative(a, n)
        let answer = Expression.product([xDerivative, expFactor]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Holding y constant, e^{ky} is a constant multiplier",
                latex: "\\frac{\\partial}{\\partial x}\\left[a x^{n} e^{ky}\\right] = a n\\, x^{n-1} e^{ky}"
            ),
            SolutionStep(title: "Differentiate the power of x", expression: xDerivative),
            SolutionStep(title: "Multiply by \(expFactor.latex)", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "k", value: k)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a x^n e^(k y)`, differentiated with respect to y.
struct PartialExponentialYTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.exponential-y")
    let subTypeID = SubTypeID.partial
    let displayName = "Exponential (∂/∂y)"
    let difficultyRange = 4...10
    let verificationRule = VerificationRule.partialDerivativeY
    var instruction: String { "Find ∂f/∂y, treating x as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)

        let expFactor = Expression.function(.exp, scaled(k, .y))
        let xPart = Expression.product([.integer(a), .power(.x, .integer(n))]).simplified()
        let problem = Expression.product([xPart, expFactor]).simplified()

        // d/dy [e^(ky)] = k e^(ky), by the chain rule.
        let expDerivative = Expression.product([.integer(k), expFactor]).simplified()
        let answer = Expression.product([xPart, expDerivative]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Holding x constant, a x^{n} is a constant multiplier; apply the chain rule to e^{ky}",
                latex: "\\frac{\\partial}{\\partial y}\\left[a x^{n} e^{ky}\\right] = a x^{n} k\\, e^{ky}"
            ),
            SolutionStep(title: "Differentiate \(expFactor.latex) with respect to y", expression: expDerivative),
            SolutionStep(title: "Multiply by \(xPart.latex)", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "n", value: n),
                ProblemParameter(name: "k", value: k)
            ],
            problem: problem,
            answer: answer,
            steps: steps
        )
    }
}

/// `a sin(k x) y^n + b y^m`, differentiated with respect to x.
struct PartialTrigXTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.trig-x")
    let subTypeID = SubTypeID.partial
    let displayName = "Trigonometric (∂/∂x)"
    let difficultyRange = 4...10
    let verificationRule = VerificationRule.partialDerivativeX
    var instruction: String { "Find ∂f/∂x, treating y as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: scale.exponentRange)

        let sineFactor = Expression.function(.sin, scaled(k, .x))
        let trigTerm = Expression.product([.integer(a), sineFactor, .power(.y, .integer(n))]).simplified()
        let yTerm = yPowerTerm(b, m)
        let problem = Expression.sum([trigTerm, yTerm]).simplified()

        // d/dx [a sin(kx) y^n] = a k cos(kx) y^n, by the chain rule; b y^m has no x.
        let cosineFactor = Expression.function(.cos, scaled(k, .x))
        let answer = Expression.product([.integer(a * k), cosineFactor, .power(.y, .integer(n))]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Apply the chain rule to the sine factor, holding y constant",
                latex: "\\frac{\\partial}{\\partial x}\\left[\\sin(kx)\\right] = k\\cos(kx)"
            ),
            SolutionStep(title: "Differentiate \(trigTerm.latex)", expression: answer),
            .narrative("\(yTerm.latex) has no x in it, so it is constant here", latex: "0")
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "k", value: k),
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

/// `a sin(k x) y^n + b y^m`, differentiated with respect to y.
struct PartialTrigYTemplate: ProblemTemplate {
    let id = TemplateID("derivatives.partial.trig-y")
    let subTypeID = SubTypeID.partial
    let displayName = "Trigonometric (∂/∂y)"
    let difficultyRange = 4...10
    let verificationRule = VerificationRule.partialDerivativeY
    var instruction: String { "Find ∂f/∂y, treating x as a constant" }

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let scale = DifficultyScale(difficulty: difficulty)
        let a = generator.drawNonZeroInt(in: scale.coefficientRange)
        let k = generator.drawNonZeroInt(in: scale.innerCoefficientRange)
        let n = generator.drawInt(in: scale.exponentRange)
        let b = generator.drawNonZeroInt(in: scale.coefficientRange)
        let m = generator.drawInt(in: scale.exponentRange)

        let sineFactor = Expression.function(.sin, scaled(k, .x))
        let trigTerm = Expression.product([.integer(a), sineFactor, .power(.y, .integer(n))]).simplified()
        let yTerm = yPowerTerm(b, m)
        let problem = Expression.sum([trigTerm, yTerm]).simplified()

        // d/dy [a sin(kx) y^n] = a n sin(kx) y^(n-1); sin(kx) is constant here.
        let trigTermDerivative = Expression.product([
            .integer(a * n),
            sineFactor,
            .power(.y, .integer(n - 1))
        ]).simplified()
        let yTermDerivative = yPowerRuleDerivative(b, m)
        let answer = Expression.sum([trigTermDerivative, yTermDerivative]).simplified()

        let steps: [SolutionStep] = [
            .narrative(
                "Holding x constant, sin(kx) is a constant multiplier",
                latex: "\\frac{\\partial}{\\partial y}\\left[a \\sin(kx) y^{n}\\right] = a \\sin(kx)\\, n y^{n-1}"
            ),
            SolutionStep(title: "Differentiate \(trigTerm.latex)", expression: trigTermDerivative),
            SolutionStep(title: "Differentiate \(yTerm.latex)", expression: yTermDerivative),
            SolutionStep(title: "Combine the terms", expression: answer)
        ]

        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "k", value: k),
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
