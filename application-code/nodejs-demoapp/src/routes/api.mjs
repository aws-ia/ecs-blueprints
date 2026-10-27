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

function readContainerMemory() {
  const layouts = [
    {
      usage: '/sys/fs/cgroup/memory.current',
      limit: '/sys/fs/cgroup/memory.max',
    },
    {
      usage: '/sys/fs/cgroup/memory/memory.usage_in_bytes',
      limit: '/sys/fs/cgroup/memory/memory.limit_in_bytes',
    },
  ]
  const layout = layouts.find(({ usage, limit }) => fs.existsSync(usage) && fs.existsSync(limit))

  if (!layout) {
    return null
  }

  const usage = Number.parseInt(fs.readFileSync(layout.usage, 'utf8').trim(), 10)
  const rawLimit = fs.readFileSync(layout.limit, 'utf8').trim()
  const limit = rawLimit === 'max' ? os.totalmem() : Number.parseInt(rawLimit, 10)

  if (!Number.isFinite(usage) || !Number.isFinite(limit)) {
    return null
  }

  return {
    usage,
    limit: limit > 90000000000000 ? os.totalmem() : limit,
  }
}

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
    console.error('Weather API request failed', {
      code: e.code,
      status: e.response?.status,
    })
    return res.status(500).send({ error: 'Weather data is temporarily unavailable' })
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
    memProcUsedBytes: 0,
    cpuAppPercentage: 0,
  }

  // Gather monitoring data
  try {
    // MEMORY
    if (fs.existsSync('/.dockerenv')) {
      data.container = true
      const memory = readContainerMemory()
      data.memUsedBytes = memory?.usage ?? os.totalmem() - os.freemem()
      data.memTotalBytes = memory?.limit ?? os.totalmem()
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
