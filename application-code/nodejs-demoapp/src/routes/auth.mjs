//
// Routes used by login and account screen
// ---------------------------------------------
// Ben C, Nov 2020 - Updated Jul 2022 by Michael Fischer
//

// TODO: Update to use Cognito

import express from 'express'
const router = express.Router()
import axios from 'axios'
import msal from '@azure/msal-node'

// For reasons we need to do this here as well
import { config as dotenvConfig } from 'dotenv'
dotenvConfig()

const AUTH_SCOPES = ['user.read']
const AUTH_ENDPOINT = 'https://login.microsoftonline.com/common'
const AUTH_CALLBACK_PATH = 'signin'

let msalApp
// Create MSAL application object
if (process.env.AAD_APP_ID && process.env.AAD_APP_SECRET) {
  msalApp = new msal.ConfidentialClientApplication({
    auth: {
      clientId: process.env.AAD_APP_ID,
      authority: AUTH_ENDPOINT,
      clientSecret: process.env.AAD_APP_SECRET,
    },
    system: {
      loggerOptions: {
        loggerCallback(level, msg) {
          if (!msg.includes('redirect?code=')) console.log('### 🕵️‍♀️ MSAL: ', msg)
        },
        piiLoggingEnabled: true,
        logLevel: msal.LogLevel.Warning,
      },
    },
  })
  console.log(`### 🔐 MSAL configured using client ID: ${process.env.AAD_APP_ID}`)
}

// ==============================
// Routes
// ==============================

router.get('/login', async (req, res) => {
  const host = req.get('host')
  const redirectUri = `${host.indexOf('localhost') == 0 ? 'http' : 'https'}://${host}/${AUTH_CALLBACK_PATH}`
  console.log(`### 🔐 MSAL login request started, sign in redirect URL is: ${redirectUri}`)
  // Get URL to sign user in and consent to scopes needed for application
  try {
    const authURL = await msalApp.getAuthCodeUrl({
      scopes: AUTH_SCOPES,
      redirectUri: redirectUri,
    })

    // Now redirect to the oauth2 URL we have been given
    res.redirect(authURL)
  } catch (err) {
    res.render('error', {
      title: 'MSAL authentication failed',
      message: err,
      error: err,
    })
  }
})

router.get(`/${AUTH_CALLBACK_PATH}`, async (req, res) => {
  const host = req.get('host')
  const redirectUri = `${host.indexOf('localhost') == 0 ? 'http' : 'https'}://${host}/${AUTH_CALLBACK_PATH}`
  try {
    const tokenResponse = await msalApp.acquireTokenByCode({
      code: req.query.code,
      scopes: AUTH_SCOPES,
      redirectUri,
    })
    if (!tokenResponse) {
      // eslint-disable-next-line quotes
      throw "No token returned! that's pretty bad"
    }

    // Store user details in session
    req.session.user = {
      account: tokenResponse.account,
      accessToken: tokenResponse.accessToken,
    }

    res.redirect('/account')
  } catch (err) {
    res.render('error', {
      title: 'MSAL authentication failed',
      message: err,
      error: err,
    })
  }
})

router.get('/logout', function (req, res) {
  req.session.destroy(() => {
    res.redirect('/')
  })
})

router.get('/account', async function (req, res) {
  if (!req.session.user) {
    res.redirect('/login')
    return
  }
  let details = {}
  let photo = null

  try {
    details = await getUserDetails(req.session.user.accessToken)
    photo = await getUserPhoto(req.session.user.accessToken)
  } catch (err) {
    console.log('### 💥 ERROR! Problem calling graph API')
    console.log('### 💥 ERROR! ', err)
  }

  res.render('account', {
    title: 'Node DemoApp: Account',
    details: details,
    photo: photo,
  })
})

// ==============================
// MS Graph calls
// ==============================

async function getUserDetails(accessToken) {
  try {
    const graphReq = {
      url: 'https://graph.microsoft.com/v1.0/me',
      headers: { Authorization: accessToken },
    }

    const resp = await axios(graphReq)
    return resp.data
  } catch (err) {
    console.log(`### 💥 ERROR! Failed to get user details ${err.toString()}`)
  }
}

async function getUserPhoto(accessToken) {
  try {
    const graphReq = {
      url: 'https://graph.microsoft.com/v1.0/me/photo/$value',
      responseType: 'arraybuffer',
      headers: { Authorization: accessToken },
    }

    const resp = await axios(graphReq)
    return new Buffer.from(resp.data, 'binary').toString('base64')
  } catch (err) {
    console.log(`### 💥 ERROR! Failed to get user photo ${err.toString()}`)
  }
}

export default router
