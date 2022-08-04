module.exports = {
  root: true,
  env: {
    es2020: true,
    node: true,
    es6: true,
    mocha: true,
    browser: true,
  },
  extends: ['eslint:recommended'],
  ignorePatterns: ['mochawesome-report/**'],
  rules: {
    // Errors & best practices
    'no-var': 'error',
    'no-console': 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-unused-vars': ['error', { argsIgnorePattern: 'next|res|req' }],

    'prefer-const': 'error',

    // ES6
    'arrow-spacing': 'error',
    'arrow-parens': 'error',
  },
  parserOptions: {
    ecmaVersion: '2020',
    sourceType: 'module',
  },
}
