console.log = function () {}

import assert from 'node:assert/strict'
import request from 'supertest'
import app, { sessionCookieOptions } from '../server.mjs'

describe('Session cookie security', function () {
  it('Requires HTTPS and browser-only access', function () {
    assert.deepEqual(sessionCookieOptions, {
      secure: true,
      httpOnly: true,
      sameSite: 'lax',
    })
  })
})

describe('Check home page', function () {
  it('Responds with 200 & HTML', function (done) {
    request(app)
      .get('/')
      .expect('Content-Type', /html/)
      .expect(/Ben Coleman/)
      .expect(/integrity="sha384-ka7Sk0Gln4gmtz2MlQnikT1wXgYsOg\+OMhuP\+IlRH9sENBO0LRn5q\+8nbTov4\+1p"/)
      .expect(200, done)
  })
})

describe('Check info results', function () {
  it('Responds with valid info', function (done) {
    request(app)
      .get('/info')
      .expect(/Node Version/)
      .expect(200, done)
  })
})

describe('Check tools page', function () {
  it('Responds with 200 & HTML', function (done) {
    request(app).get('/tools').expect('Content-Type', /html/).expect(200, done)
  })
})

describe('Check error page', function () {
  it('Responds with 404', function (done) {
    request(app).get('/foobar').expect(404, done)
  })
})

describe('Weather API', function () {
  if (process.env.WEATHER_API_KEY) {
    it('Responds with 200 and valid data', function (done) {
      request(app)
        .get('/api/weather/51.40329/0.05619')
        .expect(/humidity/)
        .expect(200, done)
    })
  } else {
    it('Responds with 500', function (done) {
      request(app)
        .get('/api/weather/51.40329/0.05619')
        .expect(500)
        .expect({ error: 'Weather data is temporarily unavailable' }, done)
    })
  }
})

describe('Monitor API returns data', function () {
  it('Responds & provides metrics', function (done) {
    request(app)
      .get('/api/monitoringdata')
      .expect('Content-Type', /json/)
      .expect(/memTotalBytes/)
      .expect(/memUsedBytes/)
      .expect(/cpuAppPercentage/)
      .expect(200, done)
  })
})
