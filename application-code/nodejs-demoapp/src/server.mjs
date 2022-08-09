//
// Main Express server for nodejs-demoapp
// ---------------------------------------------
// Ben C, Oct 2017 - Updated: Nov 2021
//

console.log('### 🚀 Node.js demo app starting...')

// Dotenv handy for local config & debugging
import { config as dotenvConfig } from 'dotenv'
dotenvConfig()

// TODO: Configure AWS X-Ray here

// Core Express & logging stuff
import express from 'express'
import path from 'path'
import logger from 'morgan'
import session from 'express-session'

const app = new express()

// View engine setup, static content & session
const __dirname = path.resolve()
app.set('views', [path.join(__dirname, 'views'), path.join(__dirname, 'todo')])
app.set('view engine', 'ejs')
app.use(express.static(path.join(__dirname, 'public')))
app.use(
  session({
    secret: 'Shape without form, shade without colour',
    cookie: { secure: false },
    resave: false,
    saveUninitialized: false,
  })
)

// Request logging, switch off when running tests
if (process.env.NODE_ENV !== 'test') {
  app.use(logger('dev'))
}

// Parsing middleware
app.use(express.json())
app.use(express.urlencoded({ extended: false }))

// Routes & controllers
import pageRoutes from './routes/pages.mjs'
import apiRoutes from './routes/api.mjs'
// import authRoutes from './routes/auth.mjs'
import todoRoutes from './todo/routes.mjs'
app.use('/', pageRoutes)
app.use('/', apiRoutes)

// Initialize authentication only when configured
// TODO: Update to use Cognito
if (process.env.OGNITO_IDENTITY_POOL_ID) {
  // app.use('/', authRoutes)
}

// Optional routes based on certain settings/features being enabled
if (process.env.TODO_MONGO_CONNSTR) {
  app.use('/', todoRoutes)
}

// Make package app version a global var, shown in _foot.ejs
import { readFileSync } from 'fs'
const packageJson = JSON.parse(readFileSync(new URL('./package.json', import.meta.url)))
app.locals.version = packageJson.version

// Catch all route, generate an error & forward to error handler
app.use(function (req, res, next) {
  let err = new Error('Not Found')
  err.status = 404
  if (req.method != 'GET') {
    err = new Error(`Method ${req.method} not allowed`)
    err.status = 500
  }

  next(err)
})

// Error handler
app.use(function (err, req, res, next) {
  console.error(`### 💥 ERROR: ${err.message}`)

  // AWS X-Ray: Collect error here

  // Render the error page
  res.status(err.status || 500)
  res.render('error', {
    title: 'Error',
    message: err.message,
    error: err,
  })
})

// Get values from env vars or defaults where not provided
const port = process.env.PORT || 3000

// Start the server
app.listen(port)
console.log(`### 🌐 Server listening on port ${port}`)

export default app
