module.exports = {
  env: {
    es2022: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2022,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "indent": "off",
    "max-len": "off",
    "require-jsdoc": "off",
    "comma-dangle": "off",
    "object-curly-spacing": "off",
    "no-empty": "off",
    "no-prototype-builtins": "off",
    "guard-for-in": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
