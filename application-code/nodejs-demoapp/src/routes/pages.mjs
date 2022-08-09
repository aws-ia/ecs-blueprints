//
// HTML page routes, that render ejs templates
// --------------------------------------------------
// Ben C, Jan 2020 - Updated Jul 2022 by Michael Fischer
//

import express from 'express'
const router = express.Router()
import os from 'os'
import fs from 'fs'

// =======================================================================
// Middleware to pass user data from session to all views
// =======================================================================
router.use(function (req, res, next) {
  if (req.session.user) {
    res.locals.user = req.session.user
  }
  next()
})

// =======================================================================
// Get home page and index
// =======================================================================
router.get('/', function (req, res, next) {
  res.render('index', {
    title: 'Node DemoApp: Home',
  })
})

// =======================================================================
// Get system & runtime info
// =======================================================================
router.get('/info', function (req, res, next) {
  const info = {
    release: os.release(),
    type: os.type(),
    cpus: os.cpus(),
    hostname: os.hostname(),
    arch: os.arch(),
    mem: Math.round(os.totalmem() / 1048576),
    env: process.env.WEBSITE_SITE_NAME ? process.env.WEBSITE_SITE_NAME.split('-')[0] : 'Local',
    nodever: process.version,
    uptime: convertSeconds(os.uptime()),
  }

  const isKube = fs.existsSync('/var/run/secrets/kubernetes.io')
  let isContainer = isKube || fs.existsSync('/.dockerenv')

  // Fallback to try to detect containerd, only works when *NOT* in Kubernetes
  if (!isContainer) {
    try {
      const cgroup = fs.readFileSync('/proc/1/cgroup', 'utf8')
      if (cgroup.includes('containerd')) {
        isContainer = true
      }
    } catch (err) {
      isContainer = false
    }
  }

  res.render('info', {
    title: 'Node DemoApp: Info',
    info: info,
    isKube: isKube,
    isContainer: isContainer,
  })
})

// =======================================================================
// Get monitor page
// =======================================================================
router.get('/monitor', function (req, res, next) {
  res.render('monitor', {
    title: 'Node DemoApp: Monitoring',
  })
})

// =======================================================================
// Get weather page
// =======================================================================
router.get('/weather', function (req, res, next) {
  res.render('weather', {
    title: 'Node DemoApp: Weather',
  })
})

// =======================================================================
// Tools page
// =======================================================================
router.get('/tools', function (req, res, next) {
  res.render('tools', {
    title: 'Node DemoApp: Tools',
  })
})

// =======================================================================
// Page to generate CPU load
// =======================================================================
router.get('/tools/load', function (req, res, next) {
  const start = new Date().getTime()
  for (let i = 0; i < 499900000.0; i++) {
    Math.pow(9000.0, 9000.0)
  }

  const time = new Date().getTime() - start

  res.render('tools', {
    title: 'Node DemoApp: Tools',
    message: `I did some really hard sums and it only took me ${time} milliseconds!`,
  })
})

// =======================================================================
// Page to generate server side errors, good for X-Ray demos
// =======================================================================
// eslint-disable-next-line no-unused-vars
router.get('/tools/error', function (req, res, next) {
  // Call some gibberish (object doesn't exist) which should trigger an exception
  // eslint-disable-next-line no-undef
  beansOnToast.eat()
})

// =======================================================================
// Page to force GC
// =======================================================================
router.get('/tools/gc', function (req, res, next) {
  let message = 'Garbage collector was not able to run'
  try {
    if (global.gc) {
      global.gc()
      message = 'Garbage collector was run'
    }
  } catch (e) {
    // DO nothing
  }

  res.render('tools', {
    title: 'Node DemoApp: Tools',
    message: message,
  })
})

export default router

// ******* UTILS HERE *************************************************************

// Util to convert seconds to DD:HH:MM:SS
function convertSeconds(n) {
  const days = Math.floor(n / (24 * 3600))
  n = n % (24 * 3600)
  const hours = Math.floor(n / 3600)
  n %= 3600
  const mins = Math.floor(n / 60)
  n %= 60
  const secs = Math.round(n)
  return `${days} days, ${hours} hours, ${mins} mins, ${secs} seconds`
}
