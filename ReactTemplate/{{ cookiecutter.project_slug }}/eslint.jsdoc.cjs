module.exports = {
  plugins: ["jsdoc"],
  parser: "@typescript-eslint/parser",
  rules: {
    "jsdoc/require-jsdoc": [
      "warn",
      {
        require: { FunctionDeclaration: true, MethodDefinition: true },
        contexts: [
          "ExportNamedDeclaration > FunctionDeclaration",
          "ExportDefaultDeclaration > FunctionDeclaration",
        ],
      },
    ],
    "jsdoc/require-param": "warn",
    "jsdoc/require-returns": "warn",
    "jsdoc/require-param-type": "off",
    "jsdoc/require-returns-type": "off",
    "jsdoc/check-tag-names": "warn",
  },
  overrides: [
    {
      files: ["**/*.test.*", "**/*.spec.*", "**/test/**"],
      rules: { "jsdoc/require-jsdoc": "off" },
    },
  ],
};
