﻿using SPA.PQL.API;
using SPA.PQL.Elements;

namespace SPA.PQL.Evaluator {
    internal sealed class EvaluatedVariable {
        public required string VariableName { get; set; }
        public required SpaApi.StatementType StatementType { get; set; }
        public required List<EvaluatorVariableValue> Elements { get; set; }
    }
}