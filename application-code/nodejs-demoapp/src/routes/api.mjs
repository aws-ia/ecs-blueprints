//
// API routes, that return JSON
// ---------------------------------------------
// Ben C, Jan 2020
//

import express from 'express'
const router = express.Router()
import os from 'os'
import fs from 'fs'
import axios from 'axios'

// =======================================================================
// Get weather data as JSON
// =======================================================================
router.get('/api/weather/:lat/:long', async function (req, res, next) {
  const WEATHER_API_KEY = process.env.WEATHER_API_KEY || '123456'
  const long = req.params.long
  const lat = req.params.lat

  // Call OpenWeather API
  try {
    const weatherResp = await axios.get(
      `https://api.openweathermap.org/data/2.5/weather?units=metric&lat=${lat}&lon=${long}&appid=${WEATHER_API_KEY}`
    )

    if (weatherResp.data) {
      //if (appInsights.defaultClient && weatherResp.data.main) {
      //  appInsights.defaultClient.trackMetric({ name: 'weatherTemp', value: weatherResp.data.main.temp })
      //}

      // Proxy the OpenWeather response through to the caller
      res.status(200).send(weatherResp.data)
    } else {
      throw new Error(`Current weather not available for: ${long},${lat}`)
    }
  } catch (e) {
    return res.status(500).send(`API error fetching weather: ${e.toString()}`)
  }
})

// =======================================================================
// API for live monitoring (CPU and memory) data
// =======================================================================
router.get('/api/monitoringdata', async function (req, res, next) {
  const data = {
    container: false,
    memUsedBytes: 0,
    memTotalBytes: 0,
    memAppUsedBytes: 0,
    cpuAppPercentage: 0,
  }

  // Gather monitoring data
  try {
    // MEMORY
    if (fs.existsSync('/.dockerenv')) {
      data.container = true

      // Read cgroup container memory info
      data.memUsedBytes = parseInt(fs.readFileSync('/sys/fs/cgroup/memory/memory.usage_in_bytes', 'utf8'))
      data.memTotalBytes = parseInt(fs.readFileSync('/sys/fs/cgroup/memory/memory.limit_in_bytes', 'utf8'))

      // limit_in_bytes might not be set, in which case it contains some HUGE number
      // Fall back to using os.totalmem()
      if (data.memTotalBytes > 90000000000000) {
        data.memTotalBytes = os.totalmem()
      }
    } else {
      data.free = os.freemem()
      data.memUsedBytes = os.totalmem() - os.freemem()
      data.memTotalBytes = os.totalmem()
    }
    data.memProcUsedBytes = process.memoryUsage().rss

    // CPU
    const startUsage = process.cpuUsage()
    const D_TIME = 1000
    // pause
    const timeout = (ms) => new Promise((res) => setTimeout(res, ms))
    await timeout(D_TIME)
    // Get results/delta
    const cpuResult = process.cpuUsage(startUsage)
    data.cpuAppPercentage = (cpuResult.user / 1000 / D_TIME) * 100

    return res.status(200).send(data)
  } catch (e) {
    return res.status(500).send({ error: true, title: 'Monitoring API error', message: e.toString() })
  }
})

// module.exports = router
export default router
